#
# Copyright (c) 2003, 2004, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

# TBD - define a C function and way to implement window callback so
# that SetWindowLong(GWL_WNDPROC) can be implemente
#


# TBD  - document the following class names
#  SciCalc            CALC.EXE
#  CalWndMain         CALENDAR.EXE
#  Cardfile           CARDFILE.EXE
#  Clipboard          CLIPBOARD.EXE
#  Clock              CLOCK.EXE
#  CtlPanelClass      CONTROL.EXE
#  XLMain             EXCEL.EXE
#  Session            MS-DOS.EXE
#  Notepad            NOTEPAD.EXE
#  pbParent           PBRUSH.EXE
#  Pif                PIFEDIT.EXE
#  PrintManager       PRINTMAN.EXE
#  Progman            PROGMAN.EXE   (Windows Program Manager)
#  Recorder           RECORDER.EXE
#  Reversi            REVERSI.EXE
#  #32770             SETUP.EXE
#  Solitaire          SOL.EXE
#  Terminal           TERMINAL.EXE
#  WFS_Frame          WINFILE.EXE
#  MW_WINHELP         WINHELP.EXE
#  #32770             WINVER.EXE
#  OpusApp            WINWORD.EXE
#  MSWRITE_MENU       WRITE.EXE
#  OMain  Microsoft Access
#  XLMAIN  Microsoft Excel
#  rctrl_renwnd32  Microsoft Outlook
#  PP97FrameClass  Microsoft PowerPoint
#  OpusApp  Microsoft Word


namespace eval twapi {
    variable null_hwin ""
}

# Enumerate toplevel windows
proc twapi::get_toplevel_windows {args} {

    array set opts [parseargs args {
        {pid.arg}
    }]

    set toplevels [twapi::EnumWindows]

    if {![info exists opts(pid)]} {
        return $toplevels
    }

    if {[string is integer $opts(pid)]} {
        set match_pids [list $opts(pid)]
    } else {
        # Treat opts(pid) as the name of the process
        set match_pids [list ]
        foreach pid [get_process_ids] {
            if {[string equal -nocase $opts(pid) [get_process_name $pid]]} {
                lappend match_pids $pid
            }
        }
        if {[llength $match_pids] == 0} {
            # No matching pids, so no matching toplevels
            return [list ]
        }
    }

    # match_pids is the list of pids to match
    set process_toplevels [list ]
    foreach toplevel $toplevels {
        set pid [get_window_process $toplevel]
        if {[lsearch -exact $match_pids $pid] >= 0} {
            lappend process_toplevels $toplevel
        }
    }

    return $process_toplevels
}


#
# Find a window based on given criteria
proc twapi::find_windows {args} {
    # TBD - would incorporating FindWindowEx be faster

    array set opts [parseargs args {
        {ancestor.int 0}
        caption.bool
        child.bool
        class.arg
        {match.arg string {string glob regexp}}
        maximize.bool
        maximizebox.bool
        minimize.bool
        minimizebox.bool
        overlapped.bool
        pids.arg
        popup.bool
        single
        style.arg
        text.arg
        toplevel.bool
        visible.bool
    }]

    if {[info exists opts(style)]
        ||[info exists opts(overlapped)]
        || [info exists opts(popup)]
        || [info exists opts(child)]
        || [info exists opts(minimizebox)]
        || [info exists opts(maximizebox)] 
        || [info exists opts(minimize)]
        || [info exists opts(maximize)] 
        || [info exists opts(visible)] 
        || [info exists opts(caption)] 
    } {
        set need_style 1
    } else {
        set need_style 0
    }

    # Figure out the type of match if -text specified
    if {[info exists opts(text)]} {
        switch -exact -- $opts(match) {
            glob {
                set text_compare [list string match -nocase $opts(text)]
            }
            string {
                set text_compare [list string equal -nocase $opts(text)]
            }
            regexp {
                set text_compare [list regexp -nocase $opts(text)]
            }
            default {
                error "Invalid value '$opts(match)' specified for -match option"
            }
        }
    }

    # If only interested in toplevels, just start from there
    if {[info exists opts(toplevel)]} {
        if {$opts(toplevel)} {
            set candidates [get_toplevel_windows]
            if {$opts(ancestor)} {
                error "Option -ancestor may not be specified together with -toplevel true"
            }
        } else {
            # We do not want windows to be toplevels. Remember list
            # so we can check below.
            set toplevels [get_toplevel_windows]
        }
    }

    if {![info exists candidates]} {
        # -toplevel TRuE not specified. 
        # If ancestor is not specified, we start from the desktop window
        # Note ancestor, if specified, is never included in the search
        if {$opts(ancestor)} {
            set candidates [get_descendent_windows $opts(ancestor)]
        } else {
            set desktop [get_desktop_window]
            set candidates [concat [list $desktop] [get_descendent_windows $desktop]]
        }
    }

    # TBD - make use of FindWindowEx function if possible

    set matches [list ]
    foreach win $candidates {

        set status [catch {
            if {[info exists toplevels]} {
                # We do NOT want toplevels
                if {[lsearch -exact -integer $toplevels $win] >= 0} {
                    # This is toplevel, which we don't want
                    continue
                }
            }

            # TBD - what is the right order to check from a performance
            # point of view

            if {$need_style} {
                set win_styles [get_window_style $win]
                set win_style [lindex $win_styles 0]
                set win_exstyle [lindex $win_styles 1]
                set win_styles [lrange $win_styles 2 end]
            }

            if {[info exists opts(style)] && [llength $opts(style)]} {
                foreach {style exstyle} $opts(style) break
                if {[string length $style] && ($style != $win_style)} continue
                if {[string length $exstyle] && ($exstyle != $win_exstyle)} continue
            }

            set match 1
            foreach opt {visible overlapped popup child minimizebox
                maximizebox minimize maximize caption
            } {
                if {[info exists opts($opt)]} {
                    if {(! $opts($opt)) == ([lsearch -exact $win_styles $opt] >= 0)} {
                        set match 0
                        break
                    }
                }
            }
            if {! $match} continue

            # TBD - should we use get_window_class or get_window_real_class
            if {[info exists opts(class)] &&
                [string compare -nocase $opts(class) [get_window_class $win]]} {
                continue
            }

            if {[info exists opts(pids)]} {
                set pid [get_window_process $win]
                if {[lsearch -exact -integer $opts(pids) $pid] < 0} continue
            }

            if {[info exists opts(text)]} {
                set text [get_window_text $win]
                if {![eval $text_compare [list [get_window_text $win]]]} continue
            }
            # Matches all criteria. If we only want one, return it, else
            # add to match list
            if {$opts(single)} {
                return [list $win]
            }
            lappend matches $win
        } result ]

        switch -exact -- $status {
            0 {
                # No error, just keep going
            }
            1 {
                # Error, see if error code is no window and if so, ignore
                foreach {subsystem code msg} $::errorCode { break }
                if {$subsystem == "TWAPI_WIN32" && $code == 2} {
                    # Window has disappeared so just do not include it
                } else {
                    error $result $::errorInfo $::errorCode
                }
            }
            2 {
                return $result;         # Block executed a return
            }
            3 {
                break;                  # Block executed a break
            }
            4 {
                continue;               # Block executed a continue
            }
        }
    }        

    return $matches
    
}


