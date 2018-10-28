<html>

<head>
  <title>:: ThinStation ::</title>
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
  <link href="style.css" rel="stylesheet" type="text/css">
</head>

<body bgcolor="#FFFFFF" leftmargin="0" topmargin="0" marginwidth="0" marginheight="0">

  <table border="0" cellpadding="0" cellspacing="0" width="650" summary="header">
    <tbody>
      <tr>
        
      <td> <a href="index.html"><img src="images/ts_logo.jpg" width="650" height="153" border="0" alt="ThinStation logo"></a> 
      </td>
      </tr>
    </tbody>
  </table>

  
<h2>ThinStation ${TS_VERSION} on ${CLIENT_NAME} :: Main page</h2>
<p> This is the web administration main console; choose what you want to supervise:</p>
<a href="/cgi-bin/SysInfo.cgi">System information</a><br>
<a href="/cgi-bin/TSVariables.cgi">ThinStation variables</a><br>
<a href="/cgi-bin/BootMessages.cgi">Boot messages</a><br>
<a href="/cgi-bin/SysLog.cgi">Syslog messages</a><br>
${XORG}
${LSHW}
${ICA}
<a href="/cgi-bin/Administration.cgi">Administration</a><br>
<a href="/cgi-bin/CdControl.cgi">Control CD Player</a><br>
${XORGVNC}
<a href="/cgi-bin/Telnet.cgi">Telnet to Localhost</a><br>
<br>
<pre>&nbsp;</pre>

</body>

</html>
