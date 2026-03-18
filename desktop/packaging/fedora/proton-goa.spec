# proton-goa.spec — RPM spec for Proton services GNOME Online Accounts integration
#
# IMPORTANT NOTES FOR INSTALLERS:
#
# 1. protonmail-bridge is NOT available in Fedora repositories.
#    Install it separately from: https://proton.me/mail/bridge
#    (official Linux package available as .rpm)
#
# 2. rclone is available from Fedora repositories:
#    dnf install rclone
#
# 3. After installing this package, add your Proton account in:
#    GNOME Settings → Online Accounts

Name:           proton-goa
Version:        0.1.0
Release:        1%{?dist}
Summary:        Proton services integration for GNOME Online Accounts
License:        GPL-2.0-only
URL:            https://github.com/terraceonhigh/Proton-on-Gnome-Online-Accounts
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  meson >= 0.60
BuildRequires:  ninja-build
BuildRequires:  gcc
BuildRequires:  pkg-config
BuildRequires:  gnome-online-accounts-devel
BuildRequires:  glib2-devel
BuildRequires:  libsecret-devel
BuildRequires:  libsoup3-devel
BuildRequires:  json-glib-devel
BuildRequires:  evolution-data-server-devel
BuildRequires:  systemd-rpm-macros

# Runtime dependencies
Requires:       gnome-online-accounts
Requires:       gvfs-goa
Requires:       rclone

# protonmail-bridge is NOT in Fedora repositories.
# Install it manually from: https://proton.me/mail/bridge

%description
Proton-on-GNOME-Online-Accounts integrates Proton services (Mail, Drive, Calendar)
with GNOME Online Accounts, providing the same seamless experience as Google or
Microsoft 365 accounts in GNOME.

After installation, add your Proton account in GNOME Settings → Online Accounts.
This will automatically configure:
  - Mail (Geary) via Proton Mail Bridge
  - Files/Drive (Nautilus sidebar) via rclone FUSE mount
  - Calendar (GNOME Calendar) via EDS integration

%prep
%autosetup

%build
cd desktop
%meson
%meson_build

%install
cd desktop
%meson_install

%post
%systemd_user_post protonmail-bridge.service
%systemd_user_post proton-calendar-bridge.service

%preun
%systemd_user_preun protonmail-bridge.service proton-calendar-bridge.service

%files
%license LICENSE
%{_libdir}/gnome-online-accounts/goa-proton.so
%{_userunitdir}/protonmail-bridge.service
%{_userunitdir}/proton-calendar-bridge.service

%changelog
* Thu Mar 05 2026 Proton-on-GOA Maintainers <maintainers@example.com> - 0.1.0-1
- Initial packaging of proton-goa 0.1.0
- Provides GNOME Online Accounts plugin for Proton Mail, Drive, and Calendar
- Includes systemd user service units for protonmail-bridge and proton-calendar-bridge
