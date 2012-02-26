#
# Copyright (c) 2004, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

#
# Get the current process window station
proc twapi::get_current_window_station_handle {} {
    return [GetProcessWindowStation]
}

#
# Get the handle to a window station
proc twapi::get_window_station_handle {winsta args} {
    array set opts [parseargs args {
        inherit.bool
        {access.arg  GENERIC_READ}
    } -nulldefault]

    set access_rights [_access_rights_to_mask $opts(access)]
    
    return [OpenWindowStation $winsta $opts(inherit) $access_rights]
}


#
# Close a window station handle
proc twapi::close_window_station_handle {hwinsta} {
    # Trying to close our window station handle will generate an error
    if {$hwinsta != [get_current_window_station_handle]} {
        CloseWindowStation $hwinsta
    }
    return
}

#
# List all window stations
proc twapi::find_window_stations {} {
    return [EnumWindowStations]
}


#
# Enumerate desktops in a window station
proc twapi::find_desktops {args} {
    array set opts [parseargs args {winsta.arg}]

    if {[info exists opts(winsta)]} {
        set hwinsta [get_window_station_handle $opts(winsta)]
    } else {
        set hwinsta [get_current_window_station_handle]
    }

    try {
        return [EnumDesktops $hwinsta]
    } finally {
        # Note close_window_station_handle protects against
        # hwinsta being the current window station handle so 
        # we do not need to do that check here
        close_window_station_handle $hwinsta
    }
}


#
# Get the handle to a desktop
proc twapi::get_desktop_handle {desk args} {
    array set opts [parseargs args {
        inherit.bool
        allowhooks.bool
        {access.arg  GENERIC_READ}
    } -nulldefault]

    set access_mask [_access_rights_to_mask $opts(access)]
    
    # If certain access rights are specified, we must add certain other
    # access rights. See OpenDesktop SDK docs
    set access_rights [_access_mask_to_rights $access_mask]
    if {[lsearch -exact $access_rights read_control] >= 0 ||
        [lsearch -exact $access_rights write_dac] >= 0 ||
        [lsearch -exact $access_rights write_owner] >= 0} {
        lappend access_rights desktop_readobject desktop_writeobjects
        set access_mask [_access_rights_to_mask $opts(access)]
    }

    return [OpenDesktop $desk $opts(allowhooks) $opts(inherit) $access_mask]
}

#
# Close the desktop handle
proc twapi::close_desktop_handle {hdesk} {
    CloseDesktop $hdesk
}

#
# Set the process window station
proc twapi::set_process_window_station {hwinsta} {
    SetProcessWindowStation $hwinsta
}
