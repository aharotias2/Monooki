/*
 *  Copyright 2022 Tanaka Takayuki (田中喬之)
 *
 *  This file is part of Monooki.
 *
 *  Monooki is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Monooki is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Monooki.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Tanaka Takayuki <aharotias2@gmail.com>
 */

using GLib.FileAttribute;

/**
 * This constant will be used to mark deleted files as a suffix at a backup-destination location.
 * that has already been saved but the original file has been deleted.
 */
public const string DELETE_MARK = "#deleted#";

/**
 * This constans is used as a mark of files which is not going to updated because its timestamp is not newer than the backup file.
 */
public const string MARK_EQUAL = "=";

/**
 * This constans is used as a mark of files which is deleted
 */
public const string MARK_DELETE = "-";

/**
 * This constants is used as a mark of files which will be newly copied to destination location.
 */
public const string MARK_CREATE = "+";

/**
 * This constants is used as a mark of files which will be updated at destination location.
 */
public const string MARK_UPDATE = "*";

/**
 * A log writer which is used if `l` commandline option is set.
 */
public DataOutputStream? log_writer;

/**
 * The error domain will be used internally in this application to passing error status and exit.
 */
public errordomain AppError {
    ARGUMENT_ERROR,
    FILESYSTEM_ERROR
}

/**
 * This enumeration will be used as exit status of some methods to pass it's result.
 */
public enum JobStatus {
    SUCCESS = 0,
    FAILURE = 1,
    NOOP = 2
}

/**
 * This enumeration wil be used to print the file infos such as 'can-write' or 'can-read' etc.
 */
public enum YesNo {
    YES, NO;
    
    public string to_string() {
        return this == YES ? "yes" : "no";
    }
    
    public static YesNo from_boolean(bool b) {
        return b ? YesNo.YES : YesNo.NO;
    }
}

/**
 * This function is an utility to easily print YesNo enum from a boolean value.
 * If parameter is true, it will return 'yes', if false 'no'.
 */
public string yesno(bool b) {
    return YesNo.from_boolean(b).to_string();
}

/**
 * This class is an utility for Gee.List.
 */
public class GeeListUtils {
    /**
     * This will return a copy of the list l1 without elements which is contained in the list l2.
     */    
    public static Gee.List<T> copy_and_remove_all<T>(Gee.List<T> l1, Gee.List<T> l2) {
        Gee.List<T> result = new Gee.ArrayList<T>();
        foreach (T item in l1) {
            if (!l2.contains(item)) {
                result.add(item);
            }
        }
        return result;
    }
}

/**
 * This class will work as a wrapper of GLib.File.
 * to get file info such as 'access::can-read' or 'access::can-write' attributes,
 * determine whether it is a directory or not, or get the modification time.
 */
public class FileWrapper : Object {
    public string relative_path { get; private set; }
    public File file { get; private set; }
    public FileType file_type { get; private set; }
    public FileInfo? info { get; private set; }
    public File? parent { get; private set; }

    private bool is_dry_run = false;

    private FileInfo? parent_info;

    public bool exists {
        get {
            return file.query_exists();
        }
    }

    public bool can_read {
        get {
            return info.get_attribute_boolean(ACCESS_CAN_READ);
        }
    }

    public bool can_write {
        get {
            return info.get_attribute_boolean(ACCESS_CAN_WRITE);
        }
    }
    
    public bool can_create {
        get {
            if (is_dry_run) {
                return true;
            }
            if (parent_info == null) {
                debug("parent info is null");
                return false;
            } else {
                debug("parent info is not null");
                return parent_info.get_attribute_boolean(ACCESS_CAN_WRITE);
            }
        }
    }

    public bool can_delete {
        get {
            return info.get_attribute_boolean(ACCESS_CAN_DELETE);
        }
    }

    public bool is_directory {
         get {
            return file_type == DIRECTORY;
        }
    }

    public bool is_symbolic_link {
        get {
            return info.get_is_symlink();
        }
    }

    public bool is_hidden_file {
        get {
            return info.get_is_hidden();
        }
    }

    public uint64 time_modified {
        get {
            return info.get_attribute_uint64("time::modified");
        }
    }

    public string owner_user {
        get {
            return info.get_attribute_string("owner::user");
        }
    }
        
    public FileWrapper() {}
    
    public FileWrapper.from_file(File file, bool is_dry_run = false) throws AppError {
        debug("FileWrapper.from_file(%s)", file.get_path());
        this.is_dry_run = is_dry_run;
        _set_file(file);
    }

