# Monooki
light weight simple command line application for backup your directories or files

## Motivation
I have used rsync to backup my files but I wonder how it works and I don't know the detail.
So I decided to create a new one for my needs.

## Usage
execute a command like below:

    $ com.github.aharotias2.Monooki dirA dirB dirC destination

Same as the cp and rsync commands.

Copy the directories dirA, dirB, and dirC to the destination directory.

If a file with the same name already exists, it will not be overwritten unless it has been updated。

You can specify the backup source by writing the path to the file with the -i option.

The --dry-run option only prints stdout the filename to be copied without doing the actual copy.

## Compile
It use meson as build system.
At first execute `meson build` command to create build environment. 
it will make a directory named `build` then cd into it and run `ninja` command to compile the Monooki.

    $ meson build
    $ cd build
    $ ninja

Then there is `com.github.aharotias2.Monooki` that is the final result of this process.
Copy it some location where included in the `PATH` environmental variable for installation.

I recommend you to register this command in your crontab scheduling list to constantly backup your important files.

Good luck.
