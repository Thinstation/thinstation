THINSTATION LIVE-CD 2.2.1

Author:        Paolo Salvan (psalvan AT users.sourceforge.net)
Company:       XVision, Italy - www.xvision.it
Last update:   2008/03/24

______________________________________________________________________________
* What is this ISO image useful for?

This ISO is useful in order to convert in the simplest way a standard PC in a
thinclient able to connect to a Windows terminal server.
You only need to burn a CD with the Thinstation ISO image, and to prepare a
floppy with the configuration.
You don't need a DHCP/TFTP server like other remote-boot thinclient solutions,
so this prebuilt is ideal for small sites or for demo-purposes, as you only
needs a few minutes to setup a thinclient, and no changes on pre-existent
servers.

This ISO image requires a standard PC with:
- pentium-class cpu and 32Mb+ of ram
- BIOS supporting boot from CD

The main features are:
- support for Terminal Services, Citrix, X, telnet, ssh, tn5250
  sessions
- support local sound (if your terminal server support it)
- support local thinclient printing with printer network port redirection

______________________________________________________________________________
* How do I use it?

- burn 'LiveCD.desktop.iso' (in the 'CD/' dir) on a CD
- Insert CD and floppy in the PC you want to convert to a thin-client
- Set "CD-Rom" as the first boot device in the thin-client BIOS
- Finish! ;o) After a while, it should show the session launching screen

The CD has and inbuilt default session, but you may want to tweak that by using
your own thinstation.conf.user. The CD will look for a 
thinstation.profile\thinstation.conf.user on the CD, local hard drives, USB stick and floppy.
The example here is for a floppy, but a usb stick works just the same.
- copy the contents of the 'Floppy/' dir in a clean floppy
- edit A:\thinstation.profile\thinstation.conf.user to fit your needs (see below)
- Insert CD and floppy in the PC you want to convert to a thin-client
- Set "CD-Rom" as the first boot device in the thin-client BIOS
- Finish! ;o) After a while, it should show the session launching screen

______________________________________________________________________________
* How do I configure thinstation.conf.user?

Check the keyboard (KEYBOARD_MAP=...) and screen (SCREEN_RESOLUTION=...)
configuration line, and then:

- If you want to connect to a 'Terminal services' session, uncomment these lines:

  SESSION_?_TYPE="rdesktop"
  SESSION_?_RDESKTOP_SERVER="<server name>"    <--- put here your server

- If you want to connect to a 'Citrix ICA' session, uncomment these lines:

  SESSION_?_TYPE="ica"

  ...and edit

  SESSION_?_ICA_APPLICATION_SET="<application name>"

  or

  SESSION_?_ICA_SERVER="<server name>"

  (note: don't set both, only one of them)

- If you want to connect to a 'X' session of a UNIX server, uncomment
  these lines:

  SESSION_?_TYPE="x"
  SESSION_?_X_SERVER="<server name>"    <--- put here your server
  SESSION_?_X_OPTIONS=

  SCREEN_X_FONT_SERVER="<font server name>:7100" <--- put here your font server

  Note: for X sessions to work, your server should be configured to accept
  "-query" requests, and can expose a font server on port 7100

IMPORTANT NOTE ABOUT SESSION NUMBERING:

You can have one or multiple sessions; please be sure that your first session
have params starting with "SESSION_0_...", the second "SESSION_1_..." and so on.

Every session can have a "title" that will be displayed in the thinstation
session launcher menu, just add a "SESSION_?_TITLE=..." line.

______________________________________________________________________________
* ...And what if I want to use only the CD, without the floppy?

You can use the CD without any extra config files, but if you want to change the
settings in your thinstation.conf.user file and keep them with the CD, you
can burn the thinstation.conf.user file directly inside the CD, as
ThinStation will search this file not only in the floppy but in the cd also.

You'll find all you need to do this in the RebuildIsoWithConf\ folder:
- go in it
- copy all the files you find inside the LiveCD in the cd-files\ folder
- copy also the thinstation.profile/ folder you precedently wrote inside the floppy
  (so you should have a 'cd-files\thinstation.profile\thinstation.conf.user' file)
- start the rebuild-iso.bat script
- now you will find a new LiveCD.desktop.iso with your conf file
  hard-written inside it!

A simpler way would be to edit the supplied .iso file with an ISO editor, add
the thinstation.conf.user file and burn the new iso; BTW, I got no success as,
after editing, the ISO editor change the absolute position of "isolinux.bin",
and the CD won't boot anymore...Let me know if you are more lucky than me.

______________________________________________________________________________
* Can I install it in a hard-disk?

Yes, you can; in short:
- Format the first partition of your HD with VFAT file-system
  (FAT/FAT32 file system with long file names support),
  and make it "active"
- Copy all the files of your CD and floppy in this partition 
- Make it bootable using "syslinux" (http://syslinux.zytor.com/):
  syslinux X:
  (where X is the just-formatted unit... be aware!)
- Boot it!

Note: the supplied prebuilt will always search the ".conf" file in HD, CD, USB, floppy
(in this order), so you can for example insert a floppy at boot time to override
some particular params of the HD .conf file.

______________________________________________________________________________
* How can I rebuild this ISO image from the official Thinstation package?

If you want to build your custom 'thinstation.iso' image (ie if you want to
have a local windows manager, to share thin-client local resources with Samba,
to have sound, to use particular network services), you can use a TS-O-Matic or
build you own on your linux box.
______________________________________________________________________________
* How can I rebuild this ISO image on a TS-O-Matic?

Select one of the TS-O-Matics from the Thinstation homesite (thinstation.org)
Ensure that 2.2.1 is selected in the version drop-down on the left hand menu
Go to the 'Load Files' Tab
Select Browse next to the Upload box, and browse for your LiveCD.desktop.build
Press upload to upload these settings
You can now alter anything you want via the various tabs
When ready click 'Build' (the spanner & screwdriver)
If you have anything selected that requires an EULA (eg. ica, java), please accept (tick)
Wait awhile - it's building your image
On the BuildTime screen, select the 'Load Files' tab
Select Browse next to the Upload box, and browse for your LiveCD.desktop.builtime
Press upload to upload these settings
You can edit the settings in the edit box on the BuildTime tab
Click 'Write Image' (CD) to generate your images
Download your own customised iso from the 'ISO' tab

______________________________________________________________________________
* How can I rebuild this ISO image on my own linux box?

To build your own you need a linux box  and the full 'Thinstation-2.2.1.tar.gz' package.
These are the steps to recompile the boot image:
- [download Thinstation-2.2.1.tar.gz]
- tar zxvf Thinstation-2.2.1.tar.gz
- cd thinstation-2.2.1
- [copy here 'BuildFiles\LiveCD.desktop.build'
  and 'BuildFiles\LiveCD.desktop.buildtime' supplied with the
  prebuilt, and if necessary edit them]
- build LiveCD.desktop.build
After a while, in the 'boot-images/iso' folder you will find the new
thinstation.iso file.
Look the FAQ for more detailed info.

______________________________________________________________________________
* Useful links

- ThinStation - a light, full featured linux based thin client OS
  http://thinstation.sourceforge.net/
    