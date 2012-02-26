#
# Copyright (c) 2003, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

# TBD - convert file spec to drive root path

#
# Get info associated with a drive
proc twapi::get_volume_info {drive args} {
    variable windefs

    set drive [_drive_rootpath $drive]
    
    array set opts [parseargs args {
        all size freespace used useravail type serialnum label maxcomponentlen fstype attr device
    } -maxleftover 0]

    if {$opts(all)} {
        # -all option does not cover -type and -device
        set device_requested $opts(device)
        set type_requested   $opts(type)
        _array_set_all opts 1
        set opts(device) $device_requested
        set opts(type)   $type_requested
    }

    set result [list ]
    if {$opts(size) || $opts(freespace) || $opts(used) || $opts(useravail)} {
        foreach {useravail size freespace} [GetDiskFreeSpaceEx $drive] {break}
        foreach opt {size freespace useravail}  {
            if {$opts($opt)} {
                lappend result -$opt [set $opt]
            }
        }
        if {$opts(used)} {
            lappend result -used [expr {$size - $freespace}]
        }
    }

    if {$opts(type) || $opts(device)} {
        set drive_type [get_drive_type $drive]
        if {$opts(type)} {
            lappend result -type $drive_type
        }
        if {$opts(device)} {
            if {"remote" == $drive_type} {
                lappend result -device ""
            } else {
                lappend result -device [QueryDosDevice [string range $drive 0 1]]
            }
        }
    }

    if {$opts(serialnum) || $opts(label) || $opts(maxcomponentlen)
        || $opts(fstype) || $opts(attr)} {
        foreach {label serialnum maxcomponentlen attr fstype} \
            [GetVolumeInformation $drive] { break }
        foreach opt {label maxcomponentlen fstype}  {
            if {$opts($opt)} {
                lappend result -$opt [set $opt]
            }
        }
        if {$opts(serialnum)} {
            set low [expr {$serialnum & 0x0000ffff}]
            set high [expr {($serialnum >> 16) & 0x0000ffff}]
            lappend result -serialnum [format "%.4X-%.4X" $high $low]
        }
        if {$opts(attr)} {
            set attrs [list ]
            foreach val {
                case_preserved_names
                unicode_on_disk
                persistent_acls
                file_compression
                volume_quotas
                supports_sparse_files
                supports_reparse_points
                supports_remote_storage
                volume_is_compressed
                supports_object_ids
                supports_encryption
                named_streams
                read_only_volume
            } {
                # Coincidentally, the attribute values happen to match
                # the corresponding constant defines
                set cdef "FILE_[string toupper $val]"
                if {$attr & $windefs($cdef)} {
                    lappend attrs $val
                }
            }
            lappend result -attr $attrs
        }
    }

    return $result
}
interp alias {} twapi::get_drive_info {} twapi::get_volume_info


# Check if disk has at least n bytes available for the user (NOT total free)
proc twapi::user_drive_space_available {drv space} {
    return [expr {$space <= [lindex [get_drive_info $drv -useravail] 1]}]
}

# Get the drive type
proc twapi::get_drive_type {drive} {
    # set type [GetDriveType "[string trimright $drive :/\\]:\\"]
    set type [GetDriveType [_drive_rootpath $drive]]
    switch -exact -- $type {
        0 { return unknown}
        1 { return invalid}
        2 { return removable}
        3 { return fixed}
        4 { return remote}
        5 { return cdrom}
        6 { return ramdisk}
    }
}

#
# Get list of drives
proc twapi::find_logical_drives {args} {
    array set opts [parseargs args {type.arg}]

    set drives [list ]

    set i 0
    set drivebits [GetLogicalDrives]
    foreach drive {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z} {
        if {[expr {$drivebits & (1 << $i)}]} {
            if {(![info exists opts(type)]) ||
                [lsearch -exact $opts(type) [get_drive_type $drive]] >= 0} {
                lappend drives $drive:
            }
        }
        incr i
    }
    return $drives
}
interp alias {} twapi::get_logical_drives {} twapi::find_logical_drives

#
# Set the drive label
proc twapi::set_drive_label {drive label} {
    SetVolumeLabel [_drive_rootpath $drive] $label
}

#
# Maps a drive letter to the given path
proc twapi::map_drive_local {drive path args} {
    array set opts [parseargs args {raw}]

    set drive [string range [_drive_rootpath $drive] 0 1]

    set flags [expr {$opts(raw) ? 0x1 : 0}]
    DefineDosDevice $flags $drive [file nativename $path]
}


