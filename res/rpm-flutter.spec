Name:       rustdesk
Version:    1.4.6
Release:    0
Summary:    RPM package
License:    GPL-3.0
URL:        https://rustdesk.com
Vendor:     rustdesk <info@rustdesk.com>
Requires:   gtk3 libxcb libXfixes alsa-lib libva pam gstreamer1-plugins-base
Recommends: libayatana-appindicator-gtk3 libxdo
Provides:   libdesktop_drop_plugin.so()(64bit), libdesktop_multi_window_plugin.so()(64bit), libfile_selector_linux_plugin.so()(64bit), libflutter_custom_cursor_plugin.so()(64bit), libflutter_linux_gtk.so()(64bit), libscreen_retriever_plugin.so()(64bit), libtray_manager_plugin.so()(64bit), liburl_launcher_linux_plugin.so()(64bit), libwindow_manager_plugin.so()(64bit), libwindow_size_plugin.so()(64bit), libtexture_rgba_renderer_plugin.so()(64bit)

# https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/

%description
The best open-source remote desktop client software, written in Rust.

%prep
# we have no source, so nothing here

%build
# we have no source, so nothing here

# %global __python %{__python3}

%install

mkdir -p "%{buildroot}/usr/share/horusrd" && cp -r ${HBB}/flutter/build/linux/x64/release/bundle/* -t "%{buildroot}/usr/share/horusrd"
mkdir -p "%{buildroot}/usr/bin"
install -Dm 644 $HBB/res/horusrd.service -t "%{buildroot}/usr/share/horusrd/files"
install -Dm 644 $HBB/res/horusrd.desktop -t "%{buildroot}/usr/share/horusrd/files"
install -Dm 644 $HBB/res/horusrd-link.desktop -t "%{buildroot}/usr/share/horusrd/files"
install -Dm 644 $HBB/res/128x128@2x.png "%{buildroot}/usr/share/icons/hicolor/256x256/apps/horusrd.png"
install -Dm 644 $HBB/res/scalable.svg "%{buildroot}/usr/share/icons/hicolor/scalable/apps/horusrd.svg"

%files
/usr/share/horusrd/*
/usr/share/horusrd/files/horusrd.service
/usr/share/icons/hicolor/256x256/apps/horusrd.png
/usr/share/icons/hicolor/scalable/apps/horusrd.svg
/usr/share/horusrd/files/horusrd.desktop
/usr/share/horusrd/files/horusrd-link.desktop

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
ln -sf /usr/share/horusrd/horusrd /usr/bin/horusrd
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
    rm /usr/bin/horusrd || true
    rmdir /usr/lib/horusrd || true
    rmdir /usr/local/horusrd || true
    rmdir /usr/share/horusrd || true
    rm /usr/share/applications/horusrd.desktop || true
    rm /usr/share/applications/horusrd-link.desktop || true
    update-desktop-database
  ;;
  1)
    # for upgrade
    rmdir /usr/lib/horusrd || true
    rmdir /usr/local/horusrd || true
  ;;
esac
