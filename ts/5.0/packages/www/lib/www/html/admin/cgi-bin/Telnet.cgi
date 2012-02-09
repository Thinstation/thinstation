#! /bin/sh

. /etc/thinstation.env
. $TS_GLOBAL

header

echo '<table BORDER=0 CELLSPACING=5 CELLPADDING=5 COLS=2 WIDTH="100%" NOSAVE >
<tr NOSAVE>
<td ALIGN=LEFT VALIGN=TOP WIDTH="70%" BGCOLOR="#FFFFFF" NOSAVE>
<center>
<!-- Here begins the applet code -->
<BR>
<BR>
Use the Button below to open the <b>Telnet Window</b> and connect to the host.<BR>

<applet CODEBASE="." 
ARCHIVE="../jta20_o.jar" 
CODE="de.mud.jta.Applet" 
WIDTH=100 HEIGHT=25>

<!-- The value below is relative to the CODEBASE -->
<PARAM NAME="config" VALUE="../applet.conf">

<!-- make sure, non-java-capable browser get a message: -->
<br><b>Your Browser seems to have no <a href="http://java.sun.com/">Java</a>
support. Please get a new browser or enable Java to see this applet!</b>
<br></applet>

<!-- End of applet code -->
</center>
</td>
</tr>
</table>'

trailer