    public FileWrapper.from_path(string path, bool is_dry_run = false) throws AppError {
        File tmp_file = File.new_for_path(path);
        debug("FileWrapper.from_path(%s)", tmp_file.get_path());
        this.is_dry_run = is_dry_run;
        _set_file(tmp_file);
    }
    
    public void _set_file(File file) throws AppError {
        debug("FileWrapper._set_file");
        this.file = file;
        if (exists) {
            try {
                info = file.query_info("standard::*,access::*,time::*,owner::*", 0);
                if (info != null) {
                    file_type = file.query_file_type(FileQueryInfoFlags.NONE);
                }
            } catch (Error e) {
                throw new AppError.FILESYSTEM_ERROR(@"summary = file info is not available, file = $(file.get_path()), code = $(e.code), detailed message = $(e.message))");
            }
        }
        if (!is_dry_run) {
            if (file.has_parent(null)) {
                debug(" file has a parent");
                File parent = file.get_parent();
                try {
                    parent_info = parent.query_info(ACCESS_CAN_WRITE, 0);
                    debug(" parent info is set.");
                } catch (Error e) {
                    throw new AppError.FILESYSTEM_ERROR(@"Failed to get file info.($(parent.get_path()))");
                }
            } else {
                throw new AppError.ARGUMENT_ERROR(@"the specified file does not have a parent. ($(file.get_path()))");
            }
        }
    }
    
    public int compare_time_modified(FileWrapper other) {
        if (time_modified == other.time_modified) {
            return 0;
        } else if (time_modified < other.time_modified) {
            return -1;
        } else {
            return 1;
        }
    }
    
    public FileWrapper resolve_relative_path(string relative_path) throws AppError {
        return new FileWrapper.from_file(file.resolve_relative_path(relative_path), is_dry_run);
    }

    public void update(bool is_dry_run = false) throws AppError {
        _set_file(file);
    }
        
    public void make_directory() throws Error {
        if (!is_dry_run) {
            file.make_directory();
        }
    }
    
    public void set_display_name(string name) throws Error {
        if (!is_dry_run) {
            file.set_display_name(name);
        }
    }
    
    public void delete() throws Error {
        if (!is_dry_run) {
            file.delete();
        } 
    }
    
    public void copy(FileWrapper dest, FileCopyFlags flags, Cancellable? cancellable,
            FileProgressCallback? callback_function) throws Error {
        if (!is_dry_run) {
            file.copy(dest.file, flags, cancellable, callback_function);
        }
    }

    public string to_string() {
        return """
file info:
  path: %s,
  owner-user: %s,
  is-directory: %s,
  can-read: %s,
  can-write: %s,
  can-delete: %s,
  is-symbolic-link: %s,
  is-hidden: %s,
  time-modified: %llu
""".printf(file.get_path(), owner_user, yesno(is_directory), yesno(can_read), yesno(can_write), yesno(can_delete),
                yesno(is_symbolic_link), yesno(is_hidden_file), time_modified);
    }
}

/**
 * バックアップ処理を行うメインクラス。
 * add_sourceメソッドでバックアップ元を設定、
 * set_destinationメソッドでバックアップ先を設定し
 * runメソッドで実行を行う。
 * is_mark_deleted_filesとis_dry_runはオプションとして使用する
 * 
 * It is a main class that will do backing up work.
 * It set source paths in add_source method,
 * set destination path in set_destination method,
 * and execute it's main job at run method.
 * it uses 'is_mark_deleted_files' and 'is_dry_run' properties as options.
 */
public class Monooki : Object {
    private string destination_path;
    private Gee.List<string> source_paths;
    private FileWrapper destination;
    private Gee.List<FileWrapper> sources;
    
    public bool is_mark_deleted_files { get; set; default = true; }
    public bool is_dry_run { get; set; default = true; }
    public bool ignore_symlinks { get; set; default = false; }
    public bool has_log_file { get; set; default = false; }
    
    /**
     * コンストラクタ
     * 
     * Constructor.
     */    
    public Monooki(bool is_dry_run) {
        source_paths = new Gee.ArrayList<string>();
        sources = new Gee.ArrayList<FileWrapper>();
        this.is_dry_run = is_dry_run;
    }

