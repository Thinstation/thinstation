#
# Copyright (c) 2003-2006, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

# TBD - allow access rights to be specified symbolically using procs
# from security.tcl
# TBD - add -user option to get_process_info and get_thread_info
# TBD - add wrapper for GetProcessExitCode

namespace eval twapi {
}

#
# Get my process id
proc twapi::get_current_process_id {} {
    return [::pid]
}

#
# Get my thread id
proc twapi::get_current_thread_id {} {
    return [GetCurrentThreadId]
}

# Return list of process ids
# Note if -path or -name is specified, then processes for which this
# information cannot be obtained are skipped
proc twapi::get_process_ids {args} {

    set save_args $args;                # Need to pass to process_exists
    array set opts [parseargs args {
        user.arg
        path.arg
        name.arg
        logonsession.arg
        glob} -maxleftover 0]

    if {[info exists opts(path)] && [info exists opts(name)]} {
        error "Options -path and -name are mutually exclusive"
    }

    if {$opts(glob)} {
        set match_op match
    } else {
        set match_op equal
    }

    set process_pids [list ]

    # If we do not care about user or path, Twapi_GetProcessList
    # is faster than EnumProcesses or the WTS functions
    if {[info exists opts(user)] == 0 &&
        [info exists opts(logonsession)] == 0 &&
        [info exists opts(path)] == 0} {
        if {[info exists opts(name)] == 0} {
            return [Twapi_GetProcessList -1 0]
        }
        # We need to match against the name
        foreach {pid piddata} [Twapi_GetProcessList -1 2] {
            if {[string $match_op -nocase $opts(name) [kl_get $piddata ProcessName]]} {
                lappend process_pids $pid
            }
        }
        return $process_pids
    }
    
    # Only want pids with a specific user or path

    # If is the name we are looking for, try using the faster WTS
    # API's first. If they are not available, we try a slower method
    # If we need to match paths or logon sessions, we don't try this
    # at all as the wts api's don't provide that info
    if {[info exists opts(path)] == 0 &&
        [info exists opts(logonsession)] == 0} {
        if {[info exists opts(user)]} {
            if {[catch {map_account_to_sid $opts(user)} sid]} {
                # No such user. Return empty list (no processes)
                return [list ]
            }
        }
        if {! [catch {WTSEnumerateProcesses NULL} wtslist]} {
            foreach wtselem $wtslist {
                array set procinfo $wtselem
                if {[info exists sid] &&
                    $procinfo(pUserSid) ne $sid} {
                    continue;           # User does not match
                }
                if {[info exists opts(name)]} {
                    # We need to match on name as well
                    if {![string $match_op -nocase $opts(name) $procinfo(pProcessName)]} {
                        # No match
                        continue
                    }
                }
                lappend process_pids $procinfo(ProcessId)
            }
            return $process_pids
        }
    }

    # Either we are matching on path/logonsession, or the WTS call failed
    # Try yet another way.

    # Note that in the code below, we use "file join" with a single arg
    # to convert \ to /. Do not use file normalize as that will also
    # land up converting relative paths to full paths
    if {[info exists opts(path)]} {
        set opts(path) [file join $opts(path)]
    }

    set process_pids [list ]
    if {[info exists opts(name)]} {
        # Note we may reach here if the WTS call above failed
        foreach {pid piddata} [Twapi_GetProcessList -1 2] {
            if {[string $match_op -nocase $opts(name) [kl_get $piddata ProcessName]]} {
                lappend all_pids $pid
            }
        }
    } else {
        set all_pids [Twapi_GetProcessList -1 0]
    }

    set popts [list ]
    foreach opt {path user logonsession} {
        if {[info exists opts($opt)]} {
            lappend popts -$opt
        }
    }
    foreach {pid piddata} [eval [list get_multiple_process_info $all_pids] $popts] {
        array set pidvals $piddata
        if {[info exists opts(path)] &&
            ![string $match_op -nocase $opts(path) [file join $pidvals(-path)]]} {
            continue
        }

        if {[info exists opts(user)] && $pidvals(-user) ne $opts(user)} {
            continue
        }

        if {[info exists opts(logonsession)] &&
            $pidvals(-logonsession) ne $opts(logonsession)} {
            continue
        }

        lappend process_pids $pid
    }
    return $process_pids
}


# Return list of modules handles for a process
proc twapi::get_process_modules {pid args} {
    variable windefs

    array set opts [parseargs args {handle name path imagedata all}]

    if {$opts(all)} {
        foreach opt {handle name path imagedata} {
            set opts($opt) 1
        }
    }
    set noopts [expr {($opts(name) || $opts(path) || $opts(imagedata) || $opts(handle)) == 0}]

    set privs [expr {$windefs(PROCESS_QUERY_INFORMATION) | $windefs(PROCESS_VM_READ)}]
    set hpid [OpenProcess $privs 0 $pid]
    set results [list ]
    try {
        foreach module [EnumProcessModules $hpid] {
            if {$noopts} {
                lappend results $module
                continue
            }
            set module_data [list ]
            if {$opts(handle)} {
                lappend module_data -handle $module
            }
            if {$opts(name)} {
                if {[catch {GetModuleBaseName $hpid $module} name]} {
                    set name ""
                }
                lappend module_data -name $name
            }
           if {$opts(path)} {
                if {[catch {GetModuleFileNameEx $hpid $module} path]} {
                    set path ""
                }
               lappend module_data -path [_normalize_path $path]
            }
            if {$opts(imagedata)} {
                if {[catch {GetModuleInformation $hpid $module} imagedata]} {
                    set base ""
                    set size ""
                    set entry ""
                } else {
                    array set temp $imagedata
                    set base $temp(lpBaseOfDll)
                    set size $temp(SizeOfImage)
                    set entry $temp(EntryPoint)
                }                
                lappend module_data -imagedata [list $base $size $entry]
            }
            lappend results $module_data
        }
    } finally {
        CloseHandle $hpid
    }
    return $results
}



