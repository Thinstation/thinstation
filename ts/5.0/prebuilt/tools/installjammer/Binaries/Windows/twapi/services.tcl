#
# Copyright (c) 2003-2007, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

namespace eval twapi {
} 

# Locks the scm database and returns a handle to the lock
proc twapi::lock_scm_db {args} {
    variable windefs

    array set opts [parseargs args {system.arg database.arg} -nulldefault]

    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(SC_MANAGER_LOCK)]
    try {
        set lock [LockServiceDatabase $scm]
    } finally {
        CloseServiceHandle $scm
    }
    return $lock
}

# Unlocks the scm database
proc twapi::unlock_scm_db {lock} {
    UnlockServiceDatabase $lock
}

# Query the lock status of the scm database. Returns 1/0 depending on whether
# database is locked. $v_lockinfo will contain a two element list of
# {lockowner time_locked}
proc twapi::query_scm_db_lock_status {v_lockinfo args} {
    variable windefs

    upvar $v_lockinfo lockinfo

    array set opts [parseargs args {system.arg database.arg} -nulldefault]
    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(SC_MANAGER_QUERY_LOCK_STATUS)]
    try {
        array set lock_status [QueryServiceLockStatus $scm]
        set lockinfo [list $lock_status(lpLockOwner) $lock_status(dwLockDuration)]
    } finally {
        CloseServiceHandle $scm
    }

    return $lock_status(fIsLocked)
}


#
# Return 1/0 depending on whether the given service exists
# $name may be either the internal or display name
proc twapi::service_exists {name args} {
    variable windefs

    array set opts [parseargs args {system.arg database.arg} -nulldefault]
    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(STANDARD_RIGHTS_READ)]
 
    try {
        GetServiceKeyName $scm $name
        set exists 1
    } onerror {TWAPI_WIN32 1060} {
        # "no such service" error for internal name.
        # Try display name
        try {
            GetServiceDisplayName $scm $name
            set exists 1
        } onerror {TWAPI_WIN32 1060} {
            set exists 0
        }
    } finally {
        CloseServiceHandle $scm
    }

    return $exists
}


#
# Create a service of the specified name
proc twapi::create_service {name command args} {
    variable windefs

    array set opts [parseargs args {
        displayname.arg
        {servicetype.arg     win32_own_process {win32_own_process win32_share_process file_system_driver kernel_driver}}
        {interactive.bool    0}
        {starttype.arg       auto_start {auto_start boot_start demand_start disabled system}}
        {errorcontrol.arg    normal {ignore normal severe critical}}
        loadordergroup.arg
        dependencies.arg
        account.arg
        password.arg
        system.arg
        database.arg
    } -nulldefault]
    

    if {[string length $opts(displayname)] == 0} {
        set opts(displayname) $name
    }

    if {[string length $command] == 0} {
        error "The executable path must not be null when creating a service"
    }
    set opts(command) $command

    switch -exact -- $opts(servicetype) {
        file_system_driver -
        kernel_driver {
            if {$opts(interactive)} {
                error "Option -interactive cannot be specified when -servicetype is $opts(servicetype)."
            }
        }
        default {
            if {$opts(interactive) && [string length $opts(account)]} {
                error "Option -interactive cannot be specified with the -account option as interactive services must run under the LocalSystem account."
            }
            if {[string equal $opts(starttype) "boot_start"]
                || [string equal $opts(starttype) "system_start"]} {
                error "Option -starttype value must be one of auto_start, demand_start or disabled when -servicetype is '$opts(servicetype)'."
            }
        }
    }

    # Map keywords to integer values
    set opts(servicetype)  $windefs(SERVICE_[string toupper $opts(servicetype)])
    set opts(starttype)    $windefs(SERVICE_[string toupper $opts(starttype)])
    set opts(errorcontrol) $windefs(SERVICE_ERROR_[string toupper $opts(errorcontrol)])

    # If interactive, add the flag to the service type
    if {$opts(interactive)} {
        setbits opts(servicetype) $windefs(SERVICE_INTERACTIVE_PROCESS)
    }

    # Ignore password if username not specified
    if {[string length $opts(account)] == 0} {
        set opts(password) ""
    } else {
        # If domain/system not specified, tack on ".\" for local system
        if {[string first \\ $opts(account)] < 0} {
            set opts(account) ".\\$opts(account)"
        }
    }

    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(SC_MANAGER_CREATE_SERVICE)]
    try {
        set svch [CreateService \
                      $scm \
                      $name \
                      $opts(displayname) \
                      $windefs(SERVICE_ALL_ACCESS) \
                      $opts(servicetype) \
                      $opts(starttype) \
                      $opts(errorcontrol) \
                      $opts(command) \
                      $opts(loadordergroup) \
                      NULL \
                      $opts(dependencies) \
                      $opts(account) \
                      $opts(password)]
        
        CloseServiceHandle $svch
        
    } finally {
        CloseServiceHandle $scm
    }
    
    return
}


