project('phosh-lockscreen-errands', 'vala', 'c',
  version: '0.1.0',
  meson_version: '>=0.56.0')

dep_gtk = dependency('gtk4')
dep_json = dependency('json-glib-1.0')
dep_gee = dependency('libgee-0.8')

# Зависимость от phosh
dep_phosh = dependency('libphosh', required: false)
if not dep_phosh.found()
  dep_phosh = dependency('phosh', required: false)
endif

subdir('src')
subdir('data')
