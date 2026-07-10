# Maintainer: Keqwerty <keqwerty@yahoo.com>

_pkgname=wavetask
pkgname="$_pkgname-git"
pkgver=1.4.r16.g68318fd
pkgrel=1
pkgdesc="A Plasma 6 task manager plasmoid with zoom effect (macOS Dock skin)"
arch=('x86_64')
url="https://github.com/Keqwerty/wavetask-fixed"
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
# Se clona este repositorio de empaquetado; el árbol de fuentes del plasmoide,
# ya con todos los cambios aplicados (blur permanente, esquinas de la máscara,
# marco vectorial estilo macOS, sincronización de tamaño del dock) y el skin
# "macOS Dock", vive dentro del clon en wavetask-source/.
source=("$_pkgsrc::git+$url.git")
sha256sums=('SKIP')

options=('!debug')

pkgver() {
  cd "$_pkgsrc"
  printf '1.4.r%s.g%s' "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"
}

build() {
  cd "$_pkgsrc/wavetask-source"
  cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
  cmake --build build -j$(nproc)
}

package() {
  cd "$_pkgsrc/wavetask-source"
  DESTDIR="$pkgdir" cmake --install build
}