# Delete the given service
proc twapi::delete_service {name args} {
    variable windefs

    array set opts [parseargs args {system.arg database.arg} -nulldefault]
    set opts(scm_priv) DELETE
    set opts(svc_priv) DELETE
    set opts(proc)     twapi::DeleteService
    
    _service_fn_wrapper $name opts

    return
}


# Get the internal name of a service
proc twapi::get_service_internal_name {name args} {
    variable windefs

    array set opts [parseargs args {system.arg database.arg} -nulldefault]
    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(STANDARD_RIGHTS_READ)]


    try {
        if {[catch {GetServiceKeyName $scm $name} internal_name]} {
            # Maybe this is an internal name itself
            GetServiceDisplayName $scm $name; # Will throw an error if not internal name
            set internal_name $name
        }
    } finally {
        CloseServiceHandle $scm
    }

    return $internal_name
}

# Get the display name of a service
proc twapi::get_service_display_name {name args} {
    variable windefs

    array set opts [parseargs args {system.arg database.arg} -nulldefault]
    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(STANDARD_RIGHTS_READ)]


    try {
        if {[catch {GetServiceDisplayName $scm $name} display_name]} {
            # Maybe this is an display name itself
            GetServiceKeyName $scm $name; # Will throw an error if not display name
            set display_name $name
        }
    } finally {
        CloseServiceHandle $scm
    }

    return $display_name
}


# Start the specified service
proc twapi::start_service {name args} {
    variable windefs

    array set opts [parseargs args {
        system.arg
        database.arg
        params.arg
        wait.int 
    } -nulldefault]
    set opts(svc_priv) SERVICE_START
    set opts(proc)     twapi::StartService
    set opts(args)     [list $opts(params)]
    unset opts(params)

    try {
        _service_fn_wrapper $name opts
    } onerror {TWAPI_WIN32 1056} {
        # Error 1056 means service already running
    }

    return [wait {twapi::get_service_state $name -system $opts(system) -database $opts(database)} running $opts(wait)]
}


# Send a control code to the specified service
proc twapi::control_service {name code access finalstate args} {
    variable windefs

    array set opts [parseargs args {
        system.arg
        database.arg
        ignorecodes.arg
        wait.int
    } -nulldefault]
    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(STANDARD_RIGHTS_READ)]
    
    try {
        set svch [OpenService $scm $name $access]
    } finally {
        CloseServiceHandle $scm
    }

    SERVICE_STATUS svc_status
    try {
        ControlService $svch $code svc_status
    } onerror {TWAPI_WIN32} {
        if {[lsearch -exact -integer $opts(ignorecodes) [lindex $errorCode 1]] < 0} {
            #Not one of the error codes we can ignore. Rethrow the error
            error $errorResult $errorInfo $errorCode
        }
    } finally {
        svc_status -delete
        CloseServiceHandle $svch
    }

    if {[string length $finalstate]} {
        # Wait until service is in specified state
        return [wait {twapi::get_service_state $name -system $opts(system) -database $opts(database)} $finalstate $opts(wait)]
    } else {
        return 0
    }
}

proc twapi::stop_service {name args} {
    variable windefs
    eval [list control_service $name \
              $windefs(SERVICE_CONTROL_STOP) $windefs(SERVICE_STOP) stopped -ignorecodes 1062] $args
}