    /**
     * バックアップ元のファイルを追加設定する。
     * チェックを行い、読み取りができないパスの場合、例外をスローする。
     * 
     * To add source paths, use this method.
     * It checks validity of the path and throw exceptions if
     * it is not readable or does not exist.
     */    
    public void add_source(string source_path) throws AppError {
        debug("add source: %s (dry-run=%s)", source_path, yesno(is_dry_run));
        FileWrapper source_wrapped = new FileWrapper.from_path(source_path, is_dry_run);
        if (source_wrapped.exists && source_wrapped.is_directory) {
            source_paths.add(source_path);
            sources.add(source_wrapped);
        } else {
            throw new AppError.ARGUMENT_ERROR("コピー元パスはディレクトリにすること" + source_wrapped.to_string());
        }
    }
    
    /**
     * バックアップ先ディレクトリパスを設定する。
     * 条件チェックを行い、バックアップ先として止揚できない場合、例外をスローする。
     * 
     * To set a backup destination path, use this method.
     * It checks a validity of the path and throw exception if it is not writable or does not exist.
     */
    public void set_destination(string destination_path) throws AppError {
        debug("Monooki.set_destination(%s, %s)", destination_path, yesno(is_dry_run));
        FileWrapper prepared_dest_wrapper = new FileWrapper.from_path(destination_path, is_dry_run);
        if (!prepared_dest_wrapper.exists) {
            if (prepared_dest_wrapper.can_create) {
                try {
                    prepared_dest_wrapper.make_directory();
                    prepared_dest_wrapper.update();
                } catch (Error e) {
                    throw new AppError.FILESYSTEM_ERROR("Fail to make the destination directory");
                }
            } else {
                throw new AppError.ARGUMENT_ERROR("The destination directory does not exist.\n");
            }
        }
        
        if (prepared_dest_wrapper.exists && !prepared_dest_wrapper.is_directory) {
            throw new AppError.ARGUMENT_ERROR("The destination path does not point a directory\n" + prepared_dest_wrapper.to_string());
        }
        
        if (prepared_dest_wrapper.exists && !prepared_dest_wrapper.can_write) {
            throw new AppError.ARGUMENT_ERROR("The destination path does exist but is not writable\n" + prepared_dest_wrapper.to_string());
        }
        
        this.destination_path = destination_path;
        this.destination = prepared_dest_wrapper;
    }

    /**
     * バックアップ処理の実行を行うメインメソッド。
     * 
     * This is the main method of this class.
     */    
    public JobStatus run(Cancellable? cancellable = null) throws AppError {
        debug("Monooki.run begin");
        foreach (FileWrapper source in sources) {
            debug("Monooki.run foreach %s in sources", source.file.get_path());
            if (!source.exists) {
                continue;
            }
            
            if (!source.can_read) {
                continue;
            }
            
            if (source.is_directory) {
                FileWrapper dest_child_wrapped = destination.resolve_relative_path(source.file.get_basename());
                if (!dest_child_wrapped.exists) {
                    try {
                        dest_child_wrapped.make_directory();
                    } catch (Error e) {
                        throw new AppError.FILESYSTEM_ERROR(@"Failed to make directory ($(dest_child_wrapped.file.get_path()))");
                    }
                }
                backup_directory(source, dest_child_wrapped, cancellable);
            } else {
                Gee.List<string> dest_children = list_children(destination.file);
                foreach (var child_name in dest_children) {
                    if (child_name != source.file.get_basename()) {
                        mark_deleted_file(destination.file.resolve_relative_path(child_name));
                    }
                }
                FileWrapper target_wrapped = destination.resolve_relative_path(source.file.get_basename());
                if (ignore_symlinks && target_wrapped.is_symbolic_link) {
                    continue;
                }
                backup_file(source, target_wrapped, cancellable);
            }
        }
        debug("Monooki.run end");
        return SUCCESS;
    }

    /**
     * ディレクトリ内にあるファイル名のリストを返す。
     * 
     * This will return a list which contains file names in a directory.
     */    
    private Gee.List<string> list_children(File dir) throws AppError {
        try {
            Gee.List<string> result = new Gee.ArrayList<string>();
            
            if (is_dry_run && !dir.query_exists()) {
                return result;
            }
            
            Dir d = Dir.open(dir.get_path());
            string? name = null;
            
            while ((name = d.read_name()) != null) {
                if (name == "." || name == "..") {
                    continue;
                }
                result.add(name);
            }
            
            return result;
        } catch (FileError e) {
            throw new AppError.FILESYSTEM_ERROR(@"ディレクトリ読み取り時にエラー ($(e.code): $(e.message))");
        }
    }