#
# Unmaps a drive letter
proc twapi::unmap_drive_local {drive args} {
    array set opts [parseargs args {
        path.arg
        raw
    }]

    set drive [string range [_drive_rootpath $drive] 0 1]

    set flags [expr {$opts(raw) ? 0x1 : 0}]
    setbits flags 0x2;                  # DDD_REMOVE_DEFINITION
    if {[info exists opts(path)]} {
        setbits flags 0x4;              # DDD_EXACT_MATCH_ON_REMOVE
    }
    DefineDosDevice $flags $drive [file nativename $opts(path)]
}

#
# Monitor file changes
proc twapi::begin_filesystem_monitor {path script args} {
    array set opts [parseargs args {
        {subtree.bool false}
        filename.bool
        dirname.bool
        attr.bool
        size.bool
        write.bool
        access.bool
        create.bool
        secd.bool
    } -maxleftover 0]

    set have_opts 0
    set flags 0
    foreach {opt val} {
        filename 0x1
        dirname  0x2
        attr     0x4
        size     0x8
        write 0x10
        access 0x20
        create  0x40
        secd      0x100
    } {
        if {[info exists opts($opt)]} {
            if {$opts($opt)} {
                setbits flags $val
            }
            set have_opts 1
        }
    }

    if {! $have_opts} {
        # If no options specified, default to all
        set flags 0x17f
    }

    return [RegisterDirChangeNotifier $path $opts(subtree) $flags $script]
}

#
# Stop monitoring of files
proc twapi::cancel_filesystem_monitor {id} {
    UnregisterDirChangeNotifier $id
}


#
# Get list of volumes
proc twapi::find_volumes {} {
    set vols [list ]
    set found 1
    # Assumes there has to be at least one volume
    foreach {handle vol} [FindFirstVolume] break
    while {$found} {
        lappend vols $vol
        foreach {found vol} [FindNextVolume $handle] break
    }
    FindVolumeClose $handle
    return $vols
}

#
# Get list of volumes
proc twapi::find_volumes {} {
    set vols [list ]
    set found 1
    # Assumes there has to be at least one volume
    foreach {handle vol} [FindFirstVolume] break
    while {$found} {
        lappend vols $vol
        foreach {found vol} [FindNextVolume $handle] break
    }
    FindVolumeClose $handle
    return $vols
}

#
# Get list of volume mount points
proc twapi::find_volume_mount_points {vol} {
    set mntpts [list ]
    set found 1
    try {
        foreach {handle mntpt} [FindFirstVolumeMountPoint $vol] break
    } onerror {TWAPI_WIN32 18} {
        # ERROR_NO_MORE_FILES
        # No volume mount points
        return [list ]
    } onerror {TWAPI_WIN32 3} {
        # Volume does not support them
        return [list ]
    }

    # At least one volume found
    while {$found} {
        lappend mntpts $mntpt
        foreach {found mntpt} [FindNextVolumeMountPoint $handle] break
    }
    FindVolumeMountPointClose $handle
    return $mntpts
}

#
# Set volume mount point
proc twapi::mount_volume {volpt volname} {
    # Note we don't use _drive_rootpath for trimming since may not be root path
    SetVolumeMountPoint "[string trimright $volpt /\\]\\" "[string trimright $volname /\\]\\"
}

#
# Delete volume mount point
proc twapi::unmount_volume {volpt} {
    # Note we don't use _drive_rootpath for trimming since may not be root path
    DeleteVolumeMountPoint "[string trimright $volpt /\\]\\"
}

#
# Get the volume mounted at a volume mount point
proc twapi::get_mounted_volume_name {volpt} {
    # Note we don't use _drive_rootpath for trimming since may not be root path
    return [GetVolumeNameForVolumeMountPoint "[string trimright $volpt /\\]\\"]
}

#
# Get the mount point corresponding to a given path
proc twapi::get_volume_mount_point_for_path {path} {
    return [GetVolumePathName [file nativename $path]]
}

#
# Show property dialog for a volume
proc twapi::volume_properties_dialog {name args} {
    array set opts [parseargs args {
        {hwin.int 0}
        {page.arg ""}
    } -maxleftover 0]
    
    shell_object_properties_dialog $name -type volume -hwin $opts(hwin) -page $opts(page)
}

#
# Show property dialog for a file
proc twapi::file_properties_dialog {name args} {
    array set opts [parseargs args {
        {hwin.int 0}
        {page.arg ""}
    } -maxleftover 0]
    
    shell_object_properties_dialog $name -type file -hwin $opts(hwin) -page $opts(page)
}

