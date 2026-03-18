systemd_user_unit_dir = get_option('prefix') / 'lib' / 'systemd' / 'user'

install_data(
  'protonmail-bridge.service',
  'proton-calendar-bridge.service',
  'proton-drive-bridge@.service',
  install_dir: systemd_user_unit_dir,
)
