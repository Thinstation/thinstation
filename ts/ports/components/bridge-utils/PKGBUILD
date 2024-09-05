# Maintainer: Christian Hesse <mail@eworm.de>
# Contributor: Judd Vinet <judd@archlinux.org>

pkgname=bridge-utils
pkgver=1.7.1
pkgrel=2
pkgdesc="Utilities for configuring the Linux ethernet bridge"
arch=('x86_64')
url='https://wiki.linuxfoundation.org/networking/bridge'
license=('GPL')
depends=('glibc')
validpgpkeys=('9F6FC345B05BE7E766B83C8F80A77F6095CDE47E')	# Stephen Hemminger (Microsoft corporate) <sthemmin@microsoft.com>
source=("https://mirrors.edge.kernel.org/pub/linux/utils/net/${pkgname}/${pkgname}-${pkgver}.tar."{xz,sign})
sha256sums=('a61d8be4f1a1405c60c8ef38d544f0c18c05b33b9b07e5b4b31033536165e60e'
            'SKIP')

prepare() {
  cd "${srcdir}/${pkgname}-${pkgver}"

  aclocal
  autoconf
}

build() {
  cd "${srcdir}/${pkgname}-${pkgver}"

  ./configure \
    --prefix=/usr \
    --sbindir=/usr/bin \
    --sysconfdir=/etc
  make
}

package() {
  cd "${srcdir}/${pkgname}-${pkgver}"

  make DESTDIR="${pkgdir}" install
}
