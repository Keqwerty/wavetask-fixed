# Maintainer: Issa M. Omais <me0@ioplus.dev>

_pkgname=wavetask
pkgname="$_pkgname-git"
pkgver=1.4.r3.gdbc7fae
pkgrel=1
pkgdesc="A Plasma 6 task manager plasmoid with zoom effect"
arch=('x86_64')
url="https://github.com/vickoc911/org.vicko.wavetask"
license=('GPL-3.0-only')

depends=(
  'qt6-base'
  'qt6-declarative'
  'ki18n'
  'kservice'
  'kwindowsystem'
  'kconfig'
  'kconfigwidgets'
  'knotifications'
  'kio'
  'kcoreaddons'
  'kitemmodels'
  'libplasma'
  'plasma-activities'
  'plasma-activities-stats'
  'plasma-pa'
  'plasma-workspace'
  'libksysguard'
  'kwin'
  'libepoxy'
  'libdrm'
)

makedepends=(
  'git'
  'cmake'
  'extra-cmake-modules'
  'gcc'
  'vulkan-headers'
)

conflicts=("$_pkgname")
provides=("$_pkgname=$pkgver")

_pkgsrc="$_pkgname"
source=(
  "$_pkgsrc::git+$url.git"
  'blur-permanent.patch'
  'tahoe-blur-corner.patch'
  'macos-frame.patch'
)
sha256sums=(
  'SKIP'
  '38fc4eb35400044845902082f3d8c11b98f9a6901f8e423611a967142dfb44d3'
  '947439591bf41860098531a915d098323cb1672d56da5bea523184a4b73105e2'
  'e0275eea810ed016e3777e3e0344df4bcbae872e03b9d88594d96207f733a642'
)

options=('!debug')

pkgver() {
  cd "$_pkgsrc"
  git describe --long --tags --abbrev=7 | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
}

prepare() {
  cd "$_pkgsrc"
  # Mantener el blur permanente en skins que lo habilitan (p. ej. Tahoe Dark).
  patch -p1 < "$srcdir/blur-permanent.patch"
  # Redondear un poco más la máscara de blur para que no sobresalga del fondo.
  patch -p1 < "$srcdir/tahoe-blur-corner.patch"
  # Marco vectorial opcional estilo macOS (Rectangle), activable por skin.
  patch -p1 < "$srcdir/macos-frame.patch"
  # Skin extra "Tahoe Blur": blur nativo de KWin sin imagen de fondo. Son
  # archivos nuevos, así que se copian desde el repo (no es un parche).
  cp -a "$startdir/skins/Tahoe Blur" package/contents/skins/
}

build() {
  cd "$_pkgsrc"
  cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
  cmake --build build -j$(nproc)
}

package() {
  cd "$_pkgsrc"
  DESTDIR="$pkgdir" cmake --install build
}