proc twapi::pause_service {name args} {
    variable windefs
    eval [list control_service $name \
              $windefs(SERVICE_CONTROL_PAUSE) \
              $windefs(SERVICE_PAUSE_CONTINUE) paused] $args
}

proc twapi::continue_service {name args} {
    variable windefs
    eval [list control_service $name \
              $windefs(SERVICE_CONTROL_CONTINUE) \
              $windefs(SERVICE_PAUSE_CONTINUE) running] $args
}

proc twapi::interrogate_service {name args} {
    variable windefs
    eval [list control_service $name \
              $windefs(SERVICE_CONTROL_INTERROGATE) \
              $windefs(SERVICE_INTERROGATE) ""] $args
    return
}


# Retrieve status information for a service
proc twapi::get_service_status {name args} {
    variable windefs

    array set opts [parseargs args {system.arg database.arg} -nulldefault]
    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(STANDARD_RIGHTS_READ)]

    try {
        set svch [OpenService $scm $name $windefs(SERVICE_QUERY_STATUS)]
    } finally {
        # Do not need SCM anymore
        CloseServiceHandle $scm
    }

    try {
        return [_format_SERVICE_STATUS_EX [QueryServiceStatusEx $svch 0]]
    } finally {
        CloseServiceHandle $svch
    }
}


# Get the state of the service
proc twapi::get_service_state {name args} {
    return [kl_get [eval [list get_service_status $name] $args] state]
}


# Get the current configuration for a service
proc twapi::get_service_configuration {name args} {
    variable windefs

    array set opts [parseargs args {
        system.arg
        database.arg
        all
        servicetype
        interactive
        errorcontrol
        starttype
        command
        loadordergroup
        account
        displayname
        dependencies
        description
        scm_handle.arg
    } -nulldefault]

    set opts(svc_priv) SERVICE_QUERY_CONFIG
    set opts(proc)     twapi::QueryServiceConfig
    array set svc_config [_service_fn_wrapper $name opts]

    # Get the service type info
    foreach {servicetype interactive} \
        [_map_servicetype_code $svc_config(dwServiceType)] break

    set result [list ]
    if {$opts(all) || $opts(servicetype)} {
        lappend result -servicetype $servicetype
    }
    if {$opts(all) || $opts(interactive)} {
        lappend result -interactive $interactive
    }
    if {$opts(all) || $opts(errorcontrol)} {
        lappend result -errorcontrol [_map_errorcontrol_code $svc_config(dwErrorControl)]
    }
    if {$opts(all) || $opts(starttype)} {
        lappend result -starttype [_map_starttype_code $svc_config(dwStartType)]
    }
    if {$opts(all) || $opts(command)} {
        lappend result -command $svc_config(lpBinaryPathName)
    }
    if {$opts(all) || $opts(loadordergroup)} {
        lappend result -loadordergroup $svc_config(lpLoadOrderGroup)
    }
    if {$opts(all) || $opts(account)} {
        lappend result -account $svc_config(lpServiceStartName)
    }
    if {$opts(all) || $opts(displayname)} {
        lappend result -displayname    $svc_config(lpDisplayName)
    }
    if {$opts(all) || $opts(dependencies)} {
        lappend result -dependencies $svc_config(lpDependencies)
    }
    if {$opts(all) || $opts(description)} {
        # TBD - replace with call to QueryServiceConfig2 when available
        if {[catch {
            registry get "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\$name" "Description"
        } desc]} {
            lappend result -description ""
        } else {
            lappend result -description $desc
        }
    }
    # Note currently we do not return svc_config(dwTagId)

    return $result
}