#
# Retrieve version info for a file
proc twapi::get_file_version_resource {path args} {
    # TBD add -datetime opt to return date and time from fixed version struct
    array set opts [parseargs args {
        all
        signature
        structversion
        fileversion
        productversion
        flags
        fileos
        filetype
        langid.arg
        codepage.arg
    }]

    set ver [Twapi_GetFileVersionInfo $path]

    try {
        array set verinfo [Twapi_VerQueryValue_FIXEDFILEINFO $ver]

        set result [list ]
        if {$opts(all) || $opts(signature)} {
            lappend result -signature [format 0x%x $verinfo(dwSignature)]
        }

        if {$opts(all) || $opts(structversion)} {
            lappend result -structversion "[expr {0xffff & ($verinfo(dwStrucVersion) >> 16)}].[expr {0xffff & $verinfo(dwStrucVersion)}]"
        }

        if {$opts(all) || $opts(fileversion)} {
            lappend result -fileversion "[expr {0xffff & ($verinfo(dwFileVersionMS) >> 16)}].[expr {0xffff & $verinfo(dwFileVersionMS)}].[expr {0xffff & ($verinfo(dwFileVersionLS) >> 16)}].[expr {0xffff & $verinfo(dwFileVersionLS)}]"
        }

        if {$opts(all) || $opts(productversion)} {
            lappend result -productversion "[expr {0xffff & ($verinfo(dwProductVersionMS) >> 16)}].[expr {0xffff & $verinfo(dwProductVersionMS)}].[expr {0xffff & ($verinfo(dwProductVersionLS) >> 16)}].[expr {0xffff & $verinfo(dwProductVersionLS)}]"
        }

        if {$opts(all) || $opts(flags)} {
            set flags [expr {$verinfo(dwFileFlags) & $verinfo(dwFileFlagsMask)}]
            lappend result -flags \
                [_make_symbolic_bitmask \
                     [expr {$verinfo(dwFileFlags) & $verinfo(dwFileFlagsMask)}] \
                     {
                         debug 1
                         prerelease 2
                         patched 4
                         privatebuild 8
                         infoinferred 16
                         specialbuild 32
                     } \
                     ]
        }
            
        if {$opts(all) || $opts(fileos)} {
            switch -exact -- [format %08x $verinfo(dwFileOS)] {
                00010000 {set os dos}
                00020000 {set os os216}
                00030000 {set os os232}
                00040000 {set os nt}
                00050000 {set os wince}
                00000001 {set os windows16}
                00000002 {set os pm16}
                00000003 {set os pm32}
                00000004 {set os windows32}
                00010001 {set os dos_windows16}
                00010004 {set os dos_windows32}
                00020002 {set os os216_pm16}
                00030003 {set os os232_pm32}
                00040004 {set os nt_windows32}
                default {set os $verinfo(dwFileOS)}
            }
            lappend result -fileos $os
        }

        if {$opts(all) || $opts(filetype)} {
            switch -exact -- [expr {0+$verinfo(dwFileType)}] {
                1 {set type application}
                2 {set type dll}
                3 {
                    set type "driver."
                    switch -exact -- [expr {0+$verinfo(dwFileSubtype)}] {
                        1 {append type printer}
                        2 {append type keyboard}
                        3 {append type language}
                        4 {append type display}
                        5 {append type mouse}
                        6 {append type network}
                        7 {append type system}
                        8 {append type installable}
                        9  {append type sound}
                        10 {append type comm}
                        11 {append type inputmethod}
                        12 {append type versionedprinter}
                        default {append type $verinfo(dwFileSubtype)}
                    }
                }
                4 {
                    set type "font."
                    switch -exact -- [expr {0+$verinfo(dwFileSubtype)}] {
                        1 {append type raster}
                        2 {append type vector}
                        3 {append type truetype}
                        default {append type $verinfo(dwFileSubtype)}
                    }
                }
                5 { set type "vxd.$verinfo(dwFileSubtype)" }
                7 {set type staticlib}
                default {
                    set type "$verinfo(dwFileType).$verinfo(dwFileSubtype)"
                }
            }
            lappend result -filetype $type
        }

        # Any remaining arguments are treated as string names

        if {[llength $args]} {
            # Find list of langid's and codepages and do closest match
            set langid [expr {[info exists opts(langid)] ? $opts(langid) : [get_user_ui_langid]}]
            set primary_langid [extract_primary_langid $langid]
            set sub_langid     [extract_sublanguage_langid $langid]
            set cp [expr {[info exists opts(codepage)] ? $opts(codepage) : 0}]
            
            # Find a match in the following order:
            # 0 Exact match for both langid and codepage
            # 1 Exact match for langid
            # 2 Primary langid matches (sublang does not) and exact codepage
            # 3 Primary langid matches (sublang does not)
            # 4 Language neutral
            # 5 English
            # 6 First langcp in list or "00000000"
            set match(7) "00000000";    # In case list is empty
            foreach langcp [Twapi_VerQueryValue_TRANSLATIONS $ver] {
                set verlangid 0x[string range $langcp 0 3]
                set vercp 0x[string range $langcp 4 7]
                if {$verlangid == $langid && $vercp == $cp} {
                    set match(0) $langcp
                    break;              # No need to look further
                }
                if {[info exists match(1)]} continue
                if {$verlangid == $langid} {
                    set match(1) $langcp
                    continue;           # Continue to look for match(0)
                }
                if {[info exists match(2)]} continue
                set verprimary [extract_primary_langid $verlangid]
                if {$verprimary == $primary_langid && $vercp == $cp} {
                    set match(2) $langcp
                    continue;       # Continue to look for match(1) or better
                }
                if {[info exists match(3)]} continue
                if {$verprimary == $primary_langid} {
                    set match(3) $langcp
                    continue;       # Continue to look for match(2) or better
                }
                if {[info exists match(4)]} continue
                if {$verprimary == 0} {
                    set match(4) $langcp; # LANG_NEUTRAL
                    continue;       # Continue to look for match(3) or better
                }
                if {[info exists match(5)]} continue
                if {$verprimary == 9} {
                    set match(5) $langcp; # English
                    continue;       # Continue to look for match(4) or better
                }
                if {![info exists match(6)]} {
                    set match(6) $langcp
                }
            }

            # Figure out what is the best match we have
            for {set i 0} {$i <= 7} {incr i} {
                if {[info exists match($i)]} {
                    break
                }
            }

            foreach sname $args {
                lappend result $sname [Twapi_VerQueryValue_STRING $ver $match($i) $sname]
            }
        }

    } finally {
        Twapi_FreeFileVersionInfo $ver
    }

    return $result
}

