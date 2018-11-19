#! /bin/sh
#----------------------------------------------------------------------
#      ___       ___ ___   P X E S   Universal  Linux  Thin  Client
#     /__/\\_// /__ /__    Copyright(C) 2003 by Diego Torres Milano
#    /    // \\/__  __/    All rights reserved.  http://pxes.sf.net
#
# Author: Diego Torres Milano <diego@in3.com.ar>
# $Id: admin.cgi,v 1.2 2003/10/07 03:25:47 diego Exp $
#----------------------------------------------------------------------

. /etc/thinstation.env
. $TS_GLOBAL

UPDATE=60
VERIFIED_COMMAND=
WEBDIR=/lib/www/html/admin/config

getpostcontent
header

config()
{

echo '
<style type="text/css">

#tablist{
	padding: 3px 0;
	margin-left: 0;
	margin-bottom: 0;
	margin-top: 1.1em;
	font: bold 12px Arial;
}

#tablist li{
	list-style: none;
	display: inline;
	margin: 0;
	margin-bottom: 1px;
}

#tablist li a{
	padding: 3px 0.5em;
	margin-left: 1px;
	margin-top: 1px;
	padding-top: 0px;
	padding-bottom: 0px;
	border: 1px solid #778;
	border-bottom: 1px solid #778;
	background: white;
}

#tablist li a:link, #tablist li a:visited{
	color: navy;
}

#tablist li a.current{
	background: lightyellow;
}

#tabcontentcontainer{
	width: 950px;
	float: left;
	align: top;
	/* Insert Optional Height definition here to give all the content a unified height */
	padding: 10px;
}

.tabcontent{
display:none;
}
.heading {
        font: 25px Arial;
        float: left;
        width: 300px;
}
.headingreadonly {
        font: 25px Arial;
        float: right;
        width: 575px;
}
.submitbutton {
        float: left;
}
.runtimeoptions {
        float: left;
        margin: 0px;
        background: white;
        width: 300px;
        font: 12px Arial;
}
.defaultoptions {
        float: right;
        width: 575px;
        font: 12px Arial;
        background: white;
}

</style>

<script type="text/javascript">

/***********************************************
* Tab Content script- ) Dynamic Drive DHTML code library (www.dynamicdrive.com)
* This notice MUST stay intact for legal use
* Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code
***********************************************/

//Set tab to intially be selected when page loads:
//[which tab (1=first tab), ID of tab content to display]:
var initialtab=[1, "sc1"]

////////Stop editting////////////////

function cascadedstyle(el, cssproperty, csspropertyNS){
	if (el.currentStyle)
		return el.currentStyle[cssproperty]
	else if (window.getComputedStyle){
		var elstyle=window.getComputedStyle(el, "")
		return elstyle.getPropertyValue(csspropertyNS)
	}
}

var previoustab=""

function expandcontent(cid, aobject){
	if (document.getElementById){
		highlighttab(aobject)
		detectSourceindex(aobject)
		if (previoustab!="")
			document.getElementById(previoustab).style.display="none"
		document.getElementById(cid).style.display="block"
		previoustab=cid
		if (aobject.blur)
			aobject.blur()
		return false
	}
	else
		return true
}

function highlighttab(aobject){
	if (typeof tabobjlinks=="undefined")
		collecttablinks()
	for (i=0; i<tabobjlinks.length; i++)
	  tabobjlinks[i].style.backgroundColor=initTabcolor
	  var themecolor=aobject.getAttribute("theme")? aobject.getAttribute("theme") : initTabpostcolor
	  aobject.style.backgroundColor=document.getElementById("tabcontentcontainer").style.backgroundColor=themecolor
}

function collecttablinks(){
	var tabobj=document.getElementById("tablist")
	tabobjlinks=tabobj.getElementsByTagName("A")
}

function detectSourceindex(aobject){
	for (i=0; i<tabobjlinks.length; i++){
		if (aobject==tabobjlinks[i]){
			tabsourceindex=i //source index of tab bar relative to other tabs
			break
		}
	}
}

function do_onload(){
	var cookiename=(typeof persisttype!="undefined" && persisttype=="sitewide")? "tabcontent" : window.location.pathname
	var cookiecheck=window.get_cookie && get_cookie(cookiename).indexOf("|")!=-1
	collecttablinks()
	initTabcolor=cascadedstyle(tabobjlinks[1], "backgroundColor", "background-color")
	initTabpostcolor=cascadedstyle(tabobjlinks[0], "backgroundColor", "background-color")
	if (typeof enablepersistence!="undefined" && enablepersistence && cookiecheck){
		var cookieparse=get_cookie(cookiename).split("|")
		var whichtab=cookieparse[0]
		var tabcontentid=cookieparse[1]
		expandcontent(tabcontentid, tabobjlinks[whichtab])
	}
	else
		expandcontent(initialtab[1], tabobjlinks[initialtab[0]-1])
}

