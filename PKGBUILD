# Maintainer: Issa M. Omais <me0@ioplus.dev>

_pkgname=wavetask
pkgname="$_pkgname-git"
pkgver=1.4.r4.g0ba7241
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
  'cmake'
  'extra-cmake-modules'
  'gcc'
  'vulkan-headers'
)

conflicts=("$_pkgname")
provides=("$_pkgname=$pkgver")

_pkgsrc="$_pkgname"
# El árbol de fuentes va incrustado en el repo (wavetask-source/): base upstream
# 0ba7241 con todos los cambios ya aplicados —blur permanente, esquinas de la
# máscara, marco vectorial estilo macOS, sincronización de tamaño del dock— y el
# skin "macOS Dock". No se clona nada ni se aplican parches en tiempo de build.
source=()
sha256sums=()

options=('!debug')

prepare() {
  # Copiar el árbol de fuentes ya parcheado al directorio de compilación.
  rm -rf "$srcdir/$_pkgsrc"
  cp -a "$startdir/wavetask-source" "$srcdir/$_pkgsrc"
}

build() {
  cd "$srcdir/$_pkgsrc"
  cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
  cmake --build build -j$(nproc)
}

package() {
  cd "$srcdir/$_pkgsrc"
  DESTDIR="$pkgdir" cmake --install build
}