# Sets a service configuration
proc twapi::set_service_configuration {name args} {
    variable windefs

    # Get the current values - we will need these for validation
    # with the new values
    array set current [get_service_configuration $name -all]
    set current(-password) ""; # This is not returned by get_service_configuration

    # Remember which arguments were actually specified
    array set specified_args $args

    # Now parse arguments, filling in defaults
    array set opts [parseargs args {
        displayname.arg
        servicetype.arg
        interactive.bool
        starttype.arg
        errorcontrol.arg
        command.arg
        loadordergroup.arg
        dependencies.arg
        account.arg
        password.arg
        {system.arg ""}
        {database.arg ""}
    }]

    if {[info exists opts(account)] && ! [info exists opts(password)]} {
        error "Option -password must also be specified when -account is specified."
    }

    # Overwrite current configuration with specified options
    foreach opt {
        displayname
        servicetype
        interactive
        starttype
        errorcontrol
        command
        loadordergroup
        dependencies
        account
        password
    } {
        if {[info exists opts($opt)]} {
            set winparams($opt) $opts($opt)
        } else {
            set winparams($opt) $current(-$opt)
        }
    }

    # Validate the new configuration
    switch -exact -- $winparams(servicetype) {
        file_system_driver -
        kernel_driver {
            if {$winparams(interactive)} {
                error "Option -interactive cannot be specified when -servicetype is $winparams(servicetype)."
            }
        }
        default {
            if {$winparams(interactive) &&
                [string length $winparams(account)] &&
                [string compare -nocase $winparams(account) "LocalSystem"]
            } {
                error "Option -interactive cannot be specified with the -account option as interactive services must run under the LocalSystem account."
            }
            if {[string equal $winparams(starttype) "boot_start"]
                || [string equal $winparams(starttype) "system_start"]} {
                error "Option -starttype value must be one of auto_start, demand_start or disabled when -servicetype is '$winparams(servicetype)'."
            }
        }
    }
    
    # Map keywords to integer values
    set winparams(servicetype)  $windefs(SERVICE_[string toupper $winparams(servicetype)])
    set winparams(starttype)    $windefs(SERVICE_[string toupper $winparams(starttype)])
    set winparams(errorcontrol) $windefs(SERVICE_ERROR_[string toupper $winparams(errorcontrol)])

    # If interactive, add the flag to the service type
    if {$winparams(interactive)} {
        if {![info exists opts(servicetype)]} {
            set opts(servicetype) $winparams(servicetype)
        }
        setbits opts(servicetype) $windefs(SERVICE_INTERACTIVE_PROCESS)
        setbits winparams(servicetype) $opts(servicetype)
    }

    # If domain/system not specified, tack on ".\" for local system
    if {[string length $winparams(account)]} {
        if {[string first \\ $winparams(account)] < 0} {
            set winparams(account) ".\\$winparams(account)"
        }
    }

    # Now replace any options that were not specified with "no change"
    # tokens. Note -interactive is not listed here, since it is included
    # in servicetype at this point
    foreach opt {servicetype starttype errorcontrol} {
        if {![info exists opts($opt)]} {
            set winparams($opt) $windefs(SERVICE_NO_CHANGE)
        }
    }
    foreach opt {command loadordergroup dependencies account password displayname} {
        if {![info exists opts($opt)]} {
            set winparams($opt) $twapi::nullptr
        }
    }

    set opts(scm_priv) STANDARD_RIGHTS_READ
    set opts(svc_priv) SERVICE_CHANGE_CONFIG
    set opts(proc)     twapi::ChangeServiceConfig
    set opts(args) \
        [list \
             $winparams(servicetype) \
             $winparams(starttype) \
             $winparams(errorcontrol) \
             $winparams(command) \
             $winparams(loadordergroup) \
             NULL \
             $winparams(dependencies) \
             $winparams(account) \
             $winparams(password) \
             $winparams(displayname)]

    _service_fn_wrapper $name opts

    return
}


