project('com.github.aharotias2.Monooki', 'vala', 'c', version: '0.0.1')

add_project_arguments(
  [
    '--vapidir', join_paths(meson.current_source_dir()),
    '--pkg', 'config'
  ],
  language: 'vala'
)

config_h = configuration_data()
config_h.set_quoted('VERSION', meson.project_version())
config_h.set_quoted('APP_ID', meson.project_name())
config_h.set_quoted('DATADIR', join_paths(get_option('prefix'), get_option('datadir')))

config_file = configure_file(
  output: 'config.h',
  configuration: config_h
)

project_config_dep = declare_dependency(
  sources: config_file,
  include_directories: include_directories('.')
)

executable(
  meson.project_name(),
  'Monooki.vala',
  dependencies: [
    dependency('glib-2.0'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    project_config_dep
  ],
  install: true
)


              


