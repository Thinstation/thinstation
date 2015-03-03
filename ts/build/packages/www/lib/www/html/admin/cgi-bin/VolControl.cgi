#! /bin/sh

. /etc/thinstation.env
. $TS_GLOBAL

header
getpostcontent

echo '<H3> A volume level controller for CD Player'
echo '</H3>'

	echo '<form action="/cgi-bin/VolControl.cgi" method=post>'
	echo '<input type=radio name=action value=0>0'
	echo '<input type=radio name=action value=5>5'
	echo '<input type=radio name=action value=10>10'
	echo '<input type=radio name=action value=15>15'
	echo '<input type=radio name=action value=20>20'
	echo '<input type=radio name=action value=25>25'
	echo '<input type=radio name=action value=30>30'
	echo '<input type=radio name=action value=35>35'
	echo '<input type=radio name=action value=40>40'
	echo '<input type=radio name=action value=45>45'
	echo '<input type=radio name=action value=50>50'
	echo '<input type=radio name=action value=55>55'
	echo '<input type=radio name=action value=60>60'
	echo '<input type=radio name=action value=65>65'
	echo '<input type=radio name=action value=70>70'
	echo '<input type=radio name=action value=75>75'
	echo '<input type=radio name=action value=80>80'
	echo '<input type=radio name=action value=85>85'
	echo '<input type=radio name=action value=90>90'
	echo '<input type=radio name=action value=95>95'
	echo '<input type=radio name=action value=100>100'
	echo '<input type=submit name="OK">'
	echo '</form>'

	volcontrol "$CGI_action"
	
	echo '<br>'
	echo '<a href="CdControl.cgi">Control CD Player</a><br>'

trailer
