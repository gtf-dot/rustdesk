Name:       rustdesk
Version:    1.5.0
Release:    0
Summary:    RPM package
License:    AGPL-3.0-only
URL:        https://rustdesk.com
Vendor:     rustdesk <info@rustdesk.com>
Requires:   gtk3 libxcb libXfixes alsa-lib libva2 gstreamer1-plugins-base
Recommends: libayatana-appindicator-gtk3 libxdo

# https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/

%description
The best open-source remote desktop client software, written in Rust.

%prep
# we have no source, so nothing here

%build
# we have no source, so nothing here

%global __python %{__python3}

%install
mkdir -p %{buildroot}/usr/bin/
mkdir -p %{buildroot}/usr/share/horusrd/
mkdir -p %{buildroot}/usr/share/horusrd/files/
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps/
mkdir -p %{buildroot}/usr/share/icons/hicolor/scalable/apps/
install -m 755 $HBB/target/release/rustdesk %{buildroot}/usr/bin/horusrd
install $HBB/libsciter-gtk.so %{buildroot}/usr/share/horusrd/libsciter-gtk.so
install $HBB/res/horusrd.service %{buildroot}/usr/share/horusrd/files/
install $HBB/res/128x128@2x.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/horusrd.png
install $HBB/res/scalable.svg %{buildroot}/usr/share/icons/hicolor/scalable/apps/horusrd.svg
install $HBB/res/horusrd.desktop %{buildroot}/usr/share/horusrd/files/
install $HBB/res/horusrd-link.desktop %{buildroot}/usr/share/horusrd/files/

%files
/usr/bin/horusrd
/usr/share/horusrd/libsciter-gtk.so
/usr/share/horusrd/files/horusrd.service
/usr/share/icons/hicolor/256x256/apps/horusrd.png
/usr/share/icons/hicolor/scalable/apps/horusrd.svg
/usr/share/horusrd/files/horusrd.desktop
/usr/share/horusrd/files/horusrd-link.desktop
/usr/share/horusrd/files/__pycache__/*

%changelog
# let's skip this for now

%pre
# can do something for centos7
case "$1" in
  1)
    # for install
  ;;
  2)
    # for upgrade
    systemctl stop horusrd || true
  ;;
esac

%post
cp /usr/share/horusrd/files/horusrd.service /etc/systemd/system/horusrd.service
cp /usr/share/horusrd/files/horusrd.desktop /usr/share/applications/
cp /usr/share/horusrd/files/horusrd-link.desktop /usr/share/applications/
systemctl daemon-reload
systemctl enable horusrd
systemctl start horusrd
update-desktop-database

%preun
case "$1" in
  0)
    # for uninstall
    systemctl stop horusrd || true
    systemctl disable horusrd || true
    rm /etc/systemd/system/horusrd.service || true
  ;;
  1)
    # for upgrade
  ;;
esac

%postun
case "$1" in
  0)
    # for uninstall
    rm /usr/share/applications/horusrd.desktop || true
    rm /usr/share/applications/horusrd-link.desktop || true
    update-desktop-database
  ;;
  1)
    # for upgrade
  ;;
esac
