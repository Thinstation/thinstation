# Maintainer: Michele Spagnuolo <mikispag@gmail.com>

pkgname=jmtpfs
pkgver=0.5
pkgrel=3
license=('GPL3')
pkgdesc='FUSE and libmtp based filesystem for accessing MTP (Media Transfer Protocol) devices'
arch=('x86_64' 'armv7h')
url=https://github.com/JasonFerrara/jmtpfs
depends=('fuse' 'libmtp')
source=("$url/archive/v$pkgver/jmtpfs-v$pkgver.tar.gz")
sha512sums=('1997d202199af59ae2138701855864e4dab624fff4feac08ea98e3e4ed6c39e4181d8f9fec35db0e83570f48de204f3d00e1b0d2244ec677f77a99b1dc9c38b3')

build() {
  cd jmtpfs-$pkgver
  ./configure CXXFLAGS=-lpthread --prefix=/usr
  make
}

package() {
  cd jmtpfs-$pkgver
  make DESTDIR="$pkgdir" install

  ln -s jmtpfs "$pkgdir"/usr/bin/mount.jmtpfs
  ln -s jmtpfs "$pkgdir"/usr/bin/mount.fuse.jmtpfs
}
