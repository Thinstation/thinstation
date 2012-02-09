#! /bin/sh

. /etc/thinstation.env
. $TS_GLOBAL

header
getpostcontent

	echo '<form action="/cgi-bin/CdControl.cgi" method=post>'
	echo '<input type=submit name=action value=eject>'
	echo '<input type=submit name=action value=back>'
	echo '<input type=submit name=action value=forward>'
	echo '<input type=submit name=action value=pause>'
	echo '</form>'

	playcd "$CGI_action"

	echo '<br>'
	echo '<a href="VolControl.cgi">Volume Control</a><br>'

trailer
