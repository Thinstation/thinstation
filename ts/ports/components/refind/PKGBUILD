# Maintainer: nl6720 <nl6720@gmail.com>
# Contributor: Keshav Amburay <(the ddoott ridikulus ddoott rat) (aatt) (gemmaeiil) (ddoott) (ccoomm)>
# Contributor: Tobias Powalowski <tpowa@archlinux.org>
# Contributor: David Runge <dvzrv@archlinux.org>

pkgname='refind-efi-git'
pkgver=0.12.0.r692.g4a84fce
pkgrel=2
pkgdesc='rEFInd Boot Manager - git version'
url='https://www.rodsbooks.com/refind/'
arch=('any')
license=('BSD' 'CCPL' 'FDL1.3' 'GPL2' 'GPL3' 'LGPL3')
depends=('bash' 'dosfstools' 'efibootmgr' 'which')
makedepends=('git' 'gnu-efi-libs')
optdepends=('gptfdisk: for finding non-vfat ESP with refind-install'
            'imagemagick: for refind-mkfont'
            'openssl: for generating local certificates with refind-install'
            'preloader-signed: pre-signed Secure Boot shim loader'
            'python: for refind-mkdefault'
            'sudo: for privilege elevation in refind-install and refind-mkdefault'
            'shim-signed: pre-signed Secure Boot shim loader'
            'sbsigntools: for EFI binary signing with refind-install')
options=('!makeflags')
conflicts=("${pkgname%-efi-git}" "${pkgname%-git}")
provides=("${pkgname%-efi-git}=${pkgver}" "${pkgname%-git}=${pkgver}")
source=('refind::git+https://git.code.sf.net/p/refind/code#branch=master')
sha512sums=('SKIP')
_arch='x64'

pkgver() {
	cd "${srcdir}/${pkgname%-efi-git}/"
	printf '%s.r%s.g%s' "$(grep -Po 'REFIND_VERSION L"\K[\d.]+' "${srcdir}/${pkgname%-efi-git}/include/version.h")" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

prepare() {
	cd "${srcdir}/${pkgname%-efi-git}/"
	# removing the path prefix from the css reference, so that the css can live in the same directory
	sed -e 's|../Styles/||g' -i "docs/${pkgname%-efi-git}/"*.html
	# hardcode RefindDir, so that refind-install can find refind_x64.efi
	sed -e 's|RefindDir=\"\$ThisDir/refind\"|RefindDir="/usr/share/refind/"|g' -i refind-install
}

build() {
	cd "${srcdir}/${pkgname%-efi-git}/"
	make
	make gptsync
	make fs
}

package() {
	cd "${srcdir}/${pkgname%-efi-git}/"
	# the install target calls refind-install, therefore we install things manually

	# efi binaries
	install -vDm 0644 refind/*.efi -t "${pkgdir}/usr/share/${pkgname%-efi-git}"
	install -vDm 0644 drivers_*/*.efi -t "${pkgdir}/usr/share/refind/drivers_${_arch}"
	install -vDm 0644 gptsync/*.efi -t "${pkgdir}/usr/share/${pkgname%-efi-git}/tools_${_arch}"
	# sample config
	install -vDm 0644 "${pkgname%-efi-git}.conf-sample" -t "${pkgdir}/usr/share/${pkgname%-efi-git}"
	# keys
	install -vDm 0644 keys/*{cer,crt} -t "${pkgdir}/usr/share/${pkgname%-efi-git}/keys"
	# keysdir
	install -vdm 0640 "${pkgdir}/etc/refind.d/keys"
	# icons
	install -vDm 0644 icons/*.png -t "${pkgdir}/usr/share/${pkgname%-efi-git}/icons"
	install -vDm 0644 icons/svg/*.svg -t "${pkgdir}/usr/share/${pkgname%-efi-git}/icons/svg"
	# scripts
	install -vDm 0755 {refind-{install,mkdefault},mkrlconf,mvrefind} -t "${pkgdir}/usr/bin"
	install -vDm 0755 fonts/mkfont.sh "${pkgdir}/usr/bin/${pkgname%-efi-git}-mkfont"
	# man pages
	install -vDm 0644 docs/man/*.8 -t "${pkgdir}/usr/share/man/man8"
	# docs
	install -vDm 0644 {CREDITS,NEWS,README}.txt -t "${pkgdir}/usr/share/doc/${pkgname%-efi-git}"
	install -vDm 0755 fonts/README.txt "${pkgdir}/usr/share/doc/${pkgname%-efi-git}/README.${pkgname%-efi-git}-mkfont.txt"
	install -vDm 0755 icons/README "${pkgdir}/usr/share/doc/${pkgname%-efi-git}/README.icons.txt"
	install -vDm 0755 keys/README.txt "${pkgdir}/usr/share/doc/${pkgname%-efi-git}/README.keys.txt"
	install -vDm 0644 "docs/${pkgname%-efi-git}/"*.{html,png,svg,txt} -t "${pkgdir}/usr/share/doc/${pkgname%-efi-git}/html"
	install -vDm 0644 docs/Styles/*.css -t "${pkgdir}/usr/share/doc/${pkgname%-efi-git}/html"
	# license
	install -vDm 0644 LICENSE.txt -t "${pkgdir}/usr/share/licenses/${pkgname}"
}