#
# Get the path of a process
proc twapi::get_process_path {pid args} {
    return [eval [list twapi::_get_process_name_path_helper $pid path] $args]
}


#
# Get the path of a process
proc twapi::get_process_name {pid args} {
    return [eval [list twapi::_get_process_name_path_helper $pid name] $args]
}


# Return list of device drivers
proc twapi::get_device_drivers {args} {
    variable windefs

    array set opts [parseargs args {name path base all}]

    set results [list ]
    foreach module [EnumDeviceDrivers] {
        catch {unset module_data}
        if {$opts(base) || $opts(all)} {
            set module_data [list -base $module]
        }
        if {$opts(name) || $opts(all)} {
            if {[catch {GetDeviceDriverBaseName $module} name]} {
                    set name ""
            }
            lappend module_data -name $name
        }
        if {$opts(path) || $opts(all)} {
            if {[catch {GetDeviceDriverFileName $module} path]} {
                set path ""
            }
            lappend module_data -path [_normalize_path $path]
        }
        if {[info exists module_data]} {
            lappend results $module_data
        }
    }

    return $results
}

#
# Kill a process 
# Returns 1 if process was ended, 0 if not ended within timeout
# 
proc twapi::end_process {pid args} {

    array set opts [parseargs args {
        {exitcode.int 1}
        force
        {wait.int 0}
    }]
    
    set process_path [get_process_path $pid]

    # First try to close nicely
    set toplevels [get_toplevel_windows -pid $pid]
    if {[llength $toplevels]} {
        # Try and close by sending them a message. WM_CLOSE is 0x10
        foreach toplevel $toplevels {
            # Send a message but come back right away
            if {0} {
                catch {PostMessage $toplevel 0x10 0 0}
            } else {
                catch {SendNotifyMessage $toplevel 0x10 0 0}
            }
        }

        # Wait for the specified time to verify process has gone away
        set gone [twapi::wait {process_exists $pid -path $process_path} 0 $opts(wait)]
        if {$gone || ! $opts(force)} {
            # Succeeded or do not want to force a kill
            return $gone
        }
        
        # Only wait 10 ms since we have already waited above
        if {$opts(wait)} {
            set opts(wait) 10
        }
    }

    # Open the process for terminate access. IF access denied (5), retry after
    # getting the required privilege
    try {
        set hpid [OpenProcess $twapi::windefs(PROCESS_TERMINATE) 0 $pid]
    } onerror {TWAPI_WIN32 5} {
        # Retry - if still fail, then just throw the error
        eval_with_privileges {
            set hpid [OpenProcess $twapi::windefs(PROCESS_TERMINATE) 0 $pid]
        } SeDebugPrivilege
    }

    try {
        TerminateProcess $hpid $opts(exitcode)
    } finally {
        CloseHandle $hpid
    }

    if {0} {
        While the process is being terminated, we can get access denied
        if we try to get the path so this if branch is commented out
        return [twapi::wait {process_exists $pid -path $process_path} 0 $opts(wait)]
    } else {
        return [twapi::wait {process_exists $pid} 0 $opts(wait)]
    }
}


# Check if the given process exists
# 0 - does not exist or exists but paths/names do not match, 
# 1 - exists and matches path (or no -path or -name specified)
# -1 - exists but do not know path and cannot compare
proc twapi::process_exists {pid args} {
    array set opts [parseargs args { path.arg name.arg glob}]

    # Simplest case - don't care about name or path
    if {! ([info exists opts(path)] || [info exists opts(name)])} {
        if {[llength [Twapi_GetProcessList $pid 0]] == 0} {
            return 0
        } else {
            return 1
        }
    }

    # Can't specify both name and path
    if {[info exists opts(path)] && [info exists opts(name)]} {
        error "Options -path and -name are mutually exclusive"
    }

    if {$opts(glob)} {
        set string_cmd match
    } else {
        set string_cmd equal
    }

    if {[info exists opts(name)]} {
        # Name is specified
        set piddata [Twapi_GetProcessList $pid 2]
        if {[llength $piddata] &&
            [string $string_cmd -nocase $opts(name) [kl_get [lindex $piddata 1] ProcessName]]} {
            # PID exists and name matches
            return 1
        } else {
            return 0
        }
    }

    # Need to match on the path
    set process_path [get_process_path $pid -noexist "" -noaccess "(unknown)"]
    if {[string length $process_path] == 0} {
        # No such process
        return 0
    }

    # Process with this pid exists
    # Path still has to match
    if {[string equal $process_path "(unknown)"]} {
        # Exists but cannot check path/name
        return -1
    }

    # Note we do not use file normalize here since that will tack on
    # absolute paths which we do not want for glob matching

    # We use [file join ] to convert \ to / to avoid special
    # interpretation of \ in string match command
    return [string $string_cmd -nocase [file join $opts(path)] [file join $process_path]]
}

#
# Get the parent process of a thread. Return "" if no such thread
proc twapi::get_thread_parent_process_id {tid} {
    set status [catch {
        set th [get_thread_handle $tid]
        try {
            set pid [lindex [lindex [Twapi_NtQueryInformationThreadBasicInformation $th] 2] 0]
        } finally {
            close_handles [list $th]
        }
    }]

    if {$status == 0} {
        return $pid
    }


    # Could not use undocumented function. Try slooooow perf counter method
    set pid_paths [get_perf_thread_counter_paths $tid -pid]
    if {[llength $pid_paths] == 0} {
        return ""
    }
    
    if {[get_counter_path_value [lindex [lindex $pid_paths 0] 3] -var pid]} {
        return $pid
    } else {
        return ""
    }
}

#
# Get the thread ids belonging to a process
proc twapi::get_process_thread_ids {pid} {
    return [lindex [lindex [get_multiple_process_info [list $pid] -tids] 1] 1]
}