    /**
     * すでにバックアップしたファイルがバックアップ元で削除された場合、
     * バックアップ先の対応するファイルの削除を行わず、代わりにファイル名にマークを付ける。
     * 成功した場合SUCCESSを、失敗した場合はFAILUREを返す。
     * dry-runオプションが有効の場合、マークを実際には付けず、対象のファイルの出力のみ行う。
     * 
     * This method will mark '#deleted#' suffix at the copied file which was deleted at original location.
     * and return SUCCESS or FAILURE as a result.
     * it will not put a real suffix to file if 'is_dry_run' option is true.
     */
    private JobStatus mark_deleted_file(File f, Cancellable? cancellable = null, bool is_dry_run = false) throws AppError {
        FileWrapper fw = new FileWrapper.from_file(f, is_dry_run);
        
        if (!fw.can_write) {
            print("%s: このファイルは制限されているため削除をマークできない。\n", f.get_path());
            return FAILURE;
        }
        
        try {
            fw.set_display_name(fw.file.get_basename() + DELETE_MARK);
        } catch (Error e) {
            throw new AppError.FILESYSTEM_ERROR("ファイルのリネームができなかった");
        }
        
        print(" - %s%s\n", f.get_path(), DELETE_MARK);
        return SUCCESS;
    }
    
    /**
     * ファイルを削除する。
     * 削除できなかった場合はFAILUREを返す。
     * dry-runオプションが有効の場合、実際に削除せず削除対象のファイル名出力のみ行う。
     * 
     * This will delete a specified file and return SUCCESS or FAILURE as a result.
     * And print the file name which it deleted with prefix "-".
     * This will not really delete the file if 'is-dry-run' option is on.
     */
    private JobStatus delete_file(FileWrapper f, Cancellable? cancellable = null) throws AppError {
        debug("Monooki.delete_file begin");
        if (f.can_delete) {
            try {
                f.delete();
            } catch (Error e) {
                throw new AppError.FILESYSTEM_ERROR("It failed to delete the specified file");
            }
            print(" - %s -- deleted\n", f.file.get_path());
            debug("Monooki.delete_file end");
            return SUCCESS;
        } else {
            string path = f.file.get_path();
            printerr("/- %s -- cannot delete\n", path);
            debug("Monooki.delete_file end");
            return FAILURE;
        }
    }
    
    /**
     * ディレクトリを再帰的に削除する。
     * dry-runオプションが有効の時、実際にファイルを削除せず、削除されることになるファイル名の出力のみ行う。
     * 
     * This will delete a specified directory recursively.
     * This means it will delete the directory either it contains children or not.
     * But it will not really delete it if 'is-dry-run' option is on.
     * It print a file name which it delete with prefix "-".
     */
    private JobStatus delete_directory(FileWrapper f, Cancellable? cancellable = null) throws AppError {
        debug("Monooki.delete_directory begin");
        if (f.is_directory) {
            Gee.List<string> children = list_children(f.file);
            foreach (var child_name in children) {
                FileWrapper child = f.resolve_relative_path(child_name);
                if (!child.can_delete) {
                    printerr("/%s %s -- skip to delete.\n", MARK_DELETE, child.file.get_path());
                    continue;
                }
                if (child.is_directory) {
                    delete_directory(child, cancellable);
                } else {
                    delete_file(child, cancellable);
                }
            }
        }
        
        delete_file(f);
        print(" %s %s -- deleted\n", MARK_DELETE, f.file.get_path());
        debug("Monooki.delete_directory end");
        return SUCCESS;
    }