# Return all descendent windows
proc twapi::get_descendent_windows {parent_hwin} {
    return [EnumChildWindows $parent_hwin]
}

#
# Return the parent window
proc twapi::get_parent_window {hwin} {
    # Note - we use GetAncestor and not GetParent because the latter
    # will return the owner in the case of a toplevel window
    return [_return_window [GetAncestor $hwin $twapi::windefs(GA_PARENT)]]
}

#
# Return owner window
proc twapi::get_owner_window {hwin} {
    return [_return_window [twapi::GetWindow $hwin \
                                $twapi::windefs(GW_OWNER)]]
}

#
# Return immediate children of a window (not all children)
proc twapi::get_child_windows {hwin} {
    set children [list ]
    # TBD - maybe get_first_child/get_next_child would be more efficient
    foreach w [get_descendent_windows $hwin] {
        if {[_same_window $hwin [get_parent_window $w]]} {
            lappend children $w
        }
    }
    return $children
}

#
# Return first child in z-order
proc twapi::get_first_child {hwin} {
    return [_return_window [twapi::GetWindow $hwin \
                                $twapi::windefs(GW_CHILD)]]
}


#
# Return the next sibling window in z-order
proc twapi::get_next_sibling_window {hwin} {
    return [_return_window [twapi::GetWindow $hwin \
                                $twapi::windefs(GW_HWNDNEXT)]]
}

#
# Return the previous sibling window in z-order
proc twapi::get_prev_sibling_window {hwin} {
    return [_return_window [twapi::GetWindow $hwin \
                                $twapi::windefs(GW_HWNDPREV)]]
}

#
# Return the sibling window that is highest in z-order
proc twapi::get_first_sibling_window {hwin} {
    return [_return_window [twapi::GetWindow $hwin \
                                $twapi::windefs(GW_HWNDFIRST)]]
}

#
# Return the sibling window that is lowest in z-order
proc twapi::get_last_sibling_window {hwin} {
    return [_return_window [twapi::GetWindow $hwin \
                                $twapi::windefs(GW_HWNDLAST)]]
}

#
# Return the desktop window
proc twapi::get_desktop_window {} {
    return [_return_window [twapi::GetDesktopWindow]]
}

#
# Return the shell window
proc twapi::get_shell_window {} {
    return [_return_window [twapi::GetShellWindow]]
}

# Return the pid for a window
proc twapi::get_window_process {hwin} {
    return [lindex [GetWindowThreadProcessId $hwin] 1]
}

# Return the thread for a window
proc twapi::get_window_thread {hwin} {
    return [lindex [GetWindowThreadProcessId $hwin] 0]
}

# Return the style of the window. Returns a list of two integers
# the first contains the style bits, the second the extended style bits
proc twapi::get_window_style {hwin} {
    set style   [GetWindowLong $hwin $twapi::windefs(GWL_STYLE)]
    set exstyle [GetWindowLong $hwin $twapi::windefs(GWL_EXSTYLE)]
    return [concat [list $style $exstyle] [_style_mask_to_symbols $style $exstyle]]
}


# Set the style of the window. Returns a list of two integers
# the first contains the original style bits, the second the 
# original extended style bits
proc twapi::set_window_style {hwin style exstyle} {
    set style [SetWindowLong $hwin $twapi::windefs(GWL_STYLE) $style]
    set exstyle [SetWindowLong $hwin $twapi::windefs(GWL_EXSTYLE) $exstyle]

    redraw_window_frame $hwin
    return
}


# Return the class of the window
proc twapi::get_window_class {hwin} {
    return [_return_window [GetClassName $hwin]]
}

# Return the real class of the window
proc twapi::get_window_real_class {hwin} {
    return [_return_window [RealGetWindowClass $hwin]]
}

# Return the long value at the given index
# This is a raw function, and should generally be used only to get
# non-system defined indices
proc twapi::get_window_long {hwin index} {
    return [GetWindowLong $hwin $index]
}


# Set the long value at the given index and return the previous value
# This is a raw function, and should generally be used only to get
# non-system defined indices
proc twapi::set_window_long {hwin index val} {
    set oldval [SetWindowLong $hwin $index $val]
}

#
# Return the identifier corrpsonding to the application instance
proc twapi::get_window_application {hwin} {
    return [format "0x%x" [GetWindowLong $hwin $twapi::windefs(GWL_HINSTANCE)]]
}

#
# Return the window id (this is different from the handle!)
proc twapi::get_window_id {hwin} {
    return [format "0x%x" [GetWindowLong $hwin $twapi::windefs(GWL_ID)]]
}

#
# Return the user data associated with a window
proc twapi::get_window_userdata {hwin} {
    return [GetWindowLong $hwin $twapi::windefs(GWL_USERDATA)]
}


#
# Set the user data associated with a window. Returns the previous value
proc twapi::set_window_userdata {hwin val} {
    return [SetWindowLong $hwin $twapi::windefs(GWL_USERDATA) $val]
}


#
# Get the foreground window
proc twapi::get_foreground_window {} {
    return [_return_window [GetForegroundWindow]]
}

#
# Set the foreground window - returns 1/0 on success/fail
proc twapi::set_foreground_window {hwin} {
    return [SetForegroundWindow $hwin]
}


#
# Activate a window - this is only brought the foreground if its application
# is in the foreground
proc twapi::set_active_window_for_thread {hwin} {
    return [_return_window [_attach_hwin_and_eval $hwin {SetActiveWindow $hwin}]]
}

#
# Get active window for an application
proc twapi::get_active_window_for_thread {tid} {
    return [_return_window [_get_gui_thread_info $tid hwndActive]]
}


#
# Get focus window for an application
proc twapi::get_focus_window_for_thread {tid} {
    return [_get_gui_thread_info $tid hwndFocus]
}

#
# Get active window for current thread
proc twapi::get_active_window_for_current_thread {} {
    return [_return_window [GetActiveWindow]]
}

#
# Update the frame - needs to be called after setting certain style bits
proc twapi::redraw_window_frame {hwin} {
    variable windefs

    set flags [expr {$windefs(SWP_ASYNCWINDOWPOS) | $windefs(SWP_NOACTIVATE) |
                     $windefs(SWP_NOMOVE) | $windefs(SWP_NOSIZE) |
                     $windefs(SWP_NOZORDER) | $windefs(SWP_FRAMECHANGED)}]
    SetWindowPos $hwin 0 0 0 0 0 $flags
}

#
# Redraw the window
proc twapi::redraw_window {hwin {opt ""}} {
    variable windefs

    if {[string length $opt]} {
        if {[string compare $opt "-force"]} {
            error "Invalid option '$opt'"
        }
        invalidate_screen_region -hwin $hwin -rect [list ] -bgerase
    }

    UpdateWindow $hwin
}

#
# Set the window position
proc twapi::move_window {hwin x y args} {
    variable windefs

    array set opts [parseargs args {
        {sync}
    }]

    # Not using MoveWindow because that will require knowing the width
    # and height (or retrieving it)
    set flags [expr {$windefs(SWP_NOACTIVATE) |
                     $windefs(SWP_NOSIZE) | $windefs(SWP_NOZORDER)}]
    if {! $opts(sync)} {
        setbits flags $windefs(SWP_ASYNCWINDOWPOS)
    }
    SetWindowPos $hwin 0 $x $y 0 0 $flags
}