#
# Get process information 
proc twapi::get_process_info {pid args} {
    return [lindex [eval [list get_multiple_process_info [list $pid]] $args] 1]
}


#
# Get multiple process information 
proc twapi::get_multiple_process_info {pids args} {

    # Options that are directly available from Twapi_GetProcessList
    if {![info exists ::twapi::get_multiple_process_info_base_opts]} {
        # Array value is the flags to pass to Twapi_GetProcessList
        array set ::twapi::get_multiple_process_info_base_opts {
            basepriority       1
            parent             1
            tssession          1
            name               2
            createtime         4
            usertime           4
            privilegedtime     4
            elapsedtime        4
            handlecount        4
            pagefaults         8
            pagefilebytes      8
            pagefilebytespeak  8
            poolnonpagedbytes  8
            poolnonpagedbytespeak  8
            poolpagedbytes     8
            poolpagedbytespeak 8
            threadcount        4
            virtualbytes       8
            virtualbytespeak   8
            workingset         8
            workingsetpeak     8
            tids               32
        }

        # The ones below are not supported on NT 4
        if {[min_os_version 5]} {
            array set ::twapi::get_multiple_process_info_base_opts {
                ioreadops         16
                iowriteops        16
                iootherops        16
                ioreadbytes       16
                iowritebytes      16
                iootherbytes      16
            }
        }
    }

    
    # Note the PDH options match those of twapi::get_process_perf_counter_paths
    set pdh_opts {
        privatebytes
    }

    set pdh_rate_opts {
        privilegedutilization
        processorutilization
        userutilization
        iodatabytesrate
        iodataopsrate
        iootherbytesrate
        iootheropsrate
        ioreadbytesrate
        ioreadopsrate
        iowritebytesrate
        iowriteopsrate
        pagefaultrate
    }

    set token_opts {
        user
        groups
        primarygroup
        privileges
        logonsession
    }

    array set opts [parseargs args \
                        [concat [list all \
                                     pid \
                                     handles \
                                     path \
                                     toplevels \
                                     commandline \
                                     [list noexist.arg "(no such process)"] \
                                     [list noaccess.arg "(unknown)"] \
                                     [list interval.int 100]] \
                             [array names ::twapi::get_multiple_process_info_base_opts] \
                             $token_opts \
                             $pdh_opts \
                             $pdh_rate_opts]]

    array set results {}

    # If user is requested, try getting it through terminal services
    # if possible since the token method fails on some newer platforms
    if {$opts(all) || $opts(user)} {
        _get_wts_pids wtssids wtsnames
    }

    # See if any Twapi_GetProcessList options are requested and if
    # so, calculate the appropriate flags
    set flags 0
    foreach opt [array names ::twapi::get_multiple_process_info_base_opts] {
        if {$opts($opt) || $opts(all)} {
            set flags [expr {$flags | $::twapi::get_multiple_process_info_base_opts($opt)}]
        }
    }
    if {$flags} {
        if {[llength $pids] == 1} {
            array set basedata [twapi::Twapi_GetProcessList [lindex $pids 0] $flags]
        } else {
            array set basedata [twapi::Twapi_GetProcessList -1 $flags]
        }
    }

    foreach pid $pids {
        set result [list ]

        if {$opts(all) || $opts(pid)} {
            lappend result -pid $pid
        }

        foreach {opt field} {
            createtime         CreateTime
            usertime           UserTime
            privilegedtime     KernelTime
            handlecount        HandleCount
            pagefaults         VmCounters.PageFaultCount
            pagefilebytes      VmCounters.PagefileUsage
            pagefilebytespeak  VmCounters.PeakPagefileUsage
            poolnonpagedbytes  VmCounters.QuotaNonPagedPoolUsage
            poolnonpagedbytespeak  VmCounters.QuotaPeakNonPagedPoolUsage
            poolpagedbytespeak     VmCounters.QuotaPeakPagedPoolUsage
            poolpagedbytes     VmCounters.QuotaPagedPoolUsage
            basepriority       BasePriority
            threadcount        ThreadCount
            virtualbytes       VmCounters.VirtualSize
            virtualbytespeak   VmCounters.PeakVirtualSize
            workingset         VmCounters.WorkingSetSize
            workingsetpeak     VmCounters.PeakWorkingSetSize
            ioreadops          IoCounters.ReadOperationCount
            iowriteops         IoCounters.WriteOperationCount
            iootherops         IoCounters.OtherOperationCount
            ioreadbytes        IoCounters.ReadTransferCount
            iowritebytes       IoCounters.WriteTransferCount
            iootherbytes       IoCounters.OtherTransferCount
            parent             InheritedFromProcessId
            tssession          SessionId
        } {
            if {$opts($opt) || $opts(all)} {
                if {[info exists basedata($pid)]} {
                    lappend result -$opt [twapi::kl_get $basedata($pid) $field]
                } else {
                    lappend result -$opt $opts(noexist)
                }
            }
        }

        if {$opts(elapsedtime) || $opts(all)} {
            if {[info exists basedata($pid)]} {
                lappend result -elapsedtime [expr {[clock seconds]-[large_system_time_to_secs [twapi::kl_get $basedata($pid) CreateTime]]}]
            } else {
                lappend result -elapsedtime $opts(noexist)
            }
        }

        if {$opts(tids) || $opts(all)} {
            if {[info exists basedata($pid)]} {
                set tids [list ]
                foreach {tid threaddata} [twapi::kl_get $basedata($pid) Threads] {
                    lappend tids $tid
                }
                lappend result -tids $tids
            } else {
                lappend result -tids $opts(noexist)
            }
        }

        if {$opts(name) || $opts(all)} {
            if {[info exists basedata($pid)]} {
                set name [twapi::kl_get $basedata($pid) ProcessName]
                if {$name eq ""} {
                    if {[is_system_pid $pid]} {
                        set name "System"
                    } elseif {[is_idle_pid $pid]} {
                        set name "System Idle Process"
                    }
                }
                lappend result -name $name
            } else {
                lappend result -name $opts(noexist)
            }
        }
        
        if {$opts(all) || $opts(path)} {
            lappend result -path [get_process_path $pid -noexist $opts(noexist) -noaccess $opts(noaccess)]
        }
        
        if {$opts(all) || $opts(toplevels)} {
            set toplevels [get_toplevel_windows -pid $pid]
            if {[llength $toplevels]} {
                lappend result -toplevels $toplevels
            } else {
                if {[process_exists $pid]} {
                    lappend result -toplevels [list ]
                } else {
                    lappend result -toplevels $opts(noexist)
                }
            }
        }

        # NOTE: we do not check opts(all) for handles since the latter
        # is an unsupported option
        if {$opts(handles)} {
            set handles [list ]
            foreach hinfo [get_open_handles $pid] {
                lappend handles [list [kl_get $hinfo -handle] [kl_get $hinfo -type] [kl_get $hinfo -name]]
            }
            lappend result -handles $handles
        }

        if {$opts(all) || $opts(commandline)} {
            lappend result -commandline [get_process_commandline $pid -noexist $opts(noexist) -noaccess $opts(noaccess)]
        }

        # Now get token related info, if any requested
        set requested_opts [list ]
        if {$opts(all) || $opts(user)} {
            # See if we already have the user. Note sid of system idle
            # will be empty string
            if {[info exists wtssids($pid)]} {
                if {$wtssids($pid) == ""} {
                    # Put user as System
                    lappend result -user "SYSTEM"
                } else {
                    # We speed up account lookup by caching sids
                    if {[info exists sidcache($wtssids($pid))]} {
                        lappend result -user $sidcache($wtssids($pid))
                    } else {
                        set uname [lookup_account_sid $wtssids($pid)]
                        lappend result -user $uname
                        set sidcache($wtssids($pid)) $uname
                    }
                }
            } else {
                lappend requested_opts -user
            }
        }
        foreach opt {groups primarygroup privileges logonsession} {
            if {$opts(all) || $opts($opt)} {
                lappend requested_opts -$opt
            }
        }
        if {[llength $requested_opts]} {
            try {
                eval lappend result [_get_token_info process $pid $requested_opts]
            } onerror {TWAPI_WIN32 5} {
                foreach opt $requested_opts {
                    set tokresult($opt) $opts(noaccess)
                }
                # The NETWORK SERVICE and LOCAL SERVICE processes cannot
                # be accessed. If we are looking for the logon session for
                # these, try getting it from the witssid if we have it
                # since the logon session is hardcoded for these accounts
                if {[lsearch -exact $requested_opts "-logonsession"] >= 0} {
                    if {![info exists wtssids]} {
                        _get_wts_pids wtssids wtsnames
                    }
                    if {[info exists wtssids($pid)]} {
                        # Map user SID to logon session
                        switch -exact -- $wtssids($pid) {
                            S-1-5-18 {
                                # SYSTEM
                                set tokresult(-logonsession) 00000000-000003e7
                            }
                            S-1-5-19 {
                                # LOCAL SERVICE
                                set tokresult(-logonsession) 00000000-000003e5
                            }
                            S-1-5-20 {
                                # LOCAL SERVICE
                                set tokresult(-logonsession) 00000000-000003e4
                            }
                        }
                    }
                }
                set result [concat $result [array get tokresult]]
            } onerror {TWAPI_WIN32 87} {
                foreach opt $requested_opts {
                    lappend result $opt $opts(noexist)
                }
            }
        }

        set results($pid) $result
    }

    # Now deal with the PDH stuff. We need to track what data we managed
    # to get
    array set gotdata {}

    # Now retrieve each PDH non-rate related counter which do not
    # require an interval of measurement
    set wanted_pdh_opts [_array_non_zero_switches opts $pdh_opts $opts(all)]
    if {[llength $wanted_pdh_opts] != 0} {
        set counters [eval [list get_perf_process_counter_paths $pids] \
                          $wanted_pdh_opts]
        foreach {opt pid val} [get_perf_values_from_metacounter_info $counters -interval 0] {
            lappend results($pid) $opt $val
            set gotdata($pid,$opt) 1; # Since we have the data
        }
    }

    # NOw do the rate related counter. Again, we need to track missing data
    set wanted_pdh_rate_opts [_array_non_zero_switches opts $pdh_rate_opts $opts(all)]
    foreach pid $pids {
        foreach opt $wanted_pdh_rate_opts {
            set missingdata($pid,$opt) 1
        }
    }
    if {[llength $wanted_pdh_rate_opts] != 0} {
        set counters [eval [list get_perf_process_counter_paths $pids] \
                          $wanted_pdh_rate_opts]
        foreach {opt pid val} [get_perf_values_from_metacounter_info $counters -interval $opts(interval)] {
            lappend results($pid) $opt $val
            set gotdata($pid,$opt) 1; # Since we have the data
        }
    }

    # For data that we could not get from PDH assume the process does not exist
    foreach pid $pids {
        foreach opt [concat $wanted_pdh_opts $wanted_pdh_rate_opts] {
            if {![info exists gotdata($pid,$opt)]} {
                # Could not get this combination. Assume missing process
                lappend results($pid) $opt $opts(noexist)
            }
        }
    }

    return [array get results]
}