    /**
     * ディレクトリ以外のファイルをバックアップする。
     * 指定したファイルが存在しない場合、FAILUREを返して処理を終了する。
     * 対象のファイルがバックアップ先に存在しない場合、行頭に「+」と共にファイル名を出力する。
     * バックアップ先に存在する場合、ファイルの更新時刻の比較を行い、対象ファイルが新しい場合はバックアップを行う。
     * その場合は行頭「*」と共にファイル名を出力する。
     * 対象のファイルの更新時刻がバックアップ先にあるものより新しくない場合はバックアップを行わない。
     * ただ行頭「=」と共にファイル名の出力のみ行う。
     */
    private JobStatus backup_file(FileWrapper src, FileWrapper dest, Cancellable? cancellable = null) throws AppError {
        debug("Monooki.backup_file begin");
        if (dest.exists) {
            if (!dest.can_write) {
                return FAILURE;
            }
            if (src.compare_time_modified(dest) < 0) {
                return FAILURE;
            }
        }

        string mark;
        if (dest.exists) {
            if (src.compare_time_modified(dest) > 0) {
                mark = MARK_UPDATE;
            } else {
                mark = MARK_EQUAL;
            }
        } else {
            mark = MARK_CREATE;
        }

        if (mark != MARK_EQUAL) {
            try {
                FileCopyFlags flags;
                if (mark == MARK_UPDATE) {
                    flags = FileCopyFlags.OVERWRITE;
                } else {
                    flags = FileCopyFlags.NONE;
                }
                
                if (has_log_file) {
                    src.copy(dest, flags, cancellable, null);
                } else {
                    src.copy(dest, flags, cancellable, (current_num_bytes, total_num_bytes) => {
                        int per = (int) ((double) current_num_bytes / (double) total_num_bytes) * 100;
                        print(" %s %s (%d%)\r", mark, src.file.get_path(), per);
                    });
                }
                print(" %s %s%s\n", mark, src.file.get_path(), is_dry_run ? " (dry-run)" : "");
            } catch (Error e) {
                throw new AppError.FILESYSTEM_ERROR(@"ファイルのコピーに失敗 ($(src.file.get_path()))");
            }
        } else {
            print(" %s %s\n", mark, src.file.get_path());
        }
        debug("Monooki.backup_file end");
        return SUCCESS;
    }
    
    /**
     * ディレクトリのバックアップ処理を行う。
     * ディレクトリ内のファイルを再帰的に全てバックアップ先に保存する。
     * dry-runオプションが有効の時は保存するファイル名の出力のみ行い、実際にファイルのバックアップは行わない。
     */
    private JobStatus backup_directory(FileWrapper src, FileWrapper dest, Cancellable? cancellable = null) throws AppError {
        debug("Monooki.backup_directory begin");
        Gee.List<string> src_children = list_children(src.file);
        Gee.List<string> dest_children = list_children(dest.file);
        Gee.List<string> removed_children = GeeListUtils.copy_and_remove_all<string>(dest_children, src_children);

        foreach (string child_name in src_children) {
            FileWrapper src_child_wrapped = src.resolve_relative_path(child_name);
            FileWrapper dest_child_wrapped = dest.resolve_relative_path(child_name);
            if (ignore_symlinks && src_child_wrapped.is_symbolic_link) {
                continue;
            }
            if (src_child_wrapped.is_directory) {
                if (!dest_child_wrapped.exists) {
                    try {
                        dest_child_wrapped.make_directory();
                    } catch (Error e) {
                        printerr("%s - Error: $(e.message)\n", dest_child_wrapped.file.get_path());
                    }
                }
                backup_directory(src_child_wrapped, dest_child_wrapped, cancellable);
            } else {
                backup_file(src_child_wrapped, dest_child_wrapped, cancellable);
            }
        }

        foreach (string removed_child_name in removed_children) {
            FileWrapper removed_child = dest.resolve_relative_path(removed_child_name);
            if (is_mark_deleted_files) {
                if (!removed_child_name.has_suffix(DELETE_MARK)) {
                    mark_deleted_file(removed_child.file, cancellable);
                }
            } else if (removed_child.is_directory) {
                delete_directory(removed_child, cancellable);
            } else {
                delete_file(removed_child, cancellable);
            }
        }
        debug("Monooki.backup_directory end");
        return SUCCESS;
    }
}

/**
 * This Application class that has an entry point
 * will parse the commandline arguments and execute it's job.
 */
public class MonookiApplication : Application {
    private bool is_version = false;
    private bool is_dry_run = false;
    private string is_mark_deleted_files = "yes";
    private string? input_file = null;
    private string? log_path = null;
    private bool ignore_symlinks = false;
    
    /**
     * A constructor.
     */    
    public MonookiApplication() {
        Object(
            application_id: APP_ID,
            flags: ApplicationFlags.HANDLES_COMMAND_LINE
        );
    }

