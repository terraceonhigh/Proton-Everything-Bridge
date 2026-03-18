goa_proton_sources = files(
  'goaprotonmailprovider.c',
  'goaprotondriveprovider.c',
  'goaprotoncalendarprovider.c',
  'goaprotonauth.c',
)

shared_module(
  'goa-proton',
  goa_proton_sources,
  dependencies: all_deps,
  install: true,
  install_dir: goa_provider_dir,
  name_prefix: '',
)