#
# Resize window
proc twapi::resize_window {hwin w h args} {
    variable windefs

    array set opts [parseargs args {
        {sync}
    }]
    

    # Not using MoveWindow because that will require knowing the x and y pos
    # (or retrieving them)
    set flags [expr {$windefs(SWP_NOACTIVATE) |
                     $windefs(SWP_NOMOVE) | $windefs(SWP_NOZORDER)}]
    if {! $opts(sync)} {
        setbits flags $windefs(SWP_ASYNCWINDOWPOS)
    }
    SetWindowPos $hwin 0 0 0 $w $h $flags
}

#
# Sets the window's z-order position
# pos is either window handle or a symbol
proc twapi::set_window_zorder {hwin pos} {
    variable windefs

    switch -exact -- $pos {
        top       { set pos $windefs(HWND_TOP) }
        bottom    { set pos $windefs(HWND_BOTTOM) }
        toplayer   { set pos $windefs(HWND_TOPMOST) }
        bottomlayer { set pos $windefs(HWND_NOTOPMOST) }
    }
    
    set flags [expr {$windefs(SWP_ASYNCWINDOWPOS) | $windefs(SWP_NOACTIVATE) |
                     $windefs(SWP_NOSIZE) | $windefs(SWP_NOMOVE)}]
    SetWindowPos $hwin $pos 0 0 0 0 $flags
}


#
# Show the given window. Returns 1 if window was previously visible, else 0
proc twapi::show_window {hwin args} {
    array set opts [parseargs args {sync activate normal startup}]

    set show 0
    if {$opts(startup)} {
        set show $twapi::windefs(SW_SHOWDEFAULT)
    } else {
        if {$opts(activate)} {
            if {$opts(normal)} {
                set show $twapi::windefs(SW_SHOWNORMAL)
            } else {
                set show $twapi::windefs(SW_SHOW)
            }
        } else {
            if {$opts(normal)} {
                set show $twapi::windefs(SW_SHOWNOACTIVATE)
            } else {
                set show $twapi::windefs(SW_SHOWNA)
            }
        }
    }

    _show_window $hwin $show $opts(sync)
}

#
# Hide the given window. Returns 1 if window was previously visible, else 0
proc twapi::hide_window {hwin args} {
    array set opts [parseargs args {sync}]
    _show_window $hwin $twapi::windefs(SW_HIDE) $opts(sync)
}

#
# Restore the given window. Returns 1 if window was previously visible, else 0
proc twapi::restore_window {hwin args} {
    array set opts [parseargs args {sync activate}]
    if {$opts(activate)} {
        _show_window $hwin $twapi::windefs(SW_RESTORE) $opts(sync)
    } else {
        OpenIcon $hwin
    }
}

#
# Maximize the given window. Returns 1 if window was previously visible, else 0
proc twapi::maximize_window {hwin args} {
    array set opts [parseargs args {sync}]
    _show_window $hwin $twapi::windefs(SW_SHOWMAXIMIZED) $opts(sync)
}


#
# Minimize the given window. Returns 1 if window was previously visible, else 0
proc twapi::minimize_window {hwin args} {
    array set opts [parseargs args {sync activate shownext}]

    # TBD - when should we use SW_FORCEMINIMIZE ?
    # TBD - do we need to attach to the window's thread?
    # TBD - when should we use CloseWindow instead?

    if $opts(activate) {
        set show $twapi::windefs(SW_SHOWMINIMIZED)
    } else {
        if {$opts(shownext)} {
            set show $twapi::windefs(SW_MINIMIZE)
        } else {
            set show $twapi::windefs(SW_SHOWMINNOACTIVE)
        }
    }

    _show_window $hwin $show $opts(sync)
}


#
# Hides popup windows
proc twapi::hide_owned_popups {hwin} {
    ShowOwnedPopups $hwin 0
}

#
# Show hidden popup windows
proc twapi::show_owned_popups {hwin} {
    ShowOwnedPopups $hwin 1
}

#
# Enable window input
proc twapi::enable_window_input {hwin} {
    return [expr {[EnableWindow $hwin 1] != 0}]
}

#
# Disable window input
proc twapi::disable_window_input {hwin} {
    return [expr {[EnableWindow $hwin 0] != 0}]
}

#
# Close a window
proc twapi::close_window {hwin args} {
    variable windefs
    array set opts [parseargs args {
        block
        {wait.int 10}
    }]

    if {$opts(block)} {
        set block [expr {$windefs(SMTO_BLOCK) | $windefs(SMTO_ABORTIFHUNG)}]
    } else {
        set block [expr {$windefs(SMTO_NORMAL) | $windefs(SMTO_ABORTIFHUNG)}]
    }

    if {[catch {SendMessageTimeout $hwin $windefs(WM_CLOSE) 0 0 $block $opts(wait)} msg]} {
        # Do no treat timeout as an error
        set erCode $::errorCode
        set erInfo $::errorInfo
        if {[lindex $erCode 0] != "TWAPI_WIN32" ||
            ([lindex $erCode 1] != 0 && [lindex $erCode 1] != 1460)} {
            error $msg $erInfo $erCode
        }
    }
}

#
# CHeck if window is minimized
proc twapi::window_minimized {hwin} {
    return [IsIconic $hwin]
}

#
# CHeck if window is maximized
proc twapi::window_maximized {hwin} {
    return [IsZoomed $hwin]
}

#
# Check if window is visible
proc twapi::window_visible {hwin} {
    return [IsWindowVisible $hwin]
}

#
# Check if a window exists
proc twapi::window_exists {hwin} {
    return [IsWindow $hwin]
}

# CHeck if window input is enabled 
proc twapi::window_unicode_enabled {hwin} {
    return [IsWindowUnicode $hwin]
}

#
# CHeck if window input is enabled 
proc twapi::window_input_enabled {hwin} {
    return [IsWindowEnabled $hwin]
}

#
# Check if child is a child of parent
proc twapi::window_is_child {parent child} {
    return [IsChild $parent $child]
}

#
# Set the focus to the given window
proc twapi::set_focus {hwin} {
    return [_return_window [_attach_hwin_and_eval $hwin {SetFocus $hwin}]]
}

#
# Flash the given window
proc twapi::flash_window_caption {hwin args} {
    eval set [parseargs args {toggle}]

    return [FlashWindow $hwin $toggle]
}

#
# Show/hide window caption buttons. hwin must be a toplevel
proc twapi::configure_window_titlebar {hwin args} {
    variable windefs

    # The minmax buttons are 

    array set opts [parseargs args {
        visible.bool
        sysmenu.bool
        minimizebox.bool
        maximizebox.bool
        contexthelp.bool
    } -maxleftover 0]

    # Get the current style setting
    foreach {style exstyle} [get_window_style $hwin] {break}

    # See if each option is specified. Else use current setting
    foreach {opt def} {
        sysmenu WS_SYSMENU
        minimizebox WS_MINIMIZEBOX
        maximizebox WS_MAXIMIZEBOX
        visible  WS_CAPTION
    } {
        if {[info exists opts($opt)]} {
            set $opt [expr {$opts($opt) ? $windefs($def) : 0}]
        } else {
            set $opt [expr {$style & $windefs($def)}]
        }
    }

    # Ditto for extended style and context help
    if {[info exists opts(contexthelp)]} {
        set contexthelp [expr {$opts(contexthelp) ? $windefs(WS_EX_CONTEXTHELP) : 0}]
    } else {
        set contexthelp [expr {$exstyle & $windefs(WS_EX_CONTEXTHELP)}]
    }

    # The min/max/help buttons all depend on sysmenu being set.
    if {($minimizebox || $maximizebox || $contexthelp) && ! $sysmenu} {
        # Don't bother raising error, since the underlying API allows it
        #error "Cannot enable minimize, maximize and context help buttons unless system menu is present"
    }

    set style [expr {($style & ~($windefs(WS_SYSMENU) | $windefs(WS_MINIMIZEBOX) | $windefs(WS_MAXIMIZEBOX) | $windefs(WS_CAPTION))) | ($sysmenu | $minimizebox | $maximizebox | $visible)}]
    set exstyle [expr {($exstyle & ~ $windefs(WS_EX_CONTEXTHELP)) | $contexthelp}]

    #puts "setting window style to $style ([format %x $style]), $exstyle ([format %x $exstyle])"
    set_window_style $hwin $style $exstyle
}