    /**
     * It's overriding a local_command_line method of GLib.Application class
     * Which will parse command line options and execute ``run'' method of newly created Monooki object.
     */
    public override bool local_command_line(ref unowned string[] args, out int exit_status) {
        try {
            hold();
            
            OptionEntry[] options = new OptionEntry[6];
            options[0] = {
                "version", '\0', OptionFlags.NONE, OptionArg.NONE, ref is_version, "Print the version number", null
            };
            options[1] = {
                "dry-run", 'd', OptionFlags.NONE, OptionArg.NONE, ref is_dry_run, "It will print simulation how to backup works without really doing it", null
            };
            options[2] = {
                "mark-deleted-files", 'm', OptionFlags.NONE, OptionArg.STRING, ref is_mark_deleted_files, "It will not delete files that was deleted in source locations.", "{yes,no}"
            };
            options[3] = {
                "input-file", 'i', OptionFlags.NONE, OptionArg.STRING, ref input_file, "a file that contains file paths line by line which you want to backup.", "FILENAME"
            };
            options[4] = {
                "log-file", 'o', OptionFlags.NONE, OptionArg.STRING, ref log_path, "a path of the log file.", "FILENAME"
            };
            options[5] = {
                "ignore-symbolic-links", 'L', OptionFlags.NONE, OptionArg.NONE, ref ignore_symlinks, "do not backup symbolic links and its contents", null
            };

            var opt_ctx = new OptionContext("");
            opt_ctx.set_help_enabled(true);
            opt_ctx.add_main_entries(options, null);

            unowned string[] tmp_args = args;
            opt_ctx.parse(ref tmp_args);

            if (is_version) {
                print("%s ver.%s\n", APP_ID, VERSION);
                exit_status = 0;
                return true;
            }
            
            if ((input_file == null && args.length < 2) || input_file != null && args.length < 1) {
                throw new AppError.ARGUMENT_ERROR("This command requires at least two arguments.\n"
                        + opt_ctx.get_help(true, null));
            }

            var cancellable = new Cancellable();

            if (log_path != null) {
                FileWrapper log = new FileWrapper.from_file(File.new_for_path(log_path), is_dry_run);
                if (log.exists) {
                    throw new AppError.ARGUMENT_ERROR("the specified log file already exists.");
                }
                if (!log.can_create) {
                    debug("log parent: %s", log.file.get_parent().get_path());
                    debug("%s\n", new FileWrapper.from_path(log.file.get_parent().get_path(), is_dry_run).to_string());
                    throw new AppError.ARGUMENT_ERROR("You don't have a permission to write to the specified log file");
                }
                
                log_writer = new DataOutputStream(log.file.create(FileCreateFlags.NONE, cancellable));
                GLib.set_print_handler((text) => {
                    try {
                        log_writer.put_string(text);
                    } catch (IOError e) {
                    }
                });
                GLib.set_printerr_handler((text) => {
                    try {
                        log_writer.put_string(text);
                    } catch (IOError e) {
                    }
                });
            }

            var backupper = new Monooki(is_dry_run);
            if (input_file != null) {
                File input_file_file = File.new_for_path(input_file);
                if (input_file_file.query_exists()) {
                    DataInputStream dis = new DataInputStream(input_file_file.read());
                    string? line = null;
                    while ((line = dis.read_line()) != null) {
                        debug("read line: %s", line);
                        backupper.add_source(line);
                    }
                } else {
                    throw new AppError.ARGUMENT_ERROR("Invalid file name for the input-file option.");
                }
            } else {
                for (int i = 1; i < args.length - 1; i++) {
                    backupper.add_source(args[i]);
                    debug(" %s,", args[i]);
                }
            }
            backupper.set_destination(args[args.length - 1]);
            backupper.is_mark_deleted_files = is_mark_deleted_files == "yes";
            backupper.ignore_symlinks = ignore_symlinks;
            backupper.has_log_file = log_path != null;

            JobStatus status = backupper.run(cancellable);

            if (status == SUCCESS) {
                exit_status = 0;
            } else {
                exit_status = 1;
            }
            
            debug("MonookiApplication.local_command_line end.");
        } catch (OptionError e) {
            printerr("error: %s\n", e.message);
            printerr("Run '%s --help' to see a full list of available command line options.\n", args[0]);
            exit_status = 1;
        } catch (Error e) {
            printerr("error: %s\n", e.message);
            exit_status = 1;
        } finally {
            release();
        }
        return true;
    }

    /**
     * This is the entry pooint
     * that create MonookiApplication and execute ``run'' method.
     */
    public static int main(string[] args) {
        // At first set up a print handler
        // because normal ``print'' method will print utf8 strings incorrectly.
        GLib.set_print_handler((text) => stdout.puts(text));
        GLib.set_printerr_handler((text) => stdout.puts(text));
        debug("%s Hello", APP_ID);
        return new MonookiApplication().run(args);
    }
}

