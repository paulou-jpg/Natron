Summary: Open source compositing software
Name: Natron
# The two actively maintained versions (that are merged into master)
Version21: 2.1.10
Version22: 2.2.10
Version23: 2.3.16
Version24: 2.4.4
Version25: 2.5.0
Version30: 3.0.0

# The version for this branch of the sources
Version: %{version25}

# The release number (must be incremented whenever changes to this file generate different binaries)
Release: 1%{?dist}
License: GPLv2

Group: System Environment/Base
URL: http://natrongithub.github.io

# https://github.com/NatronGitHub/Natron/releases/download/%{version}/Natron-%{version}.tar.xz
Source0: %{name}-%{version}.tar.xz
# https://github.com/NatronGitHub/Natron/releases/download/2.1.0/Natron-OpenColorIO-Configs-2.1.0.tar.xz
Source1: %{name}-OpenColorIO-Configs-2.1.0.tar.xz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires: fontconfig-devel gcc-c++ expat-devel python-pyside-devel shiboken-devel qt-devel boost-devel pixman-devel glfw-devel cairo-devel
Requires: fontconfig qt-x11 python-pyside shiboken-libs boost-serialization pixman glfw cairo

%description
Open source compositing software. Node-graph based. Similar in functionalities to Adobe After Effects and Nuke by The Foundry.

%prep
%setup
%setup -T -D -a 1

%build
mv Natron-OpenColorIO-Configs-2.1.0 OpenColorIO-Configs
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DNATRON_NO_ASSERTIONS=ON
cmake --build . %{?_smp_mflags}

%install
cd build
DESTDIR=%{buildroot} cmake --install .

%clean
%{__rm} -rf %{buildroot}

%post
update-mime-database /usr/share/mime
update-desktop-database /usr/share/applications

%postun
update-mime-database /usr/share/mime
update-desktop-database /usr/share/applications

%files
%defattr(-,root,root,-)
/usr/bin/Natron
/usr/bin/NatronRenderer
/usr/share/applications/Natron.desktop
/usr/share/pixmaps/natronIcon256_linux.png
/usr/share/pixmaps/natronProjectIcon_linux.png
/usr/share/mime/packages/x-natron.xml
/usr/share/OpenColorIO-Configs
%doc LICENSE.txt

%changelog