#
# Get thread information 
# TBD - add info from GetGUIThreadInfo
proc twapi::get_thread_info {tid args} {

    # Options that are directly available from Twapi_GetProcessList
    if {![info exists ::twapi::get_thread_info_base_opts]} {
        # Array value is the flags to pass to Twapi_GetProcessList
        array set ::twapi::get_thread_info_base_opts {
            pid 32
            elapsedtime 96
            waittime 96
            usertime 96
            createtime 96
            privilegedtime 96
            contextswitches 96
            basepriority 160
            priority 160
            startaddress 160
            state 160
            waitreason 160
        }
    }

    # Note the PDH options match those of twapi::get_thread_perf_counter_paths
    # Right now, we don't need any PDH non-rate options
    set pdh_opts {
    }
    set pdh_rate_opts {
        privilegedutilization 
        processorutilization
        userutilization
        contextswitchrate
    }

    set token_opts {
        groups
        user
        primarygroup
        privileges
    }

    array set opts [parseargs args \
                        [concat [list all tid [list interval.int 100]] \
                             [array names ::twapi::get_thread_info_base_opts] \
                             $token_opts $pdh_opts $pdh_rate_opts]]

    set requested_opts [_array_non_zero_switches opts $token_opts $opts(all)]
    # Now get token info, if any
    if {[llength $requested_opts]} {
        if {[catch {_get_token_info thread $tid $requested_opts} results]} {
            set erCode $::errorCode
            set erInfo $::errorInfo
            if {[string equal [lindex $erCode 0] "TWAPI_WIN32"] &&
                [lindex $erCode 1] == 1008} {
                # Thread does not have its own token. Use it's parent process
                set results [_get_token_info process [get_thread_parent_process_id $tid] $requested_opts]
            } else {
                error $results $erInfo $erCode
            }
        }
    } else {
        set results [list ]
    }

    # Now get the base options
    set flags 0
    foreach opt [array names ::twapi::get_thread_info_base_opts] {
        if {$opts($opt) || $opts(all)} {
            set flags [expr {$flags | $::twapi::get_thread_info_base_opts($opt)}]
        }
    }

    if {$flags} {
        # We need at least one of the base options
        foreach {pid piddata} [twapi::Twapi_GetProcessList -1 $flags] {
            foreach {thread_id threaddata} [kl_get $piddata Threads] {
                if {$tid == $thread_id} {
                    # Found the thread we want
                    array set threadinfo $threaddata
                    break
                }
            }
            if {[info exists threadinfo]} {
                break;  # Found it, no need to keep looking through other pids
            }
        }
        # It is possible that we looped through all the processs without
        # a thread match. Hence we check again that we have threadinfo
        # Note currently as in older versions, we do not pass back
        # any fields if the thread did not exist. Perhaps that should
        # be changed to behave similar to get_process_info
        if {[info exists threadinfo]} {
            foreach {opt field} {
                pid            ClientId.UniqueProcess
                waittime       WaitTime
                usertime       UserTime
                createtime     CreateTime
                privilegedtime KernelTime
                basepriority   BasePriority
                priority       Priority
                startaddress   StartAddress
                state          State
                waitreason     WaitReason
                contextswitches ContextSwitchCount
            } {
                if {$opts($opt) || $opts(all)} {
                    lappend results -$opt $threadinfo($field)
                }
            }

            if {$opts(elapsedtime) || $opts(all)} {
                lappend results -elapsedtime [expr {[clock seconds]-[large_system_time_to_secs $threadinfo(CreateTime)]}]
            }
        }
    }

    # Now retrieve each PDH non-rate related counter which do not
    # require an interval of measurement
    set requested_opts [_array_non_zero_switches opts $pdh_opts $opts(all)]
    if {[llength $requested_opts] != 0} {
        set counter_list [eval [list get_perf_thread_counter_paths [list $tid]] \
                          $requested_opts]
        foreach {opt tid value} [get_perf_values_from_metacounter_info $counter_list -interval 0] {
            lappend results $opt $value
        }
    }

    # Now do the same for any interval based counters
    set requested_opts [_array_non_zero_switches opts $pdh_rate_opts $opts(all)]
    if {[llength $requested_opts] != 0} {
        set counter_list [eval [list get_perf_thread_counter_paths [list $tid]] \
                          $requested_opts]
        foreach {opt tid value} [get_perf_values_from_metacounter_info $counter_list -interval $opts(interval)] {
            lappend results $opt $value
        }
    }

    if {$opts(all) || $opts(tid)} {
        lappend results -tid $tid
    }

    return $results
}