#
# Return the times associated with a file
proc twapi::get_file_times {fd args} {
    variable windefs

    array set opts [parseargs args {
        all
        mtime
        ctime
        atime
    } -maxleftover 0]

    # Figure out if fd is a file path, Tcl channel or a handle
    set close_handle false
    if {[file exists $fd]} {
        # It's a file name
        set close_handle true
        set h  [CreateFile $fd \
                    $windefs(GENERIC_READ) \
                    [expr {$windefs(FILE_SHARE_READ) | $windefs(FILE_SHARE_WRITE)}] \
                    {{} 1} \
                    $windefs(OPEN_EXISTING) \
                    0 \
                    NULL]
        set h [CastToHANDLE $h]
    } elseif {[catch {fconfigure $fd}]} {
        # Not a Tcl channel, assume a handle
        set h $fd
    } else {
        # Tcl channel
        set h [get_tcl_channel_handle $fd read]
    }

    set result [list ]

    foreach opt {ctime atime mtime} time [GetFileTime $h] {
        if {$opts(all) || $opts($opt)} {
            lappend result -$opt $time
        }
    }

    if {$close_handle} {
        close_handles $h
    }

    return $result
}


#
# Set the times associated with a file
proc twapi::set_file_times {fd args} {
    variable windefs

    array set opts [parseargs args {
        mtime.arg
        ctime.arg
        atime.arg
        preserveatime
    } -maxleftover 0 -nulldefault]

    if {$opts(atime) ne "" && $opts(preserveatime)} {
        win32_error 87 "Cannot specify -atime and -preserveatime at the same time."
    }
    if {$opts(preserveatime)} {
        set opts(atime) -1;             # Meaning preserve access to original
    }

    # Figure out if fd is a file path, Tcl channel or a handle
    set close_handle false
    if {[file exists $fd]} {
        if {$opts(preserveatime)} {
            win32_error 87 "Cannot specify -preserveatime unless file is specified as a Tcl channel or a Win32 handle."
        }

        # It's a file name
        set close_handle true
        set h  [CreateFile $fd \
                    $windefs(GENERIC_WRITE) \
                    [expr {$windefs(FILE_SHARE_READ) | $windefs(FILE_SHARE_WRITE)}] \
                    {{} 1} \
                    $windefs(OPEN_EXISTING) \
                    0 \
                    NULL]
        set h [CastToHANDLE $h]
    } elseif {[catch {fconfigure $fd}]} {
        # Not a Tcl channel, assume a handle
        set h $fd
    } else {
        # Tcl channel
        set h [get_tcl_channel_handle $fd read]
    }

    SetFileTime $h $opts(ctime) $opts(atime) $opts(mtime)

    if {$close_handle} {
        close_handles $h
    }

    return
}

#
# Utility functions

proc twapi::_drive_rootpath {drive} {
    if {[_is_unc $drive]} {
        # UNC
        return "[string trimright $drive ]\\"
    } else {
        return "[string trimright $drive :/\\]:\\"
    }
}

proc twapi::_is_unc {path} {
    return [expr {[string match {\\\\*} $path] || [string match //* $path]}]
}
