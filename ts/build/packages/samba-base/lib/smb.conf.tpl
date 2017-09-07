[global]

# workgroup = NT-Domain-Name or Workgroup-Name
   workgroup = $SAMBA_WORKGROUP

# server string is the equivalent of the NT Description field
   server string = TS $TS_VERSION - $CLIENT_IP

# This option is important for security. It allows you to restrict
# connections to machines which are on your local network. The
# following example restricts access to two C class networks and
# the "loopback" interface. For more examples of the syntax see
# the smb.conf man page
;   hosts allow = 192.168.1. 192.168.2. 127.

# if you want to automatically load your printer list rather
# than setting them up individually then you'll need this
   printcap name = $LPR_ROOT/etc/printcap
   load printers = yes
#   load printers = no

# It should not be necessary to spell out the print system type unless
# yours is non-standard. Currently supported print systems include:
# bsd, sysv, plp, lprng, aix, hpux, qnx
   printing = lprng

# Uncomment this if you want a guest account, you must add this to /etc/passwd
# otherwise the user "nobody" is used
;  guest account = pcguest

# this tells Samba to use a separate log file for each machine
# that connects
log file = /var/log/samba.log

lock directory = /var/lock

# Put a capping on the size of the log files (in Kb).
   max log size = 10

# Security mode. Most people will want user level security. See
# security_level.txt for details.
   security = $SAMBA_SECURITY

# Use password server option only with security = server
# The argument list may include:
#   password server = My_PDC_Name [My_BDC_Name] [My_Next_BDC_Name]
# or to auto-locate the domain controller/s
#   password server = *
   password server = $SAMBA_SERVER

# Password Level allows matching of _n_ characters of the password for
# all combinations of upper and lower case.
;  password level = 8
;  username level = 8

# You may wish to use password encryption. Please read
# ENCRYPTION.txt, Win95.txt and WinNT.txt in the Samba documentation.
# Do not enable this option unless you have read those documents
   encrypt passwords = yes
   smb passwd file = /etc/smbpassword

   private dir = /etc/samba/private
   lock directory = /var/lock
   pid directory = /var/lock

# Unix users can map to different SMB User names
;  username map = $LPR_ROOT/etc/smbusers

# Using the following line enables you to customise your configuration
# on a per machine basis. The %m gets replaced with the netbios name
# of the machine that is connecting
;   include = $SAMBA_ROOT/etc/smb.conf.%m

# This parameter will control whether or not Samba should obey PAM's
# account and session management directives. The default behavior is
# to use PAM for clear text authentication only and to ignore any
# account or session management. Note that Samba always ignores PAM
# for authentication in the case of encrypt passwords = yes

;  obey pam restrictions = yes

# Most people will find that this option gives better performance.
# See speed.txt and the manual pages for details
   socket options = TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192

# Configure Samba to use multiple interfaces
# If you have multiple network interfaces then you must list them
# here. See the man page for details.
;   interfaces = 192.168.12.2/24 192.168.13.2/24

# Configure remote browse list synchronisation here
#  request announcement to, or browse list sync from:
#	a specific host or from / to a whole subnet (see below)
;   remote browse sync = 192.168.3.25 192.168.5.255
# Cause this host to announce itself to local subnets here
;   remote announce = 192.168.1.255 192.168.2.44

# Browser Control Options:
# set local master to no if you don't want Samba to become a master
# browser on your network. Otherwise the normal election rules apply
   local master = no

# OS Level determines the precedence of this server in master browser
# elections. The default value should be reasonable
;   os level = 33

# Domain Master specifies Samba to be the Domain Master Browser. This
# allows Samba to collate browse lists between subnets. Don't use this
# if you already have a Windows NT domain controller doing this job
;   domain master = yes

# Preferred Master causes Samba to force a local browser election on startup
# and gives it a slightly higher chance of winning the election
;   preferred master = yes

# Enable this if you want Samba to be a domain logon server for
# Windows95 workstations.
;   domain logons = yes

# if you enable domain logons then you may want a per-machine or
# per user logon script
# run a specific logon batch file per workstation (machine)
;   logon script = %m.bat
# run a specific logon batch file per username
;   logon script = %U.bat

# Where to store roving profiles (only for Win95 and WinNT)
#        %L substitutes for this servers netbios name, %U is username
#        You must uncomment the [Profiles] share below
;   logon path = \\%L\Profiles\%U

# Windows Internet Name Serving Support Section:
# WINS Support - Tells the NMBD component of Samba to enable it's WINS Server
;   wins support = yes

# WINS Server - Tells the NMBD components of Samba to be a WINS Client
#	Note: Samba can be either a WINS Server, or a WINS Client, but NOT both
$WINS_ON   wins server = $SAMBA_WINS

# WINS Proxy - Tells Samba to answer name resolution queries on
# behalf of a non WINS capable client, for this to work there must be
# at least one	WINS Server on the network. The default is NO.
;   wins proxy = yes

# DNS Proxy - tells Samba whether or not to try to resolve NetBIOS names
# via DNS nslookups. The built-in default for versions 1.9.17 is yes,
# this has been changed in version 1.9.18 to no.
   dns proxy = no 

# Client signing - This controls whether the client is allowed or required to
# use SMB signing. Possible values are auto, mandatory and disabled.
;   client signing = auto

# Case Preservation can be handy - system default is _no_
# NOTE: These can be set on a per share basis
;  preserve case = no
;  short preserve case = no
# Default case is normally upper case for all DOS files
;  default case = lower
# Be very careful with case sensitivity - it can break things!
;  case sensitive = no

print command =      $LPR_ROOT/bin/lpr  -P%p -r %s
lpq command   =      $LPR_ROOT/bin/lpq  -P%p
lprm command  =      $LPR_ROOT/bin/lprm -P%p %j
lppause command =    $LPR_ROOT/bin/lpc hold %p %j
lpresume command =   $LPR_ROOT/bin/lpc release %p %j
queuepause command = $LPR_ROOT/bin/lpc  stop %p
queueresume command = $LPR_ROOT/bin/lpc start %p

#============================ Share Definitions ==============================

$SAMBA_PRINTER[printers]
$SAMBA_PRINTER    comment = All Printers
$SAMBA_PRINTER    path = /var/spool/samba
$SAMBA_PRINTER    browseable = no
$SAMBA_PRINTER    public = $SAMBA_PUBLIC
$SAMBA_PRINTER    printable = yes

$SAMBA_HARDDISK[harddisk]
$SAMBA_HARDDISK    comment = Hard disk
$SAMBA_HARDDISK    path = /mnt/disc
$SAMBA_HARDDISK    read only = no
$SAMBA_HARDDISK    public = $SAMBA_PUBLIC

$SAMBA_CDROM[cdrom]
$SAMBA_CDROM    comment = CDROM
$SAMBA_CDROM    path = /mnt/cdrom0
$SAMBA_CDROM    read only = yes
$SAMBA_CDROM    public = $SAMBA_PUBLIC

$SAMBA_FLOPPY[floppy]
$SAMBA_FLOPPY   comment = Floppy
$SAMBA_FLOPPY   path = /mnt/floppy
$SAMBA_FLOPPY   read only = no
$SAMBA_FLOPPY   public = $SAMBA_PUBLIC

$SAMBA_USB[usb]
$SAMBA_USB   comment = USB Device
$SAMBA_USB   path = /mnt/usbdevice
$SAMBA_USB   read only = no
$SAMBA_USB   public = $SAMBA_PUBLIC