#
# Wait until the process is ready
proc twapi::process_waiting_for_input {pid args} {
    array set opts [parseargs args {{wait.int 0}}]

    set hpid [OpenProcess $twapi::windefs(PROCESS_QUERY_INFORMATION) 0 $pid]
    try {
        set status [WaitForInputIdle $hpid $opts(wait)]
    } finally {
        CloseHandle $hpid
    }
    return $status
}

#
# Create a process
proc twapi::create_process {path args} {
    array set opts [parseargs args \
                        [list \
                             [list cmdline.arg ""] \
                             [list inheritablechildprocess.bool 0] \
                             [list inheritablechildthread.bool 0] \
                             [list childprocesssecd.arg ""] \
                             [list childthreadsecd.arg ""] \
                             [list inherithandles.bool 0] \
                             [list env.arg ""] \
                             [list startdir.arg ""] \
                             [list inheriterrormode.bool 1] \
                             [list newconsole.bool 0] \
                             [list detached.bool 0] \
                             [list newprocessgroup.bool 0] \
                             [list noconsole.bool 0] \
                             [list separatevdm.bool 0] \
                             [list sharedvdm.bool 0] \
                             [list createsuspended.bool 0] \
                             [list debugchildtree.bool 0] \
                             [list debugchild.bool 0] \
                             [list priority.arg "normal" [list normal abovenormal belownormal high realtime idle]] \
                             [list desktop.arg "__null__"] \
                             [list title.arg ""] \
                             windowpos.arg \
                             windowsize.arg \
                             screenbuffersize.arg \
                             [list feedbackcursoron.bool false] \
                             [list feedbackcursoroff.bool false] \
                             background.arg \
                             foreground.arg \
                             [list fullscreen.bool false] \
                             [list showwindow.arg ""] \
                             [list stdhandles.arg ""] \
                             [list stdchannels.arg ""] \
                             [list returnhandles.bool 0]\
                            ]]
                             
    set process_sec_attr [_make_secattr $opts(childprocesssecd) $opts(inheritablechildprocess)]
    set thread_sec_attr [_make_secattr $opts(childthreadsecd) $opts(inheritablechildthread)]

    # Check incompatible options
    foreach {opt1 opt2} {
        newconsole detached
        sharedvdm  separatevdm
    } {
        if {$opts($opt1) && $opts($opt2)} {
            error "Options -$opt1 and -$opt2 cannot be specified together"
        }
    }
    # Create the start up info structure
    set si_flags 0
    if {[info exists opts(windowpos)]} {
        foreach {xpos ypos} [_parse_integer_pair $opts(windowpos)] break
        setbits si_flags 0x4
    } else {
        set xpos 0
        set ypos 0
    }
    if {[info exists opts(windowsize)]} {
        foreach {xsize ysize} [_parse_integer_pair $opts(windowsize)] break
        setbits si_flags 0x2
    } else {
        set xsize 0
        set ysize 0
    }
    if {[info exists opts(screenbuffersize)]} {
        foreach {xscreen yscreen} [_parse_integer_pair $opts(screenbuffersize)] break
        setbits si_flags 0x8
    } else {
        set xscreen 0
        set yscreen 0
    }

    set fg 7;                           # Default to white
    set bg 0;                           # Default to black
    if {[info exists opts(foreground)]} {
        set fg [_map_console_color $opts(foreground) 0]
        setbits si_flags 0x10
    }
    if {[info exists opts(background)]} {
        set bg [_map_console_color $opts(background) 1]
        setbits si_flags 0x10
    }

    if {$opts(feedbackcursoron)} {
        setbits si_flags 0x40
    }

    if {$opts(feedbackcursoron)} {
        setbits si_flags 0x80
    }

    if {$opts(fullscreen)} {
        setbits si_flags 0x20
    }

    switch -exact -- $opts(showwindow) {
        ""        { }
        hidden    {set opts(showwindow) 0}
        normal    {set opts(showwindow) 1}
        minimized {set opts(showwindow) 2}
        maximized {set opts(showwindow) 3}
        default   {error "Invalid value '$opts(showwindow)' for -showwindow option"}
    }
    if {[string length $opts(showwindow)]} {
        setbits si_flags 0x1
    }
    
    if {[llength $opts(stdhandles)] && [llength $opts(stdchannels)]} {
        error "Options -stdhandles and -stdchannels cannot be used together"
    }

    if {[llength $opts(stdhandles)]} {
        if {! $opts(inherithandles)} {
            error "Cannot specify -stdhandles option if option -inherithandles is specified as 0"
        }
        setbits si_flags 0x100
    }

    if {[llength $opts(stdchannels)]} {
        if {! $opts(inherithandles)} {
            error "Cannot specify -stdhandles option if option -inherithandles is specified as 0"
        }
        if {[llength $opts(stdchannels)] != 3} {
            error "Must specify 3 channels for -stdchannels option corresponding stdin, stdout and stderr"
        }

        setbits si_flags 0x100

        # Convert the channels to handles
        lappend opts(stdhandles) [duplicate_handle [get_tcl_channel_handle [lindex $opts(stdchannels) 0] read] -inherit]
        lappend opts(stdhandles) [duplicate_handle [get_tcl_channel_handle [lindex $opts(stdchannels) 1] write] -inherit]
        lappend opts(stdhandles) [duplicate_handle [get_tcl_channel_handle [lindex $opts(stdchannels) 2] write] -inherit]
    }

    set startup [list $opts(desktop) $opts(title) $xpos $ypos \
                     $xsize $ysize $xscreen $yscreen \
                     [expr {$fg|$bg}] $si_flags $opts(showwindow) \
                     $opts(stdhandles)]

    # Figure out process creation flags
    set flags 0x00000400;               # CREATE_UNICODE_ENVIRONMENT
    foreach {opt flag} {
        debugchildtree       0x00000001
        debugchild           0x00000002
        createsuspended      0x00000004
        detached             0x00000008
        newconsole           0x00000010
        newprocessgroup      0x00000200
        separatevdm          0x00000800
        sharedvdm            0x00001000
        inheriterrormode     0x04000000
        noconsole            0x08000000    
    } {
        if {$opts($opt)} {
            setbits flags $flag
        }
    }

    switch -exact -- $opts(priority) {
        normal      {set priority 0x00000020}
        abovenormal {set priority 0x00008000}
        belownormal {set priority 0x00004000}
        ""          {set priority 0}
        high        {set priority 0x00000080}
        realtime    {set priority 0x00000100}
        idle        {set priority 0x00000040}
        default     {error "Unknown priority '$priority'"}
    }
    setbits flags $priority

    # Create the environment strings
    if {[llength $opts(env)]} {
        set child_env [list ]
        foreach {envvar envval} $opts(env) {
            lappend child_env "$envvar=$envval"
        }
    } else {
        set child_env "__null__"
    }
    
    try {
        foreach {ph th pid tid} [CreateProcess [file nativename $path] \
                                     $opts(cmdline) \
                                     $process_sec_attr $thread_sec_attr \
                                     $opts(inherithandles) $flags $child_env \
                                     [file normalize $opts(startdir)] $startup] {
            break
        }
    } finally {
        # If opts(stdchannels) is not an empty list, we duplicated the handles
        # into opts(stdhandles) ourselves so free them
        if {[llength $opts(stdchannels)]} {
            # Free corresponding handles in opts(stdhandles)
            eval close_handles $opts(stdhandles)
        }
    }

    # From the Tcl source code - (tclWinPipe.c)
    #     /* 
    #      * "When an application spawns a process repeatedly, a new thread 
    #      * instance will be created for each process but the previous 
    #      * instances may not be cleaned up.  This results in a significant 
    #      * virtual memory loss each time the process is spawned.  If there 
    #      * is a WaitForInputIdle() call between CreateProcess() and
    #      * CloseHandle(), the problem does not occur." PSS ID Number: Q124121
    #      */
    # WaitForInputIdle $ph 5000 -- Apparently this is only needed for NT 3.5


    if {$opts(returnhandles)} {
        return [list $pid $tid $ph $th]
    } else {
        CloseHandle $th
        CloseHandle $ph
        return [list $pid $tid]
    }
}


