Adding own entries to Core Distro Files  (TS 2.2)

 * If you need to add a entry to a core file such as passwd or services you
   can do this by creating a directory in your package called contribs.  In this 
   folder specify the directory structure and file you wish to append.

   This can allow several contributed packages to work in conjunction, each independantly
   adding there own services or passwd entries.

   ie  
   PACKAGENAME/build/contribs/etc/services

   This won't work with files which are symlinked, such as the hosts file as this isn't created
   until runtime.

Adding commerical packages in TS (TS 2.2)

 * We cannot place commerical binaries into TS.  TO get around this you can create an install and
   remove package in the package directory.  ie

  packages/ica/build
  packages/ica/build/install
  packages/ica/build/remove
  packages/ica/build/license
  packages/ica/build/installed

  the license file should be symlinked to any eula that must be accepted before including the package
  in a build.  Additionally the build script looks for the parameters

param   xxxurl  url_to_package_download

the build script will then call the install script to set up the package.


Module Package Dependencies

 * kernel/dependencies_package contains packages names which inside list modules.
  This allows you to specify modules to be added to image to allow the package 
  to work properly.  Examples are the autofs package which includes automatically
  the nfs module.

Module Dependencies

 * kernel/dependencies_module contains module names which inside list packages.
  This allows you to specify packages to be added to image to allow the module 
  to work properly.  Examples are the pcmcia module, which includes automatically
  the pcmcia package.

  package pcmcia

  You can also include modules which are dependant on other modules within this file.
  ie the usbcore file includes the lines

  module ehci-hcd
  module ohci-hcd
  module uhci-hcd

Adding full Locale support (TS 2.2)

  * If file

    PACKAGENAME/build/fulllocales

    exists then full locale support will be added to package


Package Dependencies

 * In each package there is a depenencies file which lists dependant packages which
   are automatically added if this package is included.


Package Cross Dependencies (TS 2.2)

 * The depenencies file can now support cross dependencies.  This means package is only
   selected if both first and second package is included.  An example of this is ica_pnagent.
   The package ica/dependencies file looks like this.

   base
   messagebox
   glibc225
   ica_pnagent firefox

   This means base, messagebox and glibc225 are all added automatically.  However, ica_pnagent
   is only added if the firefox package is also selected.

Custom Keymaps

 * It is possible to do add-hock modifications to the keymaps by adding in your own
   keymap mods in an xmod file.  If the file keymaps-xx/x-common/lib/kmaps/XXXX.xmod file exists when
   starting a application it checks for this file and modifies the loaded keymap with any entries.
   An example of this is

  keymaps-en_nz/x-common/lib/kmaps/en_nz.xmod

Configuration Files

*  As of 2.2 the build process now generates thinstation.conf.sample by
   appending all files called <package>.conf from the conf directory where
   the <package> has been selected in the build.conf. The conf directory is
   a copy of the packages/<package>/build/conf directory.

   Hence, all packages for 2.2beta9 onwards, that require parameters,
   should have a /build/conf directory and it should contain at least 1
   file called <seq><package> (the sequence number is the order the files
   will be included in the build).

Special Parameters

* There is some special flags which some packages use to set certain options

  package/cmd/PACKAGE.getip               Brings up a dialog box for a server ip
  package/cmd/PACKAGE.getuser             Brings up a dialog box for a user name
  package/cmd/PACKAGE.wm                  Tells scripting to create package as a window manager
  package/cmd/PACKAGE.change_server_type  Tells scripting to use TITLE or APPLICATION_SET name as the
                                          server name, used for 2x and ica packages
  package/cmd/PACKAGE.global              General command to start application
  package/cmd/PACKAGE.menu                Command to start application from replimenu
  package/cmd/PACKAGE.console             Command to start application from console
  package/cmd/PACKAGE.window              Command to start application in a window
  package/cmd/PACKAGE.fullscreen          Command to start application in fullscreen
