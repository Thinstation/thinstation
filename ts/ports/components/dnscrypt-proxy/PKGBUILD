# Maintainer: David Runge <dave@sleepmap.de>
# Contributor: Felix Yan <felixonmars@archlinux.org>
# Contributor: Techlive Zheng <techlivezheng at gmail dot com>
# Contributor: peace4all <markspost at rocketmail dot com>

pkgname=dnscrypt-proxy
pkgver=2.0.25
pkgrel=2
pkgdesc="DNS proxy, supporting encrypted DNS protocols such as DNSCrypt v2 and DNS-over-HTTPS"
arch=('x86_64')
url="https://dnscrypt.info"
license=('custom:ISC')
depends=('glibc')
makedepends=('git' 'go-pie')
install="${pkgname}.install"
backup=("etc/${pkgname}/${pkgname}.toml"
        "etc/${pkgname}/blacklist.txt"
        "etc/${pkgname}/cloaking-rules.txt"
        "etc/${pkgname}/forwarding-rules.txt"
        "etc/${pkgname}/ip-blacklist.txt"
        "etc/${pkgname}/whitelist.txt"
)
source=("${pkgname}-${pkgver}.tar.gz::https://github.com/jedisct1/${pkgname}/archive/${pkgver}.tar.gz"
        "${pkgname}.service"
        "${pkgname}.socket"
        'configuration.diff')
sha512sums=('74a47b013e15cbdcf8691bf3618cce40149f9832f6fc4c2cbfb6af2a72b4ecb52b068a150999771a77fcf4fdb49c64dabd127c5101ae29fb86723bc30c946133'
            'aa871927bbc37d0c629e75a39cbfe50ce6062a19d7fe5b61895c604d6a480ba8f484cf207943c6ee7bf2dc3c7799d8f7a2b1ea5c8e586920c97730a7c503985e'
            '56a56e87032da9316b392b0613124b0743673041596c717005541ae9b3994c7fc16c02497ea773d321f45d8e0f9ea8fda00783062cef4d5c8277b5b6f7cb10d5'
            '6144f3d33f3d85c9a4e5573f88e92f1b9d7118fd654072eeac6c3f76085086d4b2464e1d3579d8501153f453bc5125859d148fc3b3486d26368d1f51911aeb33')

prepare() {
  cd "$pkgname-$pkgver"
  patch -Np1 -i ../configuration.diff
  # create empty ip-blacklist.txt
  touch "${pkgname}/ip-blacklist.txt"
  # symlink upstream's vendor to src
  ln -sfv vendor src
  rm -v go.mod
}

build() {
  cd "$pkgname-$pkgver"
  # set GOPATH
  export GOPATH=$(pwd)
  cd "${pkgname}"
  go build -ldflags="-linkmode external -extldflags ${LDFLAGS} -s -w"
}

package() {
  cd $pkgname-$pkgver
  # executable
  install -vDm 755 "${pkgname}/${pkgname}" -t "${pkgdir}/usr/bin/"
  # configuration
  install -vDm 644 "${pkgname}/example-${pkgname}.toml" \
    "${pkgdir}/etc/${pkgname}/${pkgname}.toml"
  install -vDm 644 "${pkgname}/example-blacklist.txt" \
    "${pkgdir}/etc/${pkgname}/blacklist.txt"
  install -vDm 644 "${pkgname}/example-cloaking-rules.txt" \
    "${pkgdir}/etc/${pkgname}/cloaking-rules.txt"
  install -vDm 644 "${pkgname}/example-forwarding-rules.txt" \
    "${pkgdir}/etc/${pkgname}/forwarding-rules.txt"
  install -vDm 644 "${pkgname}/ip-blacklist.txt" \
    "${pkgdir}/etc/${pkgname}/ip-blacklist.txt"
  install -vDm 644 "${pkgname}/example-whitelist.txt" \
    "${pkgdir}/etc/${pkgname}/whitelist.txt"
  # systemd service/socket
  install -vDm 644 "../${pkgname}."{service,socket} \
    -t "${pkgdir}/usr/lib/systemd/system/"
  # license
  install -vDm 644 LICENSE -t "${pkgdir}/usr/share/licenses/${pkgname}"
  # docs
  install -vDm 644 {ChangeLog,README.md} \
    -t "${pkgdir}/usr/share/doc/${pkgname}"
}
# vim:set ts=2 sw=2 et:
