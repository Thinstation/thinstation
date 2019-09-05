#!/bin/sh -
#@ Update protocols and services from IANA.
#@ Taken from ArchLinux script written by Gaetan Bisson.  Adjusted for CRUX.

awk=awk
curl=curl
url_pn='https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xml'
url_snpn="https://www.iana.org/assignments/service-names-port-numbers/\
service-names-port-numbers.xml"

download() {
	datetime=`date +'%FT%T%z'`
	echo 'Downloading protocols'
	${curl} -o protocols.xml ${url_pn}
	[ ${?} -eq 0 ] || exit 20
	echo 'Downloading services'
	${curl} -o services.xml ${url_snpn}
	[ ${?} -eq 0 ] || exit 21
}

process() {
	echo 'Processing protocols'
	${awk} -F "[<>]" -v URL="${url_pn}" -v DT="${datetime}" '
		BEGIN{
			print "# /etc/protocols, created " DT
			print "# Source: " URL
		}
		/<record/ {v = n = ""}
		/<value/ {v = $3}
		/<name/ && $3!~/ / {n = $3}
		/<\/record/ && n && v != ""{
			printf "%-12s %3i %s\n", tolower(n), v, n
		}
	' < protocols.xml > protocols.new
	[ ${?} -eq 0 ] || exit 30

	echo 'Processing services'
	${awk} -F "[<>]" -v URL="${url_snpn}" -v DT="${datetime}" '
		BEGIN{
			print "# /etc/services, created " DT
			print "# Source: " URL
		}
		/<record/ {n = u = p = c = ""}
		/<name/ && !/\(/ {n = $3}
		/<number/ {u = $3}
		/<protocol/ {p = $3}
		/Unassigned/ || /Reserved/ || /historic/ {c = 1}
		/<\/record/ && n && u && p && !c{
			printf "%-15s %5i/%s\n", n, u, p
		}
	' < services.xml > services.new
	[ ${?} -eq 0 ] || exit 31
}

update() {
	mv protocols.new protocols
	[ ${?} -eq 0 ] || exit 40
	mv services.new services
	[ ${?} -eq 0 ] || exit 41
	rm -f protocols.xml services.xml
	[ ${?} -eq 0 ] || exit 42
}

download
process
update