#
# Generate sound for the specified duration
proc twapi::beep {args} {
    array set opts [parseargs args {
        {frequency.int 1000}
        {duration.int 100}
        {type.arg}
    }]

    if {[info exists opts(type)]} {
        switch -exact -- $opts(type) {
            ok           {MessageBeep 0}
            hand         {MessageBeep 0x10}
            question     {MessageBeep 0x20}
            exclaimation {MessageBeep 0x30}
            exclamation {MessageBeep 0x30}
            asterisk     {MessageBeep 0x40}
            default      {error "Unknown sound type '$opts(type)'"}
        }
        return
    }
    Beep $opts(frequency) $opts(duration)
    return
}


# Arrange window icons
proc twapi::arrange_icons {{hwin ""}} {
    if {$hwin == ""} {
        set hwin [get_desktop_window]
    }
    ArrangeIconicWindows $hwin
}

#
# Get the window text/caption
proc twapi::get_window_text {hwin} {
    twapi::GetWindowText $hwin
}

#
# Set the window text/caption
proc twapi::set_window_text {hwin text} {
    twapi::SetWindowText $hwin $text
}

#
# Get size of client area
proc twapi::get_window_client_area_size {hwin} {
    return [lrange [GetClientRect $hwin] 2 3]
}

#
# Get window coordinates
proc twapi::get_window_coordinates {hwin} {
    return [GetWindowRect $hwin]
}

#
# Get the window under the point
proc twapi::get_window_at_location {x y} {
    return [WindowFromPoint [list $x $y]]
}

#
# Marks a screen region as invalid forcing a redraw
proc twapi::invalidate_screen_region {args} {
    array set opts [parseargs args {
        {hwin.int 0}
        rect.arg
        bgerase
    } -nulldefault]

    InvalidateRect $opts(hwin) $opts(rect) $opts(bgerase)
}

#
# Get the caret blink time
proc twapi::get_caret_blink_time {} {
    return [GetCaretBlinkTime]
}

#
# Set the caret blink time
proc twapi::set_caret_blink_time {ms} {
    return [SetCaretBlinkTime $ms]
}

#
# Hide the caret
proc twapi::hide_caret {} {
    HideCaret 0
}

#
# Show the caret
proc twapi::show_caret {} {
    ShowCaret 0
}

#
# Get the caret position
proc twapi::get_caret_location {} {
    return [GetCaretPos]
}

#
# Get the caret position
proc twapi::set_caret_location {point} {
    return [SetCaretPos [lindex $point 0] [lindex $point 1]]
}


#
# Get display size
proc twapi::get_display_size {} {
    return [lrange [get_window_coordinates [get_desktop_window]] 2 3]
}


#
# Get path to the desktop wallpaper
interp alias {} twapi::get_desktop_wallpaper {} twapi::get_system_parameters_info SPI_GETDESKWALLPAPER


#
# Set desktop wallpaper
proc twapi::set_desktop_wallpaper {path args} {
    
    array set opts [parseargs args {
        persist
    }]

    if {$opts(persist)} {
        set flags 3;                    # Notify all windows + persist
    } else {
        set flags 2;                    # Notify all windows
    }

    if {$path == "default"} {
        SystemParametersInfo 0x14 0 NULL 0
        return
    }

    if {$path == "none"} {
        set path ""
    }

    set mem_size [expr {2 * ([string length $path] + 1)}]
    set mem [malloc $mem_size]
    try {
        twapi::Twapi_WriteMemoryUnicode $mem 0 $mem_size $path
        SystemParametersInfo 0x14 0 $mem $flags
    } finally {
        free $mem
    }
}

#
# Get desktop work area
interp alias {} twapi::get_desktop_workarea {} twapi::get_system_parameters_info SPI_GETWORKAREA


#
# Simulate user input
proc twapi::send_input {inputlist} {
    variable windefs

    set inputs [list ]
    foreach input $inputlist {
        if {[string equal [lindex $input 0] "mouse"]} {
            foreach {mouse xpos ypos} $input {break}
            set mouseopts [lrange $input 3 end]
            array unset opts
            array set opts [parseargs mouseopts {
                relative moved
                ldown lup rdown rup mdown mup x1down x1up x2down x2up
                wheel.int
            }]
            set flags 0
            if {! $opts(relative)} {
                set flags $windefs(MOUSEEVENTF_ABSOLUTE)
            }
            
            if {[info exists opts(wheel)]} {
                if {($opts(x1down) || $opts(x1up) || $opts(x2down) || $opts(x2up))} {
                    error "The -wheel input event attribute may not be specified with -x1up, -x1down, -x2up or -x2down events"
                }
                set mousedata $opts(wheel)
                set flags $windefs(MOUSEEVENTF_WHEEL)
            } else {
                if {$opts(x1down) || $opts(x1up)} {
                    if {$opts(x2down) || $opts(x2up)} {
                        error "The -x1down, -x1up mouse input attributes are mutually exclusive with -x2down, -x2up attributes"
                    }
                    set mousedata $windefs(XBUTTON1)
                } else {
                    if {$opts(x2down) || $opts(x2up)} {
                        set mousedata $windefs(XBUTTON2)
                    } else {
                        set mousedata 0
                    }
                }
            }
            foreach {opt flag} {
                moved MOVE
                ldown LEFTDOWN
                lup   LEFTUP
                rdown RIGHTDOWN
                rup   RIGHTUP
                mdown MIDDLEDOWN
                mup   MIDDLEUP
                x1down XDOWN
                x1up   XUP
                x2down XDOWN
                x2up   XUP
            } {
                if {$opts($opt)} {
                    set flags [expr {$flags | $windefs(MOUSEEVENTF_$flag)}]
                }
            }
                
            lappend inputs [list mouse $xpos $ypos $mousedata $flags]

        } else {
            foreach {inputtype vk scan keyopts} $input {break}
            if {[lsearch -exact $keyopts "-extended"] < 0} {
                set extended 0
            } else {
                set extended $windefs(KEYEVENTF_EXTENDEDKEY)
            }
            if {[lsearch -exact $keyopts "-usescan"] < 0} {
                set usescan 0
            } else {
                set usescan $windefs(KEYEVENTF_SCANCODE)
            }
            switch -exact -- $inputtype {
                keydown {
                    lappend inputs [list key $vk $scan [expr {$extended|$usescan}]]
                }
                keyup {
                    lappend inputs [list key $vk $scan \
                                        [expr {$extended
                                               | $usescan
                                               | $windefs(KEYEVENTF_KEYUP)
                                           }]]
                }
                key {
                    lappend inputs [list key $vk $scan [expr {$extended|$usescan}]]
                    lappend inputs [list key $vk $scan \
                                        [expr {$extended
                                               | $usescan
                                               | $windefs(KEYEVENTF_KEYUP)
                                           }]]
                }
                unicode {
                    lappend inputs [list key 0 $scan $windefs(KEYEVENTF_UNICODE)]
                    lappend inputs [list key 0 $scan \
                                        [expr {$windefs(KEYEVENTF_UNICODE)
                                               | $windefs(KEYEVENTF_KEYUP)
                                           }]]
                }
                default {
                    error "Unknown input type '$inputtype'" 
                }
            }
        }
    }

    SendInput $inputs
}