# Get status for the specified service types
proc twapi::get_multiple_service_status {args} {
    variable windefs

    set service_types [list \
                           kernel_driver \
                           file_system_driver \
                           adapter \
                           recognizer_driver \
                           win32_own_process \
                           win32_share_process]
    set switches [concat $service_types \
                      [list active inactive] \
                      [list system.arg database.arg]]
    array set opts [parseargs args $switches -nulldefault]

    set servicetype 0
    foreach type $service_types {
        if {$opts($type)} {
            set servicetype [expr { $servicetype
                                    | $windefs(SERVICE_[string toupper $type])
                                }]
        }
    }
    if {$servicetype == 0} {
        # No type specified, return all
        set servicetype [expr {$windefs(SERVICE_KERNEL_DRIVER)
                               | $windefs(SERVICE_FILE_SYSTEM_DRIVER)
                               | $windefs(SERVICE_ADAPTER)
                               | $windefs(SERVICE_RECOGNIZER_DRIVER)
                               | $windefs(SERVICE_WIN32_OWN_PROCESS)
                               | $windefs(SERVICE_WIN32_SHARE_PROCESS)}]
    }

    set servicestate 0
    if {$opts(active)} {
        set servicestate [expr {$servicestate |
                                $windefs(SERVICE_ACTIVE)}]
    }
    if {$opts(inactive)} {
        set servicestate [expr {$servicestate |
                                $windefs(SERVICE_INACTIVE)}]
    }
    if {$servicestate == 0} {
        # No state specified, include all
        set servicestate $windefs(SERVICE_STATE_ALL)
    }
    
    set servicelist [list ]

    set scm [OpenSCManager $opts(system) $opts(database) \
                 $windefs(SC_MANAGER_ENUMERATE_SERVICE)]
    try {
        if {[min_os_version 5]} {
            set status_recs [EnumServicesStatusEx $scm 0 $servicetype $servicestate __null__]
        } else {
            set status_recs [EnumServicesStatus $scm $servicetype $servicestate]
        }
    } finally {
        CloseServiceHandle $scm
    }

    foreach status_rec $status_recs {
        lappend servicelist [_format_status_record $status_rec]
    }

    return $servicelist
}


# Get status for the dependents of the specified service
proc twapi::get_dependent_service_status {name args} {
    variable windefs

    array set opts [parseargs args \
                        [list active inactive system.arg database.arg] \
                        -nulldefault]

    set servicestate 0
    if {$opts(active)} {
        set servicestate [expr {$servicestate |
                                $windefs(SERVICE_ACTIVE)}]
    }
    if {$opts(inactive)} {
        set servicestate [expr {$servicestate |
                                $windefs(SERVICE_INACTIVE)}]
    }
    if {$servicestate == 0} {
        # No state specified, include all
        set servicestate $windefs(SERVICE_STATE_ALL)
    }
    
    set opts(svc_priv) SERVICE_ENUMERATE_DEPENDENTS
    set opts(proc)     twapi::EnumDependentServices
    set opts(args)     [list $servicestate]
    set status_recs [_service_fn_wrapper $name opts]

    set servicelist [list ]
    foreach status_rec $status_recs {
        lappend servicelist [_format_status_record $status_rec]
    }
        
    return $servicelist
}


# Map an integer service type code into a list consisting of 
# {SERVICETYPESYMBOL BOOLEAN}. If there is not symbolic service type
# for the service, just the integer code is returned. The BOOLEAN
# is 1/0 depending on whether the service type code is interactive
proc twapi::_map_servicetype_code {servicetype} {
    variable windefs

    set interactive [expr {($servicetype & $windefs(SERVICE_INTERACTIVE_PROCESS)) != 0}]
    set servicetype [expr {$servicetype & (~$windefs(SERVICE_INTERACTIVE_PROCESS))}]

    # Map service type integer code to symbol, *if possible*
    set service_syms {
        win32_own_process win32_share_process kernel_driver
        file_system_driver adapter recognizer_driver
    }
    set servicetype [code_to_symbol $servicetype $service_syms]
    
    return [list $servicetype $interactive]
}

# Map a start type code into a symbol. Returns the integer code if
# no mapping possible
proc twapi::_map_starttype_code {code} {
    return [code_to_symbol \
                $code {auto_start boot_start demand_start disabled system_start}]
}


# Map a error control code into a symbol. Returns the integer code if
# no mapping possible
proc twapi::_map_errorcontrol_code {code} {
    return [code_to_symbol \
                $code {ignore normal severe critical} "SERVICE_ERROR_"]
}