#
# Get a handle to a process
proc twapi::get_process_handle {pid args} {
    array set opts [parseargs args {
        {access.arg process_query_information}
        {inherit.bool 0}
    }]
    return [OpenProcess [_access_rights_to_mask $opts(access)] $opts(inherit) $pid]
}

#
# Get a handle to a thread
proc twapi::get_thread_handle {tid args} {
    array set opts [parseargs args {
        {access.arg thread_query_information}
        {inherit.bool 0}
    }]
    return [OpenThread [_access_rights_to_mask $opts(access)] $opts(inherit) $tid]
}

#
# Suspend a thread
proc twapi::suspend_thread {tid} {
    set htid [OpenProcess $twapi::windefs(THREAD_SUSPEND_RESUME) 0 $tid]
    try {
        set status [SuspendThread $htid]
    } finally {
        CloseHandle $htid
    }
    return $status
}

#
# Resume a thread
proc twapi::resume_thread {tid} {
    set htid [OpenThread $twapi::windefs(THREAD_SUSPEND_RESUME) 0 $tid]
    try {
        set status [ResumeThread $htid]
    } finally {
        CloseHandle $htid
    }
    return $status
}


#
# Get the exit code for a process. Returns "" if still running.
proc twapi::get_process_exit_code {hpid} {
    set code [GetExitCodeProcess $hpid]
    return [expr {$code == 259 ? "" : $code}]
}