#
# Block the input
proc twapi::block_input {} {
    return [BlockInput 1]
}

#
# Unblock the input
proc twapi::unblock_input {} {
    return [BlockInput 0]
}

#
# Send the given set of characters to the input queue
proc twapi::send_input_text {s} {
    return [Twapi_SendUnicode $s]
}

#
# send_keys - uses same syntax as VB SendKeys function
proc twapi::send_keys {keys} {
    set inputs [_parse_send_keys $keys]
    send_input $inputs
}


#
# Register a hotkey
proc twapi::register_hotkey {hotkey script} {
    foreach {modifiers vk} [_hotkeysyms_to_vk $hotkey] break

    RegisterHotKey $modifiers $vk $script
}

proc twapi::unregister_hotkey {id} {
    UnregisterHotKey $id
}


#
# Simulate clicking a mouse button
proc twapi::click_mouse_button {button} {
    switch -exact -- $button {
        1 -
        left { set down -ldown ; set up -lup}
        2 -
        right { set down -rdown ; set up -rup}
        3 -
        middle { set down -mdown ; set up -mup}
        x1     { set down -x1down ; set up -x1up}
        x2     { set down -x2down ; set up -x2up}
        default {error "Invalid mouse button '$button' specified"}
    }

    send_input [list \
                    [list mouse 0 0 $down] \
                    [list mouse 0 0 $up]]
    return
}

#
# Simulate mouse movement
proc twapi::move_mouse {xpos ypos {mode ""}} {
    # If mouse trails are enabled, it leaves traces when the mouse is
    # moved and does not clear them until mouse is moved again. So
    # we temporarily disable mouse trails

    if {[min_os_version 5 1]} {
        set trail [get_system_parameters_info SPI_GETMOUSETRAILS]
        set_system_parameters_info SPI_SETMOUSETRAILS 0
    }
    switch -exact -- $mode {
        -relative {
            lappend cmd -relative
            foreach {curx cury} [GetCursorPos] break
            incr xpos $curx
            incr ypos $cury
        }
        -absolute -
        ""        { }
        default   { error "Invalid mouse movement mode '$mode'" }
    }
    
    SetCursorPos $xpos $ypos
        
    # Restore trail setting
    if {[min_os_version 5 1]} {
        set_system_parameters_info SPI_SETMOUSETRAILS $trail
    }
}

#
# Simulate turning of the mouse wheel
proc twapi::turn_mouse_wheel {wheelunits} {
    send_input [list [list mouse 0 0 -relative -wheel $wheelunits]]
    return
}


#
# Get the mouse/cursor position
proc twapi::get_mouse_location {} {
    return [GetCursorPos]
}


################################################################
# Sound functions

#
# Play the specified sound
proc twapi::play_sound {name args} {
    variable windefs

    array set opts [parseargs args {
        alias
        async
        loop
        nodefault
        wait
        nostop
    }]
    
    if {$opts(alias)} {
        set flags $windefs(SND_ALIAS)
    } else {
        set flags $windefs(SND_FILENAME)
    }
    if {$opts(loop)} {
        # Note LOOP requires ASYNC 
        setbits flags [expr {$windefs(SND_LOOP) | $windefs(SND_ASYNC)}]
    } else {
        if {$opts(async)} {
            setbits flags $windefs(SND_ASYNC)
        } else {
            setbits flags $windefs(SND_SYNC)
        }
    }

    if {$opts(nodefault)} {
        setbits flags $windefs(SND_NODEFAULT)
    }    

    if {! $opts(wait)} {
        setbits flags $windefs(SND_NOWAIT)
    }    

    if {$opts(nostop)} {
        setbits flags $windefs(SND_NOSTOP)
    }    

    return [PlaySound $name 0 $flags]
}

#
#
proc twapi::stop_sound {} {
    PlaySound "" 0 $twapi::windefs(SND_PURGE)
}


#
# Get the color depth of the display
proc twapi::get_color_depth {{hwin 0}} {
    set h [GetDC $hwin]
    try {
        return [GetDeviceCaps $h 12]
    } finally {
        ReleaseDC $hwin $h
    }
}


################################################################
# Utility routines

#
# Attaches to the thread queue of the thread owning $hwin and executes
# script in the caller's scope
proc twapi::_attach_hwin_and_eval {hwin script} {
    set me [get_current_thread_id]
    set hwin_tid [get_window_thread $hwin]
    if {$hwin_tid == 0} {
        error "Window $hwin does not exist or could not get its thread owner"
    }

    # Cannot (and no need to) attach to oneself so just exec script directly
    if {$me == $hwin_tid} {
        return [uplevel 1 $script]
    }

    try {
        if {![AttachThreadInput $me $hwin_tid 1]} {
            error "Could not attach to thread input for window $hwin"
        }
        set result [uplevel 1 $script]
    } finally {
        AttachThreadInput $me $hwin_tid 0
    }

    return $result
}

#
# Helper function to wrap GetGUIThreadInfo
# Returns the value of the given fields. If a single field is requested,
# returns it as a scalar else returns a flat list of FIELD VALUE pairs
proc twapi::_get_gui_thread_info {tid args} {
    set gtinfo [GUITHREADINFO]
    try {
        GetGUIThreadInfo $tid $gtinfo
        set result [list ]
        foreach field $args {
            set value [$gtinfo cget -$field]
            switch -exact -- $field {
                cbSize { }
                rcCaret {
                    set value [list [$value cget -left] \
                                   [$value cget -top] \
                                   [$value cget -right] \
                                   [$value cget -bottom]]
                }
                default { set value [format 0x%x $value] }
            }
            lappend result $value
        }
    } finally {
        $gtinfo -delete
    }

    if {[llength $args] == 1} {
        return [lindex $result 0]
    } else {
        return $result
    }
}


#
# if $hwin corresponds to a null window handle, returns an empty string
proc twapi::_return_window {hwin} {
    if {$hwin == 0} {
        return $twapi::null_hwin
    }
    return $hwin
}

#
# Return 1 if same window
proc twapi::_same_window {hwin1 hwin2} {
    # If either is a null handle, no match
    if {[string length $hwin1] == 0 || [string length $hwin2] == 0} {
        return 0
    }
    if {$hwin1 == 0 || $hwin2 == 0} {
        return 0
    }

    # Need integer compare
    return [expr {$hwin1==$hwin2}]
}

