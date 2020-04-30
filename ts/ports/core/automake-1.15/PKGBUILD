# Maintainer: dracorp aka Piotr Rogoza <piotr.r.public at gmail.com>

pkgname=automake-1.15
_pkgname=automake
pkgver=1.15.1
_pkgver=1.15
pkgrel=2
pkgdesc="A GNU tool for automatically creating Makefiles"
arch=('any')
license=('GPL')
url="https://www.gnu.org/software/automake"
groups=('base-devel')
depends=('perl' 'bash')
makedepends=('autoconf')
provides=("automake=1.15")
options=(!emptydirs)
source=("ftp://ftp.gnu.org/gnu/${_pkgname}/${_pkgname}-${pkgver}.tar.gz")
sha256sums=('988e32527abe052307d21c8ca000aa238b914df363a617e38f4fb89f5abf6260')

build() {
  cd "$srcdir"/${_pkgname}-$pkgver
  ./configure --build=$CHOST --prefix=/usr
  make
}

package() {
  cd "$srcdir"/${_pkgname}-$pkgver
  make DESTDIR="$pkgdir" install

  rm -f "$pkgdir"/usr/bin/{automake,aclocal}
  rm -rf "$pkgdir"/usr/share/aclocal
  rm -fv "$pkgdir"/usr/share/man/man1/{automake,aclocal}.1*

  rm -rf "$pkgdir"/usr/share/info
  rm -rf "$pkgdir"/usr/share/doc
}