#
# Get the command line for a process
proc twapi::get_process_commandline {pid args} {

    if {[is_system_pid $pid] || [is_idle_pid $pid]} {
        return ""
    }

    array set opts [parseargs args {
        {noexist.arg "(no such process)"}
        {noaccess.arg "(unknown)"}
    }]

    try {
        # Assume max command line len is 1024 chars (2048 bytes)
        set max_len 2048
        set hgbl [GlobalAlloc 0 $max_len]
        set pgbl [GlobalLock $hgbl]
        try {
            set hpid [OpenProcess [expr {$twapi::windefs(PROCESS_QUERY_INFORMATION)
                                         | $twapi::windefs(PROCESS_VM_READ)}] \
                          0 \
                          $pid]
        } onerror {TWAPI_WIN32 87} {
            # Process does not exist
            return $opts(noexist)
        }
        
        # Get the address where the PEB is stored - see Nebbett
        set peb_addr [lindex [Twapi_NtQueryInformationProcessBasicInformation $hpid] 1]
        # Read the PEB as binary
        # The pointer to the process information block is the 5th longword
        ReadProcessMemory $hpid [expr {16+$peb_addr}] $pgbl 4
        
        # Convert this to an integer address
        if {![binary scan [Twapi_ReadMemoryBinary $pgbl 0 4] i info_addr]} {
            error "Could not get address of process information block"
        }
        # The pointer to the command line is stored at offset 68
        ReadProcessMemory $hpid [expr {$info_addr + 68}] $pgbl 4
        if {![binary scan [Twapi_ReadMemoryBinary $pgbl 0 4] i cmdline_addr]} {
            error "Could not get address of command line"
        }

        # Now read the command line itself. We do not know the length
        # so assume MAX_PATH (1024) chars (2048 bytes). However, this may
        # fail if the memory beyond the command line is not allocated in the
        # target process. So we have to check for this error and retry with
        # smaller read sizes
        while {$max_len > 128} {
            try {
                ReadProcessMemory $hpid $cmdline_addr $pgbl $max_len
                break
            } onerror {TWAPI_WIN32 299} {
                # Reduce read size
                set max_len [expr {$max_len / 2}]
            }
        }

        # OK, got something. It's in Unicode format, may not be null terminated
        # or may have multiple null terminated strings. THe command line
        # is the first string.
        set cmdline [encoding convertfrom unicode [Twapi_ReadMemoryBinary $pgbl 0 $max_len]]
        set null_offset [string first "\0" $cmdline]
        if {$null_offset >= 0} {
            set cmdline [string range $cmdline 0 [expr {$null_offset-1}]]
        }
        
    } onerror {TWAPI_WIN32 5} {
        # Access denied
        set cmdline $opts(noaccess)
    } finally {
        if {[info exists hpid]} {
            close_handles $hpid
        }
        if {[info exists hgbl]} {
            if {[info exists pgbl]} {
                # We had locked the memory
                GlobalUnlock $hgbl
            }
            GlobalFree $hgbl
        }
    }

    return $cmdline
}


#
# Get process parent - can return ""
proc twapi::get_process_parent {pid args} {
    array set opts [parseargs args {
        {noexist.arg "(no such process)"}
        {noaccess.arg "(unknown)"}
    }]

    if {[is_system_pid $pid] || [is_idle_pid $pid]} {
        return ""
    }

    try {
        set hpid [OpenProcess $twapi::windefs(PROCESS_QUERY_INFORMATION) 0 $pid]
        set parent [lindex [Twapi_NtQueryInformationProcessBasicInformation $hpid] 5]
        
    } onerror {TWAPI_WIN32 5} {
        set error noaccess
    } onerror {TWAPI_WIN32 87} {
        set error noexist
    } finally {
        if {[info exists hpid]} {
            close_handles $hpid
        }
    }

    # TBD - if above fails, try through Twapi_GetProcessList

    if {![info exists parent]} {
        # Try getting through pdh library
        set counters [get_perf_process_counter_paths $pid -parent]
        if {[llength counters]} {
            set vals [get_perf_values_from_metacounter_info $counters -interval 0]
            if {[llength $vals] > 2} {
                set parent [lindex $vals 2]
            }
        }
        if {![info exists parent]} {
            set parent $opts($error)
        }
    }

    return $parent
}