#
# Helper function for showing/hiding windows
proc twapi::_show_window {hwin cmd {wait 0}} {
    # If either our thread owns the window or we want to wait for it to
    # process the command, use the synchrnous form of the function
    if {$wait || ([get_window_thread $hwin] == [get_current_thread_id])} {
        ShowWindow $hwin $cmd
    } else {
        ShowWindowAsync $hwin $cmd
    }
}


# Initialize the virtual key table
proc twapi::_init_vk_map {} {
    variable windefs
    variable vk_map

    if {![info exists vk_map]} {
        array set vk_map [list \
                              "+" [list $windefs(VK_SHIFT) 0]\
                              "^" [list $windefs(VK_CONTROL) 0] \
                              "%" [list $windefs(VK_MENU) 0] \
                              "BACK" [list $windefs(VK_BACK) 0] \
                              "BACKSPACE" [list $windefs(VK_BACK) 0] \
                              "BS" [list $windefs(VK_BACK) 0] \
                              "BKSP" [list $windefs(VK_BACK) 0] \
                              "TAB" [list $windefs(VK_TAB) 0] \
                              "CLEAR" [list $windefs(VK_CLEAR) 0] \
                              "RETURN" [list $windefs(VK_RETURN) 0] \
                              "ENTER" [list $windefs(VK_RETURN) 0] \
                              "SHIFT" [list $windefs(VK_SHIFT) 0] \
                              "CONTROL" [list $windefs(VK_CONTROL) 0] \
                              "MENU" [list $windefs(VK_MENU) 0] \
                              "ALT" [list $windefs(VK_MENU) 0] \
                              "PAUSE" [list $windefs(VK_PAUSE) 0] \
                              "BREAK" [list $windefs(VK_PAUSE) 0] \
                              "CAPITAL" [list $windefs(VK_CAPITAL) 0] \
                              "CAPSLOCK" [list $windefs(VK_CAPITAL) 0] \
                              "KANA" [list $windefs(VK_KANA) 0] \
                              "HANGEUL" [list $windefs(VK_HANGEUL) 0] \
                              "HANGUL" [list $windefs(VK_HANGUL) 0] \
                              "JUNJA" [list $windefs(VK_JUNJA) 0] \
                              "FINAL" [list $windefs(VK_FINAL) 0] \
                              "HANJA" [list $windefs(VK_HANJA) 0] \
                              "KANJI" [list $windefs(VK_KANJI) 0] \
                              "ESCAPE" [list $windefs(VK_ESCAPE) 0] \
                              "ESC" [list $windefs(VK_ESCAPE) 0] \
                              "CONVERT" [list $windefs(VK_CONVERT) 0] \
                              "NONCONVERT" [list $windefs(VK_NONCONVERT) 0] \
                              "ACCEPT" [list $windefs(VK_ACCEPT) 0] \
                              "MODECHANGE" [list $windefs(VK_MODECHANGE) 0] \
                              "SPACE" [list $windefs(VK_SPACE) 0] \
                              "PRIOR" [list $windefs(VK_PRIOR) 0] \
                              "PGUP" [list $windefs(VK_PRIOR) 0] \
                              "NEXT" [list $windefs(VK_NEXT) 0] \
                              "PGDN" [list $windefs(VK_NEXT) 0] \
                              "END" [list $windefs(VK_END) 0] \
                              "HOME" [list $windefs(VK_HOME) 0] \
                              "LEFT" [list $windefs(VK_LEFT) 0] \
                              "UP" [list $windefs(VK_UP) 0] \
                              "RIGHT" [list $windefs(VK_RIGHT) 0] \
                              "DOWN" [list $windefs(VK_DOWN) 0] \
                              "SELECT" [list $windefs(VK_SELECT) 0] \
                              "PRINT" [list $windefs(VK_PRINT) 0] \
                              "PRTSC" [list $windefs(VK_SNAPSHOT) 0] \
                              "EXECUTE" [list $windefs(VK_EXECUTE) 0] \
                              "SNAPSHOT" [list $windefs(VK_SNAPSHOT) 0] \
                              "INSERT" [list $windefs(VK_INSERT) 0] \
                              "INS" [list $windefs(VK_INSERT) 0] \
                              "DELETE" [list $windefs(VK_DELETE) 0] \
                              "DEL" [list $windefs(VK_DELETE) 0] \
                              "HELP" [list $windefs(VK_HELP) 0] \
                              "LWIN" [list $windefs(VK_LWIN) 0] \
                              "RWIN" [list $windefs(VK_RWIN) 0] \
                              "APPS" [list $windefs(VK_APPS) 0] \
                              "SLEEP" [list $windefs(VK_SLEEP) 0] \
                              "NUMPAD0" [list $windefs(VK_NUMPAD0) 0] \
                              "NUMPAD1" [list $windefs(VK_NUMPAD1) 0] \
                              "NUMPAD2" [list $windefs(VK_NUMPAD2) 0] \
                              "NUMPAD3" [list $windefs(VK_NUMPAD3) 0] \
                              "NUMPAD4" [list $windefs(VK_NUMPAD4) 0] \
                              "NUMPAD5" [list $windefs(VK_NUMPAD5) 0] \
                              "NUMPAD6" [list $windefs(VK_NUMPAD6) 0] \
                              "NUMPAD7" [list $windefs(VK_NUMPAD7) 0] \
                              "NUMPAD8" [list $windefs(VK_NUMPAD8) 0] \
                              "NUMPAD9" [list $windefs(VK_NUMPAD9) 0] \
                              "MULTIPLY" [list $windefs(VK_MULTIPLY) 0] \
                              "ADD" [list $windefs(VK_ADD) 0] \
                              "SEPARATOR" [list $windefs(VK_SEPARATOR) 0] \
                              "SUBTRACT" [list $windefs(VK_SUBTRACT) 0] \
                              "DECIMAL" [list $windefs(VK_DECIMAL) 0] \
                              "DIVIDE" [list $windefs(VK_DIVIDE) 0] \
                              "F1" [list $windefs(VK_F1) 0] \
                              "F2" [list $windefs(VK_F2) 0] \
                              "F3" [list $windefs(VK_F3) 0] \
                              "F4" [list $windefs(VK_F4) 0] \
                              "F5" [list $windefs(VK_F5) 0] \
                              "F6" [list $windefs(VK_F6) 0] \
                              "F7" [list $windefs(VK_F7) 0] \
                              "F8" [list $windefs(VK_F8) 0] \
                              "F9" [list $windefs(VK_F9) 0] \
                              "F10" [list $windefs(VK_F10) 0] \
                              "F11" [list $windefs(VK_F11) 0] \
                              "F12" [list $windefs(VK_F12) 0] \
                              "F13" [list $windefs(VK_F13) 0] \
                              "F14" [list $windefs(VK_F14) 0] \
                              "F15" [list $windefs(VK_F15) 0] \
                              "F16" [list $windefs(VK_F16) 0] \
                              "F17" [list $windefs(VK_F17) 0] \
                              "F18" [list $windefs(VK_F18) 0] \
                              "F19" [list $windefs(VK_F19) 0] \
                              "F20" [list $windefs(VK_F20) 0] \
                              "F21" [list $windefs(VK_F21) 0] \
                              "F22" [list $windefs(VK_F22) 0] \
                              "F23" [list $windefs(VK_F23) 0] \
                              "F24" [list $windefs(VK_F24) 0] \
                              "NUMLOCK" [list $windefs(VK_NUMLOCK) 0] \
                              "SCROLL" [list $windefs(VK_SCROLL) 0] \
                              "SCROLLLOCK" [list $windefs(VK_SCROLL) 0] \
                              "LSHIFT" [list $windefs(VK_LSHIFT) 0] \
                              "RSHIFT" [list $windefs(VK_RSHIFT) 0 -extended] \
                              "LCONTROL" [list $windefs(VK_LCONTROL) 0] \
                              "RCONTROL" [list $windefs(VK_RCONTROL) 0 -extended] \
                              "LMENU" [list $windefs(VK_LMENU) 0] \
                              "LALT" [list $windefs(VK_LMENU) 0] \
                              "RMENU" [list $windefs(VK_RMENU) 0 -extended] \
                              "RALT" [list $windefs(VK_RMENU) 0 -extended] \
                              "BROWSER_BACK" [list $windefs(VK_BROWSER_BACK) 0] \
                              "BROWSER_FORWARD" [list $windefs(VK_BROWSER_FORWARD) 0] \
                              "BROWSER_REFRESH" [list $windefs(VK_BROWSER_REFRESH) 0] \
                              "BROWSER_STOP" [list $windefs(VK_BROWSER_STOP) 0] \
                              "BROWSER_SEARCH" [list $windefs(VK_BROWSER_SEARCH) 0] \
                              "BROWSER_FAVORITES" [list $windefs(VK_BROWSER_FAVORITES) 0] \
                              "BROWSER_HOME" [list $windefs(VK_BROWSER_HOME) 0] \
                              "VOLUME_MUTE" [list $windefs(VK_VOLUME_MUTE) 0] \
                              "VOLUME_DOWN" [list $windefs(VK_VOLUME_DOWN) 0] \
                              "VOLUME_UP" [list $windefs(VK_VOLUME_UP) 0] \
                              "MEDIA_NEXT_TRACK" [list $windefs(VK_MEDIA_NEXT_TRACK) 0] \
                              "MEDIA_PREV_TRACK" [list $windefs(VK_MEDIA_PREV_TRACK) 0] \
                              "MEDIA_STOP" [list $windefs(VK_MEDIA_STOP) 0] \
                              "MEDIA_PLAY_PAUSE" [list $windefs(VK_MEDIA_PLAY_PAUSE) 0] \
                              "LAUNCH_MAIL" [list $windefs(VK_LAUNCH_MAIL) 0] \
                              "LAUNCH_MEDIA_SELECT" [list $windefs(VK_LAUNCH_MEDIA_SELECT) 0] \
                              "LAUNCH_APP1" [list $windefs(VK_LAUNCH_APP1) 0] \
                              "LAUNCH_APP2" [list $windefs(VK_LAUNCH_APP2) 0] \
                             ]
    }
    
}


