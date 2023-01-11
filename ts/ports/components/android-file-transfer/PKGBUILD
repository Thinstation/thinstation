# Contributor: yaroslav <proninyaroslav@mail.ru>
# Contributor: Askhat Bakarov <sirocco{at}ngs{dot}ru>

pkgname=android-file-transfer
pkgver=4.2
pkgrel=3
pkgdesc='Android MTP client with minimalistic UI'
arch=(x86_64)
url='https://whoozle.github.io/android-file-transfer-linux'
license=(GPL3)
depends=(qt5-base fuse2 libxkbcommon-x11 hicolor-icon-theme file)
makedepends=(cmake qt5-tools)
source=(android-file-transfer-$pkgver.tar.gz::https://github.com/whoozle/android-file-transfer-linux/archive/v$pkgver.tar.gz)
sha256sums=('cc607d68e8a18273c9b56975a70a0e68fbdf9d5b903b2727a345a605ff48a19f')

build() {
  cd android-file-transfer-linux-$pkgver
  cmake -DCMAKE_INSTALL_PREFIX=/usr . -DCMAKE_CXX_FLAGS="$CXXFLAGS -ffat-lto-objects"
  make
}

package() {
  cd android-file-transfer-linux-$pkgver
  make DESTDIR="$pkgdir/" install
}