if (window.addEventListener)
	window.addEventListener("load", do_onload, false)
else if (window.attachEvent)
	window.attachEvent("onload", do_onload)
else if (document.getElementById)
	window.onload=do_onload


</script>

<form method=post>
	<input type=submit name=action value=halt>
	<input type=submit name=action value=reboot>
</form>

<ul id="tablist">'

  let x=0
  (cat $WEBDIR/headings) |
  while read heading
  do
	let x=x+1
	echo '<li>'
	echo '<a class="current" onClick="return expandcontent('\''sc'$x\'', this)">'$heading'</a>'
	echo '</li>'
  done

  echo '<DIV id="tabcontentcontainer">'

  let x=0
  (cat $WEBDIR/headings) |
  while read heading
  do
  	let x=x+1
  echo '<div id="sc'$x'" class="tabcontent">'
  echo '<p class="heading" >'$heading'</p>'
  echo '<p class="headingreadonly" >Help on Options (Readonly)</p>'

  echo '<form action="/cgi-bin/Administration.cgi" method=post>'
  echo '<textarea class="runtimeoptions" rows="20" name="S'$x'" cols="80" wrap="virtual">'

  (cat $WEBDIR/"$heading".sample | cut -f1 -d= -s | cut -f1 -d_ -s | sed -e "s/#//g" | sed -e "s/ //g" | sort ) |
   while read option
   do
        if [ "$option" != "$oldoption" ]; then
		oldoption="$option"
                set | grep "^$option"_
        fi
   done
   oldoption=""
   (cat $WEBDIR/"$heading".sample | cut -f1 -d= -s | grep -v _ | sed -e "s/#//g" | sed -e "s/ //g" | sort ) |
   while read option
   do
	if [ "$option" != "$oldoption" ]; then
		oldoption="$option"
		set | grep "^$option"=
	fi
   done

   echo '</textarea>'
   echo '<input class="submitbutton" type=submit value="Save" name="action" />'
   echo '</form>'
   echo '<textarea class="defaultoptions" rows="20" name="S2'$x'" cols="80" wrap="virtual" readonly>'
   cat $WEBDIR/"$heading".sample
   echo '</textarea>'
   echo '</div>'
done

echo '</DIV>'

}
if [ -z "$CGI_password" ] && [ -z "$CGI_action" ] ; then
	echo '<form action="/cgi-bin/Administration.cgi" method=post>'
	echo 'Enter the TS Admin password to access administrative commands<br>'
	echo '<br>'
	echo 'Password: <input type=password name=password size=16><br>'
	echo '<input type=submit name=sumbit value=submit>'
	echo '</form>'
else
   if [ -z "$CGI_action" ] ; then
	if verify_password tsadmin `hex2char "$CGI_password"` ; then
	   config
	else
		echo "$?"
		echo "Invalid password"
	fi
   fi
fi
if [ -n "$CGI_action" ] ; then
	case "$CGI_action" in
		reboot)
			refresh $UPDATE
			echo "<h1>rebooting...</h1>"
			VERIFIED_COMMAND=reboot
		;;

		off|halt)
			echo "<h1>halting...</h1>"
			VERIFIED_COMMAND=halt
			;;
		Save)
		        x=`cat $WEBDIR/headings | wc -l`
			let y=0
			while [ $y -le $x ]
			do
				let y=y+1
				CGIText=`eval echo '$CGI_S'$y`
				if [ -n "$CGIText" ] ; then
					hex2char $CGIText  | sed -e s/\//g | grep = >> /tmp/ts_configs
				fi
			done
			chmod 755 /tmp/ts_configs
			if /tmp/ts_configs > /dev/null 2>&1 ; then
				for name in `cat /tmp/ts_configs | cut -f1 -d=`
				do
					deletestring="$deletestring -e /$name/d"
				done
				if [ -e $TS_USER ] ; then
					cat $TS_USER | sed $deletestring >> /tmp/ts_configs
				fi
				cat /tmp/ts_configs > $TS_USER
				rm /tmp/ts_configs
				. $TS_USER
			else
				echo "Invalid config submitted, reverting to previous"
				rm /tmp/ts_configs
			fi
			config
			;;

		*)
			echo "Invalid action: $CGI_action"
			;;
	esac
fi

trailer

if [ -n "$VERIFIED_COMMAND" ]; then
	(sleep 5; sudo -u tsadmin sudo $VERIFIED_COMMAND) &
fi