# Map a service state code to a symbol 
proc twapi::_map_state_code {code} {
    # Map state integer code to symbol *if possible*
    set states {
        stopped start_pending stop_pending running continue_pending
        pause_pending paused
    }
    set state [code_to_symbol $code $states]
}


#
# Format a service status list record 
# {dwServiceType 1 dwCurrentState 2....}
# gets formatted as 
# {-servicetype win32_own_process -state running ...}
proc twapi::_format_status_record {status_rec} {

    set retval [_format_SERVICE_STATUS_EX $status_rec]
    if {[kl_vget $status_rec lpServiceName name]} {
        lappend retval name $name
    }
    if {[kl_vget $status_rec lpDisplayName displayname]} {
        lappend retval displayname $displayname
    }
    return $retval
}

#
# Format an extended service status record
proc twapi::_format_SERVICE_STATUS_EX {svc_status} {
    # Get the service type and strip off the interactive flag
    foreach {servicetype interactive} \
        [_map_servicetype_code [kl_get $svc_status dwServiceType]] break

    # Map state integer code to symbol *if possible*
    set state [_map_state_code [kl_get $svc_status dwCurrentState]]

    # Pid if available
    if {![kl_vget $svc_status dwProcessId pid]} {
        # There was no dwProcessId field. NT 4
        if {$state == "stopped"} {
            set pid 0
        } else {
            set pid -1
        }
    }

    set attrs [list ]
    if {[kl_vget $svc_status dwServiceFlags flags] &&
        ($flags & 1)} {
        lappend attrs systemprocess
    }
    
    return [list \
                servicetype  $servicetype \
                interactive  $interactive \
                state        $state \
                controls_accepted [kl_get $svc_status dwControlsAccepted] \
                exitcode     [kl_get $svc_status dwWin32ExitCode] \
                service_code [kl_get $svc_status dwServiceSpecificExitCode] \
                checkpoint   [kl_get $svc_status dwCheckPoint] \
                wait_hint    [kl_get $svc_status dwWaitHint] \
                pid          $pid \
                attrs        $attrs]
}


# Maps an integer code to a symbolic name if possible, else returns the
# integer code
proc twapi::code_to_symbol {code symlist {prefix "SERVICE_"}} {
    variable windefs
    foreach sym $symlist {
        if {$code == $windefs(${prefix}[string toupper $sym])} {
            return $sym
        }
    }
    return $code
}


#
# Standard template for calling a service function. v_opts should refer
# to an array with the following elements:
# opts(system) - target system. Must be specified
# opts(database) - target database. Must be specified
# opts(scm_priv) - requested privilege when opening SCM. STANDARD_RIGHTS_READ
#   is used if unspecified. Not used if scm_handle is specified
# opts(scm_handle) - handle to service control manager. Optional
# opts(svc_priv) - requested privilege when opening service. Must be present
# opts(proc) - proc/function to call. The first arg is the service handle
# opts(args) - additional arguments to pass to the function.
#   Empty if unspecified
# 
proc twapi::_service_fn_wrapper {name v_opts} {
    variable windefs
    upvar $v_opts opts

    # Use STANDARD_RIGHTS_READ for SCM if not specified
    set scm_priv [expr {[info exists opts(scm_priv)] ? $opts(scm_priv) : "STANDARD_RIGHTS_READ"}]

    if {[info exists opts(scm_handle)] &&
        $opts(scm_handle) ne ""} {
        set scm $opts(scm_handle)
    } else {
        set scm [OpenSCManager $opts(system) $opts(database) \
                     $windefs($scm_priv)]
    }
    try {
        set svch [OpenService $scm $name $windefs($opts(svc_priv))]
    } finally {
        # No need for scm handle anymore. Close it unless it was
        # passed to us
        if {(![info exists opts(scm_handle)]) ||
            ($opts(scm_handle) eq "")} {
            CloseServiceHandle $scm
        }
    }

    set proc_args [expr {[info exists opts(args)] ? $opts(args) : ""}]
    try {
        set results [eval [list $opts(proc) $svch] $proc_args]
    } finally {
        CloseServiceHandle $svch
    }
    
    return $results
}


