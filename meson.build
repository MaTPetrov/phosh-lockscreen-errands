sources = files(
  'plugin.vala',
  'errands-data.vala',
  'errands-widget.vala'
)

shared_library('phosh-plugin-errands',
  sources,
  dependencies: [dep_phosh, dep_gtk, dep_json, dep_gee],
  install: true,
  install_dir: get_option('libdir') / 'phosh' / 'plugins'
)