#
# Constructs a list of input events by parsing a string in the format
# used by Visual Basic's SendKeys function
proc twapi::_parse_send_keys {keys {inputs ""}} {
    variable vk_map

    _init_vk_map

    set n [string length $keys]
    set trailer [list ]
    for {set i 0} {$i < $n} {incr i} {
        set key [string index $keys $i]
        switch -exact -- $key {
            "+" -
            "^" -
            "%" {
                lappend inputs [concat keydown $vk_map($key)]
                set trailer [linsert $trailer 0 [concat keyup $vk_map($key)]]
            }
            "~" {
                lappend inputs [concat key $vk_map(RETURN)]
                set inputs [concat $inputs $trailer]
                set trailer [list ]
            }
            "(" {
                # Recurse for paren expression
                set nextparen [string first ")" $keys $i]
                if {$nextparen == -1} {
                    error "Invalid key sequence - unterminated ("
                }
                set inputs [concat $inputs [_parse_send_keys [string range $keys [expr {$i+1}] [expr {$nextparen-1}]]]]
                set inputs [concat $inputs $trailer]
                set trailer [list ]
                set i $nextparen
            }
            "\{" {
                set nextbrace [string first "\}" $keys $i]
                if {$nextbrace == -1} {
                    error "Invalid key sequence - unterminated $key"
                }

                if {$nextbrace == ($i+1)} {
                    # Look for the next brace
                    set nextbrace [string first "\}" $keys $nextbrace]
                    if {$nextbrace == -1} {
                        error "Invalid key sequence - unterminated $key"
                    }
                }

                set key [string range $keys [expr {$i+1}] [expr {$nextbrace-1}]]
                set bracepat [string toupper $key]
                if {[info exists vk_map($bracepat)]} {
                    lappend inputs [concat key $vk_map($bracepat)]
                } else {
                    # May be pattern of the type {C} or {C N} where
                    # C is a single char and N is a count
                    set c [string index $key 0]
                    set count [string trim [string range $key 1 end]]
                    scan $c %c unicode
                    if {[string length $count] == 0} {
                        set count 1
                    } else {
                        # Note if $count is not an integer, an error
                        # will be generated as we want
                        incr count 0
                        if {$count < 0} {
                            error "Negative character count specified in braced key input"
                        }
                    }
                    for {set j 0} {$j < $count} {incr j} {
                        lappend inputs [list unicode 0 $unicode]
                    }
                }
                set inputs [concat $inputs $trailer]
                set trailer [list ]
                set i $nextbrace
            }
            default {
                scan $key %c unicode
                # Alphanumeric keys are treated separately so they will
                # work correctly with control modifiers
                if {$unicode >= 0x61 && $unicode <= 0x7A} {
                    # Lowercase letters
                    lappend inputs [list key [expr {$unicode-32}] 0]
                } elseif {$unicode >= 0x30 && $unicode <= 0x39} {
                    # Digits
                    lappend inputs [list key $unicode 0]
                } else {
                    lappend inputs [list unicode 0 $unicode]
                }
                set inputs [concat $inputs $trailer]
                set trailer [list ]
            }
        }
    }
    return $inputs
}

#
# Map style bits to a style symbol list
proc twapi::_style_mask_to_symbols {style exstyle} {
    variable windefs

    set attrs [list ]
    if {$style & $windefs(WS_POPUP)} {
        lappend attrs popup
        if {$style & $windefs(WS_GROUP)} { lappend attrs group }
        if {$style & $windefs(WS_TABSTOP)} { lappend attrs tabstop }
    } else {
        if {$style & $windefs(WS_CHILD)} {
            lappend attrs child
        } else {
            lappend attrs overlapped
        }
        if {$style & $windefs(WS_MINIMIZEBOX)} { lappend attrs minimizebox }
        if {$style & $windefs(WS_MAXIMIZEBOX)} { lappend attrs maximizebox }
    }
    
    # Note WS_BORDER, WS_DLGFRAME and WS_CAPTION use same bits
    if {$style & $windefs(WS_CAPTION)} {
        lappend attrs caption
    } else {
        if {$style & $windefs(WS_BORDER)} { lappend attrs border }
        if {$style & $windefs(WS_DLGFRAME)} { lappend attrs dlgframe }
    }

    foreach mask {
        WS_MINIMIZE WS_VISIBLE WS_DISABLED WS_CLIPSIBLINGS
        WS_CLIPCHILDREN WS_MAXIMIZE WS_VSCROLL WS_HSCROLL WS_SYSMENU
        WS_THICKFRAME
    } {
        if {$style & $windefs($mask)} {
            lappend attrs [string tolower [string range $mask 3 end]]
        }
    }

    if {$exstyle & $windefs(WS_EX_RIGHT)} {
        lappend attrs right
    } else {
        lappend attrs left
    }
    if {$exstyle & $windefs(WS_EX_RTLREADING)} {
        lappend attrs rtlreading
    } else {
        lappend attrs ltrreading
    }
    if {$exstyle & $windefs(WS_EX_LEFTSCROLLBAR)} {
        lappend attrs leftscrollbar
    } else {
        lappend attrs rightscrollbar
    }

    foreach mask {
        WS_EX_DLGMODALFRAME WS_EX_NOPARENTNOTIFY WS_EX_TOPMOST
        WS_EX_ACCEPTFILES WS_EX_TRANSPARENT WS_EX_MDICHILD WS_EX_TOOLWINDOW
        WS_EX_WINDOWEDGE WS_EX_CLIENTEDGE WS_EX_CONTEXTHELP WS_EX_CONTROLPARENT
        WS_EX_STATICEDGE WS_EX_APPWINDOW
    } {
        if {$exstyle & $windefs($mask)} {
            lappend attrs [string tolower [string range $mask 6 end]]
        }
    }
    
    return $attrs
}


