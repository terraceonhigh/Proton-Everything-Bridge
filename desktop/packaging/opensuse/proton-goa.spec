%define _name proton-goa

Name:           %{_name}
Version:        0.1.0
Release:        0
Summary:        Proton services integration for GNOME Online Accounts
License:        GPL-2.0-only
Group:          System/GUI/GNOME
URL:            https://github.com/terraceonhigh/Proton-on-Gnome-Online-Accounts
Source:         %{_name}-%{version}.tar.gz
BuildRequires:  meson >= 0.60
BuildRequires:  ninja
BuildRequires:  gcc
BuildRequires:  pkg-config
BuildRequires:  gnome-online-accounts-devel
BuildRequires:  glib2-devel
BuildRequires:  libsecret-devel
BuildRequires:  libsoup3-devel
BuildRequires:  libjson-glib-devel
BuildRequires:  evolution-data-server-devel
BuildRequires:  systemd-rpm-macros
Requires:       gnome-online-accounts
Requires:       gvfs
Requires:       rclone
# protonmail-bridge must be installed separately from proton.me
Recommends:     protonmail-bridge

%description
Proton-on-GNOME-Online-Accounts integrates Proton Mail, Proton Drive, and
Proton Calendar into GNOME Online Accounts. After adding a Proton account in
GNOME Settings → Online Accounts, Mail (Geary), Files/Drive (Nautilus), and
Calendar (GNOME Calendar) are automatically configured — mirroring the
experience of Google or Microsoft 365 accounts in GOA.

This package provides the GOA backend plugin and systemd user services for
the Proton Mail Bridge, Proton Drive Bridge, and Proton Calendar Bridge.

%prep
%autosetup -n %{_name}-%{version}

%build
cd desktop
%meson
%meson_build

%install
cd desktop
%meson_install

%post
%service_add_post protonmail-bridge.service proton-calendar-bridge.service

%preun
%service_del_preun protonmail-bridge.service proton-calendar-bridge.service

%files
%license LICENSE
%{_libdir}/gnome-online-accounts/goa-proton.so
%{_prefix}/lib/systemd/user/protonmail-bridge.service
%{_prefix}/lib/systemd/user/proton-calendar-bridge.service
%{_prefix}/lib/systemd/user/proton-drive-bridge@.service
%doc docs/account-setup-flow.md

%changelog
