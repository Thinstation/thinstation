#!/bin/sh
#
# mksslcert
#
# creates self-signed openssl certificates based on
# the local hostname or the given one
# Fallback to localhost if not set.
#
# Juergen Daubert, jue at crux dot nu


print_help() {
	echo "usage: ${0##*/} <key> <cert> [hostname]"
	echo "  key       full path to openssl private key"
	echo "  cert      full path to openssl certificate"
	echo "  hostname  host name of certificate"
}

main() {
	if [ ! "$1" -o ! "$2" ]; then
		print_help
		exit 1
	fi
	
	KEY=$1
	CRT=$2
	FQDN=$(hostname -f) || FQDN=localhost
	if [ ! -z "$3" ]; then
		FQDN="$3"
	fi
	INFO=".\n.\n.\n.\n.\n$FQDN\nroot@$FQDN"
	OPTS="req -new -nodes -x509 -days 365 -newkey rsa:2048"
	
	printf "$INFO\n" | openssl $OPTS -out $CRT -keyout $KEY 2> /dev/null
	
	if [ $? -ne 0 ]; then
		echo "Error: creating of certificate failed"
		exit 1
	else
		echo "SSL certificate $CRT with key $KEY for host $FQDN created"
		chmod 0600 $CRT $KEY 
	fi
}

main "$@"

# End of file
