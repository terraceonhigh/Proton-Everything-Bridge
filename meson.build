project(
  'proton-goa',
  'c',
  version: '0.1.0',
  license: 'GPL-2.0-only',
  meson_version: '>= 0.62',
  default_options: [
    'prefix=/usr',
  ],
)

# Dependencies
goa_backend_dep = dependency('goa-backend-1.0')
glib_dep        = dependency('glib-2.0')
gobject_dep     = dependency('gobject-2.0')
gio_dep         = dependency('gio-2.0')
libsecret_dep   = dependency('libsecret-1')
libsoup_dep     = dependency('libsoup-3.0')
json_glib_dep   = dependency('json-glib-1.0')

all_deps = [
  goa_backend_dep,
  glib_dep,
  gobject_dep,
  gio_dep,
  libsecret_dep,
  libsoup_dep,
  json_glib_dep,
]

# GOA provider plugin install directory
goa_provider_dir = goa_backend_dep.get_variable(
  pkgconfig: 'providerdir',
  default_value: get_option('prefix') / get_option('libdir') / 'gnome-online-accounts',
)

subdir('src')
subdir('data')