#
# Get the command line
proc twapi::get_command_line {} {
    return [GetCommandLineW]
}

#
# Parse the command line
proc twapi::get_command_line_args {cmdline} {
    # Special check for empty line. CommandLinetoArgv returns process
    # exe name in this case.
    if {[string length $cmdline] == 0} {
        return [list ]
    }
    return [CommandLineToArgv $cmdline]
}



# Return true if passed pid is system
proc twapi::is_system_pid {pid} {
    foreach {major minor} [get_os_version] break
    if {$major == 4 } {
        # NT 4
        set syspid 2
    } elseif {$major == 5 && $minor == 0} {
        # Win2K
        set syspid 8
    } else {
        # XP and Win2K3
        set syspid 4
    }

    # Redefine ourselves and call the redefinition
    proc ::twapi::is_system_pid pid "expr \$pid==$syspid"
    return [is_system_pid $pid]
}

# Return true if passed pid is of idle process
proc twapi::is_idle_pid {pid} {
    return [expr {$pid == 0}]
}


#
# Utility procedures
#


#
# Get the path of a process
proc twapi::_get_process_name_path_helper {pid {type name} args} {
    variable windefs

    array set opts [parseargs args {
        {noexist.arg "(no such process)"}
        {noaccess.arg "(unknown)"}
    }]

    if {![string is integer $pid]} {
        error "Invalid non-numeric pid $pid"
    }
    if {[is_system_pid $pid]} {
        return "System"
    }
    if {[is_idle_pid $pid]} {
        return "System Idle Process"
    }
    # OpenProcess masks off the bottom two bits thereby converting
    # an invalid pid to a real one. We do not want this except on
    # NT 4.0 where PID's can be any number
    if {($pid & 3) && [min_os_version 5]} {
        return $opts(noexist)
    }

    set privs [expr {$windefs(PROCESS_QUERY_INFORMATION) | $windefs(PROCESS_VM_READ)}]

    try {
        set hpid [OpenProcess $privs 0 $pid]
    } onerror {TWAPI_WIN32 87} {
        return $opts(noexist)
    } onerror {TWAPI_WIN32 5} {
        # Access denied
        # If it is the name we want, first try WTS and if that
        # fails try getting it from PDH (slowest)

        if {[string equal $type "name"]} {
            if {! [catch {WTSEnumerateProcesses NULL} wtslist]} {
                foreach wtselem $wtslist {
                    if {[kl_get $wtselem ProcessId] == $pid} {
                        return [kl_get $wtselem pProcessName]
                    }
                }
            }

            # That failed as well, try PDH
            set pdh_path [lindex [lindex [twapi::get_perf_process_counter_paths [list $pid] -pid] 0] 3]
            array set pdhinfo [parse_perf_counter_path $pdh_path]
            return $pdhinfo(instance)
        }                        
        return $opts(noaccess)
    }

    try {
        set module [lindex [EnumProcessModules $hpid] 0]
        if {[string equal $type "name"]} {
            set path [GetModuleBaseName $hpid $module]
        } else {
            set path [_normalize_path [GetModuleFileNameEx $hpid $module]]
        }
    } onerror {TWAPI_WIN32 5} {
        # Access denied
        # On win2k (and may be Win2k3), if the process has exited but some
        # app still has a handle to the process, the OpenProcess succeeds
        # but the EnumProcessModules call returns access denied. So
        # check for this case
        if {[min_os_version 5 0]} {
            # Try getting exit code. 259 means still running.
            # Anything else means process has terminated
            if {[GetExitCodeProcess $hpid] == 259} {
                return $opts(noaccess)
            } else {
                return $opts(noexist)
            }
        } else {
            # Rethrows original error - note try automatically beings these
            # into scope
            error $errorResult $errorInfo $errorCode
        }
    } finally {
        CloseHandle $hpid
    }
    return $path
}

#
# Return various information from a process token
proc twapi::_get_token_info {type id optlist} {
    array set opts [parseargs optlist {
        user
        groups
        primarygroup
        privileges
        logonsession
        {noexist.arg "(no such process)"}
        {noaccess.arg "(unknown)"}
    } -maxleftover 0]

    if {$type == "thread"} {
        set tok [open_thread_token -tid $id -access [list token_query]]
    } else {
        set tok [open_process_token -pid $id -access [list token_query]]
    }
    
    set result [list ]
    try {
        if {$opts(user)} {
            lappend result -user [get_token_user $tok -name]
        }
        if {$opts(groups)} {
            lappend result -groups [get_token_groups $tok -name]
        }
        if {$opts(primarygroup)} {
            lappend result -primarygroup [get_token_primary_group $tok -name]
        }
        if {$opts(privileges)} {
            lappend result -privileges [get_token_privileges $tok -all]
        }
        if {$opts(logonsession)} {
            array set stats [get_token_statistics $tok]
            lappend result -logonsession $stats(authluid)
        }
    } finally {
        close_token $tok
    }

    return $result
}

#
# Fill in arrays with result from WTSEnumerateProcesses if available
proc twapi::_get_wts_pids {v_sids v_names} {
    # Note this call is expected to fail on NT 4.0 without terminal server
    if {! [catch {WTSEnumerateProcesses NULL} wtslist]} {
        upvar $v_sids wtssids
        upvar $v_names wtsnames
        foreach wtselem $wtslist {
            set pid [kl_get $wtselem ProcessId]
            set wtssids($pid) [kl_get $wtselem pUserSid]
            set wtsnames($pid) [kl_get $wtselem pProcessName]
        }
    }
}
