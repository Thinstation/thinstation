# ThinStation

README - Displaying of this file can be disabled by touching `/ts/etc/READ`

Visit the ThinStation [Wiki][]

[Wiki]: https://github.com/Thinstation/thinstation/wiki/Getting-Started-with-ThinStation

This env was created for you by Donald A. Cupp Jr. from Crux and ThinStation

ThinStation itself has many many many contributors, but much thanx goes out to
Mike Eriksen, Trevor Batley, Miles Roper and Marcos Amorim

Work To Do / Work in Progress: mail to developer list if you can help

* We could really use some help on the documentation. A lot has changed since 2.2, and I am afraid the documentation has not kept up. Please create a wiki account and help others with your knowledge.

**Note that several modules have been moved inside the kernel**

## Installation
Just run `./setup_chroot`. The first time this is run, it will expand all binary packages into the right place. It will then populate all the packages that build will use to make images. Afterwards, it will just start the chroot session.

## Running
You will need to make sure you are in the chroot **Development Environment** by running `./setup-chroot`. You should then be able to `cd /build` and run `./build` to start making images. Edit build.conf and thinstation.conf.buildtime to make changes

## Compiling
First off, this is a very advanced and not required at all to use ThinStation.

The **CFLAGS** and **CXXFLAGS** can be changed by editing `/ts/etc/pkgmk.conf` and then exiting and re-entering the chroot. If you change the flags, you might want to rebuild all installed packages with `rebuild-all` command.
You can make a single package like this `prt-get depinst [Package Name]` or update it with `prt-get update [Package name]`.
You can remove a package  with `prt-get remove [Package Name]`.
You can also go to the actual port directory like `cd /ts/ports/components/busybox-TS` and then do `pkgmk -kw` (keep work) if you want to examine the working compile and perhaps edit a `.config` file. If you upgrade a version or change a `.config`, you will need to run `pkgmk -um` to update md5 checksums on source files.
If the file layout changes, you will need to run `pkgmk -uf` to update the footprint of the results.

## Ports
The available ports directories can be changed by editing `/ts/etc/prt-get.conf` and then exiting and re-entering chroot.
A "Generic" Pkgfile is located in `/ts/ports`. Copy this file into your new port directory and rename to `Pkgfile`.
You can update the official crux ports with `ports -u` and then do a `prt-get sysup` to update all packages in chroot.
Other ports may be availabe, but should only be used as a template from `http://crux.nu/portdb/`.
Doing an update will sometimes give undesired results. Be patient and read the log files for package builds.(`/var/log/pkgbuild`)

## Updating ThinStation
The update command will read a `.dna` file and extract the latest and greatest from compressed binary packages into the working TS packages folder.

## Source
Some package sources were not available in any crux port. 
In those instances, I made my own port, BUT I did not install the resulting binaries into the chroot, but rather jailed them in `/ts/components`. Ports where I could not locate the source anywhere else but in the old TS chroot are in `/ts/ports/static-source`. You could compile all static source packages with a line like:

    for pkg in `ls --color=never /ts/ports/static-source/`; do
        prt-get install $pkg
    done

This will also work with the components directory.

**WARNING**

Never edit the ports in `/usr/ports/`. You will likely lose your work. 
If you need to edit a port, bring it into the `/ts/ports/(something appt)` directory and make your own package.
Everything else you might need is in `/ts/TS_ENV`and `/ts/bin`