#
# Test proc for displaying all colors for a class
proc twapi::_show_theme_colors {class part {state ""}} {
    set w [toplevel .themetest$class$part$state]

    set h [OpenThemeData [winfo id $w] $class]
    wm title $w "$class Colors"

    label $w.title -text "$class, $part, $state" -bg white
    grid $w.title -

    set part [::twapi::TwapiThemeDefineValue $part]
    set state [::twapi::TwapiThemeDefineValue $state]

    foreach x {BORDERCOLOR FILLCOLOR TEXTCOLOR EDGELIGHTCOLOR EDGESHADOWCOLOR EDGEFILLCOLOR TRANSPARENTCOLOR GRADIENTCOLOR1 GRADIENTCOLOR2 GRADIENTCOLOR3 GRADIENTCOLOR4 GRADIENTCOLOR5 SHADOWCOLOR GLOWCOLOR TEXTBORDERCOLOR TEXTSHADOWCOLOR GLYPHTEXTCOLOR FILLCOLORHINT BORDERCOLORHINT ACCENTCOLORHINT BLENDCOLOR} {
        set prop [::twapi::TwapiThemeDefineValue TMT_$x]
        if {![catch {twapi::GetThemeColor $h $part $state $prop} color]} {
            label $w.l-$x -text $x
            label $w.c-$x -text $color -bg $color
            grid $w.l-$x $w.c-$x
        }
    }
    CloseThemeData $h
}

#
# Test proc for displaying all fonts for a class
proc twapi::_show_theme_fonts {class part {state ""}} {
    set w [toplevel .themetest$class$part$state]

    set h [OpenThemeData [winfo id $w] $class]
    wm title $w "$class fonts"

    label $w.title -text "$class, $part, $state" -bg white
    grid $w.title -

    set part [::twapi::TwapiThemeDefineValue $part]
    set state [::twapi::TwapiThemeDefineValue $state]

    foreach x {GLYPHTYPE FONT} {
        set prop [::twapi::TwapiThemeDefineValue TMT_$x]
        if {![catch {twapi::GetThemeFont $h NULL $part $state $prop} font]} {
            label $w.l-$x -text $x
            label $w.c-$x -text $font
            grid $w.l-$x $w.c-$x
        }
    }
    CloseThemeData $h
}

# TBD - do we document this?
proc twapi::write_bmp_file {filename bmp} {
    # Assumes $bmp is clipboard content in format 8 (CF_DIB)
    
    # First parse the bitmap data to collect header information
    binary scan $bmp "iiissiiiiii" size width height planes bitcount compression sizeimage xpelspermeter ypelspermeter clrused clrimportant

    # We only handle BITMAPINFOHEADER right now (size must be 40)
    if {$size != 40} {
        error "Unsupported bitmap format. Header size=$size"
    }

    # We need to figure out the offset to the actual bitmap data
    # from the start of the file header. For this we need to know the
    # size of the color table which directly follows the BITMAPINFOHEADER
    if {$bitcount == 0} {
        error "Unsupported format: implicit JPEG or PNG"
    } elseif {$bitcount == 1} {
        set color_table_size 2
    } elseif {$bitcount == 4} {
        # TBD - Not sure if this is the size or the max size
        set color_table_size 16
    } elseif {$bitcount == 8} {
        # TBD - Not sure if this is the size or the max size
        set color_table_size 256
    } elseif {$bitcount == 16 || $bitcount == 32} {
        if {$compression == 0} {
            # BI_RGB
            set color_table_size $clrused
        } elseif {$compression == 3} {
            # BI_BITFIELDS
            set color_table_size 3
        } else {
            error "Unsupported compression type '$compression' for bitcount value $bitcount"
        }
    } elseif {$bitcount == 24} {
        set color_table_size $clrused
    } else {
        error "Unsupported value '$bitcount' in bitmap bitcount field"
    }

    set filehdr_size 14;                # sizeof(BITMAPFILEHEADER)
    set bitmap_file_offset [expr {$filehdr_size+$size+($color_table_size*4)}]
    set filehdr [binary format "a2 i x2 x2 i" "BM" [expr {$filehdr_size + [string length $bmp]}] $bitmap_file_offset]

    set fd [open $filename w]
    fconfigure $fd -translation binary

    puts -nonewline $fd $filehdr
    puts -nonewline $fd $bmp

    close $fd
}

#
# utility procedure to map symbolic hotkey to {modifiers virtualkey}
proc twapi::_hotkeysyms_to_vk {hotkey} {
    variable vk_map
    
    _init_vk_map

    set keyseq [split [string tolower $hotkey] -]
    set key [lindex $keyseq end]

    # Convert modifiers to bitmask
    set modifiers 0
    foreach modifier [lrange $keyseq 0 end-1] {
        switch -exact -- [string tolower $modifier] {
            ctrl -
            control {
                setbits modifiers 2
            }

            alt -
            menu {
                setbits modifiers 1
            }

            shift {
                setbits modifiers 4
            }

            win {
                setbits modifiers 8
            }

            default {
                error "Unknown key modifier $modifier"
            }
        }
    }
    # Map the key to a virtual key code
    if {[string length $key] == 1} {
        # Single character
        scan $key %c unicode
        
        # Only allow alphanumeric keys and a few punctuation symbols
        # since keyboard layouts are not standard
        if {$unicode >= 0x61 && $unicode <= 0x7A} {
            # Lowercase letters - change to upper case virtual keys
            set vk [expr {$unicode-32}]
        } elseif {($unicode >= 0x30 && $unicode <= 0x39)
                  || ($unicode >= 0x41 && $unicode <= 0x5A)} {
            # Digits or upper case
            set vk $unicode
        } else {
            error "Only alphanumeric characters may be specified for the key. For non-alphanumeric characters, specify the virtual key code"
        }
    } elseif {[info exists vk_map($key)]} {
        # It is a virtual key name
        set vk [lindex $vk_map($key) 0]
    } elseif {[info exists vk_map([string toupper $key])]} {
        # It is a virtual key name
        set vk [lindex $vk_map([string toupper $key]) 0]
    } elseif {[string is integer $key]} {
        # Actual virtual key specification
        set vk $key
    } else {
        error "Unknown or invalid key specifier '$key'"            
    }

    return [list $modifiers $vk]
}
