#
# Copyright (c) 2003, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

# TBD - allow SID and account name to be used interchangeably in various
# functions
# TBD - ditto for LUID v/s privilege names

namespace eval twapi {
    # Map privilege level mnemonics to priv level
    array set priv_level_map {guest 0 user 1 admin 2}

    # Map of Sid integer type to Sid type name
    array set sid_type_names {
        1 user 
        2 group
        3 domain 
        4 alias 
        5 wellknowngroup
        6 deletedaccount
        7 invalid
        8 unknown
        9 computer
    }

    # Well known group to SID mapping
    array set well_known_sids {
        nullauthority     S-1-0
        nobody            S-1-0-0
        worldauthority    S-1-1
        everyone          S-1-1-0
        localauthority    S-1-2
        creatorauthority  S-1-3
        creatorowner      S-1-3-0
        creatorgroup      S-1-3-1
        creatorownerserver  S-1-3-2
        creatorgroupserver  S-1-3-3
        ntauthority       S-1-5
        dialup            S-1-5-1
        network           S-1-5-2
        batch             S-1-5-3
        interactive       S-1-5-4
        service           S-1-5-6
        anonymouslogon    S-1-5-7
        proxy             S-1-5-8
        serverlogon       S-1-5-9
        authenticateduser S-1-5-11
        terminalserver    S-1-5-13
        localsystem       S-1-5-18
        localservice      S-1-5-19
        networkservice    S-1-5-20
    }

    # Built-in accounts
    # TBD - see http://support.microsoft.com/?kbid=243330 for more built-ins
    array set builtin_account_sids {
        administrators  S-1-5-32-544
        users           S-1-5-32-545
        guests          S-1-5-32-546
        "power users"   S-1-5-32-547
    }
}

#
# Helper for lookup_account_name{sid,name}
proc twapi::_lookup_account {func account args} {
    if {$func == "LookupAccountSid"} {
        set lookup name
        # If we are mapping a SID to a name, check if it is the logon SID
        # LookupAccountSid returns an error for this SID
        if {[is_valid_sid_syntax $account] &&
            [string match -nocase "S-1-5-5-*" $account]} {
            set name "Logon SID"
            set domain "NT AUTHORITY"
            set type "logonid"
        }
    } else {
        set lookup sid
    }
    array set opts [parseargs args \
                        [list all \
                             $lookup \
                             domain \
                             type \
                             [list system.arg ""]\
                            ]]


    # Lookup the info if have not already hardcoded results
    if {![info exists domain]} {
        foreach "$lookup domain type" [$func $opts(system) $account] break
    }

    set result [list ]
    if {$opts(all) || $opts(domain)} {
        lappend result -domain $domain
    }
    if {$opts(all) || $opts(type)} {
        lappend result -type $twapi::sid_type_names($type)
    }

    if {$opts(all) || $opts($lookup)} {
        lappend result -$lookup [set $lookup]
    }

    # If no options specified, only return the sid/name
    if {[llength $result] == 0} {
        return [set $lookup]
    }

    return $result
}

# Returns the sid, domain and type for an account
proc twapi::lookup_account_name {name args} {
    return [eval [list _lookup_account LookupAccountName $name] $args]
}


# Returns the name, domain and type for an account
proc twapi::lookup_account_sid {sid args} {
    return [eval [list _lookup_account LookupAccountSid $sid] $args]
}

#
# Returns the sid for a account - may be given as a SID or name
proc twapi::map_account_to_sid {account args} {
    array set opts [parseargs args {system.arg} -nulldefault]

    # Treat empty account as null SID (self)
    if {[string length $account] == ""} {
        return ""
    }

    if {[is_valid_sid_syntax $account]} {
        return $account
    } else {
        return [lookup_account_name $account -system $opts(system)]
    }
}


#
# Returns the name for a account - may be given as a SID or name
proc twapi::map_account_to_name {account args} {
    array set opts [parseargs args {system.arg} -nulldefault]

    if {[is_valid_sid_syntax $account]} {
        return [lookup_account_sid $account -system $opts(system)]
    } else {
        # Verify whether a valid account by mapping to an sid
        if {[catch {map_account_to_sid $account -system $opts(system)}]} {
            # As a special case, change LocalSystem to SYSTEM. Some Windows
            # API's (such as services) return LocalSystem which cannot be
            # resolved by the security functions. This name is really the
            # same a the built-in SYSTEM
            if {$account == "LocalSystem"} {
                return "SYSTEM"
            }
            error "Unknown account '$account'"
        } 
        return $account
    }
}

#
# Return the user account for the current process
proc twapi::get_current_user {{format ""}} {
    set user [GetUserName]
    if {$format == ""} {
        return $user
    }
    if {$format == "-sid"} {
        return [map_account_to_sid $user]
    }
    error "Unknown option '$format'"
}

#
# Verify that the given sid is valid. This is purely a syntactic check
proc twapi::is_valid_sid_syntax sid {
    try {
        set result [IsValidSid $sid]
    } onerror {TWAPI_WIN32 1337} {
        set result 0
    }

    return $result
}

#
# Returns token for the process with pid $pid
proc twapi::open_process_token {args} {
    variable windefs

    array set opts [parseargs args {
        pid.int
        {access.arg token_query}
    } -maxleftover 0]

    set access [_access_rights_to_mask $opts(access)]

    # If "Win2K all access" specified, modify for NT 4.0 else we get an error
    if {($access == $windefs(TOKEN_ALL_ACCESS_WIN2K))
        && ([lindex [get_os_version] 0] == 4)} {
        set access $windefs(TOKEN_ALL_ACCESS_WINNT)
    }

    # Get a handle for the process
    if {[info exists opts(pid)]} {
        set ph [OpenProcess $windefs(PROCESS_QUERY_INFORMATION) 0 $opts(pid)]
    } else {
        variable my_process_handle
        set ph $my_process_handle
    }
    try {
        # Get a token for the process
        set ptok [OpenProcessToken $ph $access]
    } finally {
        # Close handle only if we did an OpenProcess
        if {[info exists opts(pid)]} {
            CloseHandle $ph
        }
    }

    return $ptok
}


#
# Returns token for the thread with tid $tid. If $tid is "", current thread
# is assumed
proc twapi::open_thread_token {args} {
    variable windefs

    array set opts [parseargs args {
        tid.int
        {access.arg token_query}
        {self.bool  false}
    } -maxleftover 0]

    set access [_access_rights_to_mask $opts(access)]

    # If "Win2K all access" specified, modify for NT 4.0 else we get an error
    if {($access == $windefs(TOKEN_ALL_ACCESS_WIN2K))
        && ([lindex [get_os_version] 0] == 4)} {
        set access $windefs(TOKEN_ALL_ACCESS_WINNT)
    }

    # Get a handle for the thread
    if {[info exists opts(tid)]} {
        set th [OpenThread $windefs(THREAD_QUERY_INFORMATION) 0 $opts(tid)]
    } else {
        set th [GetCurrentThread]
    }
    try {
        # Get a token for the process
        set ttok [OpenThreadToken $th $access $opts(self)]
    } finally {
        # Close handle only if we did an OpenProcess
        if {[info exists opts(tid)]} {
            CloseHandle $th
        }
    }

    return $ttok
}

#
# Close a token
proc twapi::close_token {tok} {
    CloseHandle $tok
}

#
# Get the user account associated with a token
proc twapi::get_token_user {tok args} {
    array set opts [parseargs args [list name]]
    set user [lindex [GetTokenInformation $tok $twapi::windefs(TokenUser)] 0]
    if {$opts(name)} {
        set user [lookup_account_sid $user]
    }
    return $user
}

#
# Get the groups associated with a token
proc twapi::get_token_groups {tok args} {
    array set opts [parseargs args [list name] -maxleftover 0]

    set groups [list ]
    foreach {group} [GetTokenInformation $tok $twapi::windefs(TokenGroups)] {
        set group [lindex $group 0]
        if {$opts(name)} {
            set group [lookup_account_sid $group]
        }
        lappend groups $group
    }

    return $groups
}

#
# Get the groups associated with a token along with their attributes
# These are returned as a flat list of the form "sid attrlist sid attrlist..."
# where the attrlist is a list of attributes
proc twapi::get_token_group_sids_and_attrs {tok} {
    variable windefs 

    set sids_and_attrs [list ]
    foreach {group} [GetTokenInformation $tok $windefs(TokenGroups)] {
        foreach {sid attr} $group break
        set attr_list {enabled enabled_by_default logon_id
            mandatory owner resource use_for_deny_only}
        lappend sids_and_attrs $sid [_map_token_attr $attr $attr_list SE_GROUP]
    }

    return $sids_and_attrs
}

# Get list of privileges that are currently enabled for the token
# If -all is specified, returns a list {enabled_list disabled_list}
proc twapi::get_token_privileges {tok args} {
    variable windefs

    set all [expr {[lsearch -exact $args -all] >= 0}]

    set enabled_privs [list ]
    set disabled_privs [list ]
    foreach {item} [GetTokenInformation $tok $windefs(TokenPrivileges)] {
        set priv [map_luid_to_privilege [lindex $item 0] -mapunknown]
        if {[lindex $item 1] & $windefs(SE_PRIVILEGE_ENABLED)} {
            lappend enabled_privs $priv
        } else {
            lappend disabled_privs $priv
        }
    }

    if {$all} {
        return [list $enabled_privs $disabled_privs]
    } else {
        return $enabled_privs
    }
}

#
# Return true if the token has the given privilege
proc twapi::check_enabled_privileges {tok privlist args} {
    set all_required [expr {[lsearch -exact $args "-any"] < 0}]

    if {0} {
        We now call the PrivilegeCheck instead. Not sure it matters
        This code also does not handle -any option
        foreach priv $privlist {
            if {[expr {
                       [lsearch -exact [get_token_privileges $tok] $priv] < 0
                   }]} {
                return 0
            }
        }
        return 1
    } else {
        set luid_attr_list [list ]
        foreach priv $privlist {
            lappend luid_attr_list [list [map_privilege_to_luid $priv] 0]
        }
        return [Twapi_PrivilegeCheck $tok $luid_attr_list $all_required]
    }
}


#
# Enable specified privileges. Returns "" if the given privileges were
# already enabled, else returns the privileges that were modified
proc twapi::enable_privileges {privlist} {
    variable my_process_handle

    # Get our process token
    set tok [OpenProcessToken $my_process_handle 0x28]; # QUERY + ADJUST_PRIVS
    try {
        return [enable_token_privileges $tok $privlist]
    } finally {
        close_token $tok
    }
}


#
# Disable specified privileges. Returns "" if the given privileges were
# already enabled, else returns the privileges that were modified
proc twapi::disable_privileges {privlist} {
    variable my_process_handle

    # Get our process token
    set tok [OpenProcessToken $my_process_handle 0x28]; # QUERY + ADJUST_PRIVS
    try {
        return [disable_token_privileges $tok $privlist]
    } finally {
        close_token $tok
    }
}


#
# Execute the given script with the specified privileges.
# After the script completes, the original privileges are restored
proc twapi::eval_with_privileges {script privs args} {
    array set opts [parseargs args {besteffort} -maxleftover 0]

    if {[catch {enable_privileges $privs} privs_to_disable]} {
        if {! $opts(besteffort)} {
            return -code error -errorinfo $::errorInfo \
                -errorcode $::errorCode $privs_to_disable
        }
        set privs_to_disable [list ]
    }

    set code [catch {uplevel $script} result]
    switch $code {
        0 {
            disable_privileges $privs_to_disable
            return $result
        }
        1 {
            # Save error info before calling disable_privileges
            set erinfo $::errorInfo
            set ercode $::errorCode
            disable_privileges $privs_to_disable
            return -code error -errorinfo $::errorInfo \
                -errorcode $::errorCode $result
        }
        default {
            disable_privileges $privs_to_disable
            return -code $code $result
        }
    }
}


# Get the privilege associated with a token and their attributes
proc twapi::get_token_privileges_and_attrs {tok} {
    set privs_and_attrs [list ]
    foreach priv [GetTokenInformation $tok $twapi::windefs(TokenPrivileges)] {
        foreach {luid attr} $priv break
        set attr_list {enabled enabled_by_default used_for_access}
        lappend privs_and_attrs [map_luid_to_privilege $luid -mapunknown] \
            [_map_token_attr $attr $attr_list SE_PRIVILEGE]
    }

    return $privs_and_attrs

}


#
# Get the sid that will be used as the owner for objects created using this
# token. Returns name instead of sid if -name options specified
proc twapi::get_token_owner {tok args} {
    return [ _get_token_sid_field $tok TokenOwner $args]
}


#
# Get the sid that will be used as the primary group for objects created using
# this token. Returns name instead of sid if -name options specified
proc twapi::get_token_primary_group {tok args} {
    return [ _get_token_sid_field $tok TokenPrimaryGroup $args]
}


#
# Return the source of an access token
proc twapi::get_token_source {tok} {
    return [GetTokenInformation $tok $twapi::windefs(TokenSource)]
}


#
# Return the token type of an access token
proc twapi::get_token_type {tok} {
    if {[GetTokenInformation $tok $twapi::windefs(TokenType)]} {
        return "primary"
    } else {
        return "impersonation"
    }
}

#
# Return the token type of an access token
proc twapi::get_token_impersonation_level {tok} {
    return [_map_impersonation_level \
                [GetTokenInformation $tok \
                     $twapi::windefs(TokenImpersonationLevel)]]
}

#
# Return token statistics
proc twapi::get_token_statistics {tok} {
    array set stats {}
    set labels {luid authluid expiration type impersonationlevel
        dynamiccharged dynamicavailable groupcount
        privilegecount modificationluid}
    set statinfo [GetTokenInformation $tok $twapi::windefs(TokenStatistics)]
    foreach label $labels val $statinfo {
        set stats($label) $val
    }
    set stats(type) [expr {$stats(type) == 1 ? "primary" : "impersonation"}]
    set stats(impersonationlevel) [_map_impersonation_level $stats(impersonationlevel)]

    return [array get stats]
}


#
# Enable the privilege state of a token. Generates an error if
# the specified privileges do not exist in the token (either
# disabled or enabled), or cannot be adjusted
proc twapi::enable_token_privileges {tok privs} {
    variable windefs

    set luid_attrs [list]
    foreach priv $privs {
        lappend luid_attrs [list [map_privilege_to_luid $priv] $windefs(SE_PRIVILEGE_ENABLED)]
    }

    set privs [list ]
    foreach {item} [Twapi_AdjustTokenPrivileges $tok 0 $luid_attrs] {
        lappend privs [map_luid_to_privilege [lindex $item 0] -mapunknown]
    }
    return $privs

    

}

#
# Disable the privilege state of a token. Generates an error if
# the specified privileges do not exist in the token (either
# disabled or enabled), or cannot be adjusted
proc twapi::disable_token_privileges {tok privs} {
    set luid_attrs [list]
    foreach priv $privs {
        lappend luid_attrs [list [map_privilege_to_luid $priv] 0]
    }

    set privs [list ]
    foreach {item} [Twapi_AdjustTokenPrivileges $tok 0 $luid_attrs] {
        lappend privs [map_luid_to_privilege [lindex $item 0] -mapunknown]
    }
    return $privs
}

#
# Disable all privs in a token
proc twapi::disable_all_token_privileges {tok} {
    set privs [list ]
    foreach {item} [Twapi_AdjustTokenPrivileges $tok 1 [list ]] {
        lappend privs [map_luid_to_privilege [lindex $item 0] -mapunknown]
    }
    return $privs
}


#
# Get list of users on a system
proc twapi::get_users {args} {
    array set opts [parseargs args {system.arg} -nulldefault]
    return [Twapi_NetUserEnum $opts(system) 0]
}

#
# Add a new user account
proc twapi::new_user {username args} {
    

    array set opts [parseargs args [list \
                                        system.arg \
                                        password.arg \
                                        comment.arg \
                                        [list priv.arg "user" [array names twapi::priv_level_map]] \
                                        home_dir.arg \
                                        script_path.arg \
                                       ] \
                        -nulldefault]

    # NetUserAdd requires the $priv level to be 1 (USER). We change it below
    # using the NetUserSetInfo call
    NetUserAdd $opts(system) $username $opts(password) 1 \
        $opts(home_dir) $opts(comment) 0 $opts(script_path)

    try {
        set_user_priv_level $username $opts(priv) -system $opts(system)
    } onerror {} {
        # Remove the previously created user account
        set ecode $errorCode
        set einfo $errorInfo
        catch {delete_user $username -system $opts(system)}
        error $errorResult $einfo $ecode
    }
}


#
# Delete a user account
proc twapi::delete_user {username args} {
    eval set [parseargs args {system.arg} -nulldefault]

    # Remove the user from the LSA rights database.
    _delete_rights $username $system

    NetUserDel $system $username
}


#
# Define various functions to set various user account fields
foreach field {name password home_dir comment script_path full_name country_code profile home_dir_drive} {
    proc twapi::set_user_$field {username fieldval args} "
        array set opts \[parseargs args {
            system.arg
        } -nulldefault \]
        Twapi_NetUserSetInfo_$field \$opts(system) \$username \$fieldval"
}

#
# Set user privilege level
proc twapi::set_user_priv_level {username priv_level args} {
    eval set [parseargs args {system.arg} -nulldefault]

    if {0} {
        # FOr some reason NetUserSetInfo cannot change priv level
        # Tried it separately with a simple C program. So this code
        # is commented out and we use group membership to achieve
        # the desired result
        if {![info exists twapi::priv_level_map($priv_level)]} {
            error "Invalid privilege level value '$priv_level' specified. Must be one of [join [array names twapi::priv_level_map] ,]"
        }
        set priv $twapi::priv_level_map($priv_level)

        Twapi_NetUserSetInfo_priv $system $username $priv
    } else {
        # Don't hardcode group names - reverse map SID's instead for 
        # non-English systems. Also note that since
        # we might be lowering privilege level, we have to also
        # remove from higher privileged groups
        variable builtin_account_sids
        switch -exact -- $priv_level {
            guest {
                set outgroups {administrators users}
                set ingroup guests
            }
            user  {
                set outgroups {administrators}
                set ingroup users
            }
            admin {
                set outgroups {}
                set ingroup administrators
            }
            default {error "Invalid privilege level '$priv_level'. Must be one of 'guest', 'user' or 'admin'"}
        }
        # Remove from higher priv groups
        foreach outgroup $outgroups {
            # Get the potentially localized name of the group
            set group [lookup_account_sid $builtin_account_sids($outgroup)]
            # Catch since may not be member of that group
            catch {remove_member_from_local_group $group $username}
        }

        # Get the potentially localized name of the group to be added
        set group [lookup_account_sid $builtin_account_sids($ingroup)]
        add_member_to_local_group $group $username
    }
}

#
# Set account expiry time
proc twapi::set_user_expiration {username time args} {
    eval set [parseargs args {system.arg} -nulldefault]

    if {[string equal $time "never"]} {
        set time -1
    } else {
        set time [clock scan $time]
    }

    Twapi_NetUserSetInfo_acct_expires $system $username $time
}

#
# Unlock a user account
proc twapi::unlock_user {username args} {
    eval [list _change_usri3_flags $username $twapi::windefs(UF_LOCKOUT) 0] $args
}

#
# Enable a user account
proc twapi::enable_user {username args} {
    eval [list _change_usri3_flags $username $twapi::windefs(UF_ACCOUNTDISABLE) 0] $args
}

#
# Disable a user account
proc twapi::disable_user {username args} {
    variable windefs
    eval [list _change_usri3_flags $username $windefs(UF_ACCOUNTDISABLE) $windefs(UF_ACCOUNTDISABLE)] $args
}



#
# Return the specified fields for a user account
proc twapi::get_user_account_info {account args} {
    variable windefs

    # Define each option, the corresponding field, and the 
    # information level at which it is returned
    array set fields {
        comment {usri3_comment 1}
        password_expired {usri3_password_expired 3}
        full_name {usri3_full_name 2}
        parms {usri3_parms 2}
        units_per_week {usri3_units_per_week 2}
        primary_group_id {usri3_primary_group_id 3}
        status {usri3_flags 1}
        logon_server {usri3_logon_server 2}
        country_code {usri3_country_code 2}
        home_dir {usri3_home_dir 1}
        password_age {usri3_password_age 1}
        home_dir_drive {usri3_home_dir_drive 3}
        num_logons {usri3_num_logons 2}
        acct_expires {usri3_acct_expires 2}
        last_logon {usri3_last_logon 2}
        user_id {usri3_user_id 3}
        usr_comment {usri3_usr_comment 2}
        bad_pw_count {usri3_bad_pw_count 2}
        code_page {usri3_code_page 2}
        logon_hours {usri3_logon_hours 2}
        workstations {usri3_workstations 2}
        last_logoff {usri3_last_logoff 2}
        name {usri3_name 0}
        script_path {usri3_script_path 1}
        priv {usri3_priv 1}
        profile {usri3_profile 3}
        max_storage {usri3_max_storage 2}
    }
    # Left out - auth_flags {usri3_auth_flags 2}
    # Left out (always returned as NULL) - password {usri3_password 1}


    array set opts [parseargs args \
                        [concat [array names fields] \
                             [list sid local_groups global_groups system.arg all]] \
                       -nulldefault]

    if {$opts(all)} {
        foreach field [array names fields] {
            set opts($field) 1
        }
        set opts(local_groups) 1
        set opts(global_groups) 1
        set opts(sid) 1
    }

    # Based on specified fields, figure out what level info to ask for
    set level 0
    foreach {field fielddata} [array get fields] {
        if {[lindex $fielddata 1] > $level} {
            set level [lindex $fielddata 1]
        }
    }
    
    array set data [NetUserGetInfo $opts(system) $account $level]

    # Extract the requested data
    array set result [list ]
    foreach {field fielddata} [array get fields] {
        if {$opts($field)} {
            set result($field) $data([lindex $fielddata 0])
        }
    }

    # Map internal values to more friendly formats
    if {$opts(status)} {
        if {$result(status) & $windefs(UF_ACCOUNTDISABLE)} {
            set result(status) "disabled"
        } elseif {$result(status) & $windefs(UF_LOCKOUT)} {
            set result(status) "locked"
        } else {
            set result(status) "enabled"
        }
    }

    if {[info exists result(logon_hours)]} {
        binary scan $result(logon_hours) b* result(logon_hours)
    }

    foreach time_field {acct_expires last_logon last_logoff} {
        if {[info exists result($time_field)]} {
            if {$result($time_field) == -1} {
                set result($time_field) "never"
            } elseif {$result($time_field) == 0} {
                set result($time_field) "unknown"
            } else {
                set result($time_field) [clock format $result($time_field) -gmt 1]
            }
        }
    }
    
    if {[info exists result(priv)]} {
        switch -exact -- [expr {$result(priv) & 3}] {
            0 { set result(priv) "guest" }
            1 { set result(priv) "user" }
            2 { set result(priv) "admin" }
        }
    }

    if {$opts(local_groups)} {
        set result(local_groups) [NetUserGetLocalGroups $opts(system) $account 0]
    }

    if {$opts(global_groups)} {
        set result(global_groups) [NetUserGetGroups $opts(system) $account]
    }

    if {$opts(sid)} {
        set result(sid) [lookup_account_name $account]
    }

    return [get_array_as_options result]
}

proc twapi::get_user_local_groups_recursive {account args} {
    array set opts [parseargs args {
        system.arg
    } -nulldefault -maxleftover 0]

    return [NetUserGetLocalGroups $opts(system) [map_account_to_name $account] 1]
}


#
# Set the specified fields for a user account
proc twapi::set_user_account_info {account args} {
    variable windefs

    set notspecified "3kjafnq2or2034r12"; # Some junk

    # Define each option, the corresponding field, and the 
    # information level at which it is returned
    array set opts [parseargs args {
        {system.arg ""}
        comment.arg
        full_name.arg
        country_code.arg
        home_dir.arg
        home_dir.arg
        acct_expires.arg
        name.arg
        script_path.arg
        priv.arg
        profile.arg
    }]

    if {[info exists opts(comment)]} {
        set_user_comment $account $opts(comment) -system $opts(system)
    }

    if {[info exists opts(full_name)]} {
        set_user_full_name $account $opts(full_name) -system $opts(system)
    }

    if {[info exists opts(country_code)]} {
        set_user_country_code $account $opts(country_code) -system $opts(system)
    }

    if {[info exists opts(home_dir)]} {
        set_user_home_dir $account $opts(home_dir) -system $opts(system)
    }

    if {[info exists opts(home_dir_drive)]} {
        set_user_home_dir_drive $account $opts(home_dir_drive) -system $opts(system)
    }

    if {[info exists opts(acct_expires)]} {
        set_user_expiration $account $opts(acct_expires) -system $opts(system)
    }

    if {[info exists opts(name)]} {
        set_user_name $account $opts(name) -system $opts(system)
    }

    if {[info exists opts(script_path)]} {
        set_user_script_path $account $opts(script_path) -system $opts(system)
    }

    if {[info exists opts(priv)]} {
        set_user_priv_level $account $opts(priv) -system $opts(system)
    }

    if {[info exists opts(profile)]} {
        set_user_profile $account $opts(profile) -system $opts(system)
    }
}
                    

proc twapi::get_global_group_info {name args} {
    array set opts [parseargs args {
        {system.arg ""}
        comment
        name
        members
        sid
        all
    } -maxleftover 0]

    set result [list ]
    if {$opts(all) || $opts(sid)} {
        lappend result -sid [lookup_account_name $name -system $opts(system)]
    }
    if {$opts(all) || $opts(comment) || $opts(name)} {
        array set info [NetGroupGetInfo $opts(system) $name 1]
        if {$opts(all) || $opts(name)} {
            lappend result -name $info(grpi3_name)
        }
        if {$opts(all) || $opts(comment)} {
            lappend result -comment $info(grpi3_comment)
        }
    }
    if {$opts(all) || $opts(members)} {
        lappend result -members [get_global_group_members $name -system $opts(system)]
    }
    return $result
}

#
# Get info about a local or global group
proc twapi::get_local_group_info {name args} {
    array set opts [parseargs args {
        {system.arg ""}
        comment
        name
        members
        sid
        all
    } -maxleftover 0]

    set result [list ]
    if {$opts(all) || $opts(sid)} {
        lappend result -sid [lookup_account_name $name -system $opts(system)]
    }
    if {$opts(all) || $opts(comment) || $opts(name)} {
        array set info [NetLocalGroupGetInfo $opts(system) $name 1]
        if {$opts(all) || $opts(name)} {
            lappend result -name $info(lgrpi1_name)
        }
        if {$opts(all) || $opts(comment)} {
            lappend result -comment $info(lgrpi1_comment)
        }
    }
    if {$opts(all) || $opts(members)} {
        lappend result -members [get_local_group_members $name -system $opts(system)]
    }
    return $result
}

#
# Get list of global groups on a system
proc twapi::get_global_groups {args} {
    array set opts [parseargs args {system.arg} -nulldefault]
    return [NetGroupEnum $opts(system)]
}

#
# Get list of local groups on a system
proc twapi::get_local_groups {args} {
    array set opts [parseargs args {system.arg} -nulldefault]
    return [NetLocalGroupEnum $opts(system)]
}


#
# Create a new global group
proc twapi::new_global_group {grpname args} {
    array set opts [parseargs args {
        system.arg
        comment.arg
    } -nulldefault]

    NetGroupAdd $opts(system) $grpname $opts(comment)
}


#
# Create a new local group
proc twapi::new_local_group {grpname args} {
    array set opts [parseargs args {
        system.arg
        comment.arg
    } -nulldefault]

    NetLocalGroupAdd $opts(system) $grpname $opts(comment)
}


#
# Delete a global group
proc twapi::delete_global_group {grpname args} {
    eval set [parseargs args {system.arg} -nulldefault]

    # Remove the group from the LSA rights database.
    _delete_rights $grpname $system

    NetGroupDel $opts(system) $grpname
}

#
# Delete a local group
proc twapi::delete_local_group {grpname args} {
    array set opts [parseargs args {system.arg} -nulldefault]

    # Remove the group from the LSA rights database.
    _delete_rights $grpname $opts(system)

    NetLocalGroupDel $opts(system) $grpname
}


#
# Enumerate members of a global group
proc twapi::get_global_group_members {grpname args} {
    array set opts [parseargs args {system.arg} -nulldefault]

    NetGroupGetUsers $opts(system) $grpname
}

#
# Enumerate members of a local group
proc twapi::get_local_group_members {grpname args} {
    array set opts [parseargs args {system.arg} -nulldefault]

    NetLocalGroupGetMembers $opts(system) $grpname
}

#
# Add a user to a global group
proc twapi::add_user_to_global_group {grpname username args} {
    eval set [parseargs args {system.arg} -nulldefault]

    # No error if already member of the group
    try {
        NetGroupAddUser $system $grpname $username
    } onerror {TWAPI_WIN32 1320} {
        # Ignore
    }
}


#
# Add a user to a local group
proc twapi::add_member_to_local_group {grpname username args} {
    eval set [parseargs args {system.arg} -nulldefault]

    # No error if already member of the group
    try {
        Twapi_NetLocalGroupAddMember $system $grpname $username
    } onerror {TWAPI_WIN32 1378} {
        # Ignore
    }
}


# Remove a user from a global group
proc twapi::remove_user_from_global_group {grpname username args} {
    eval set [parseargs args {system.arg} -nulldefault]

    try {
        NetGroupDelUser $system $grpname $username
    } onerror {TWAPI_WIN32 1321} {
        # Was not in group - ignore
    }
}


# Remove a user from a local group
proc twapi::remove_member_from_local_group {grpname username args} {
    eval set [parseargs args {system.arg} -nulldefault]

    try {
        Twapi_NetLocalGroupDelMember $system $grpname $username
    } onerror {TWAPI_WIN32 1377} {
        # Was not in group - ignore
    }
}


#
# Map a privilege given as a LUID
proc twapi::map_luid_to_privilege {luid args} {
    
    array set opts [parseargs args [list system.arg mapunknown] -nulldefault]

    # luid may in fact be a privilege name. Check for this
    if {[is_valid_luid_syntax $luid]} {
        try {
            set name [LookupPrivilegeName $opts(system) $luid]
        } onerror {TWAPI_WIN32 1313} {
            if {! $opts(mapunknown)} {
                error $errorResult $errorInfo $errorCode
            }
            set name "Privilege-$luid"
        }
    } else {
        # Not a valid LUID syntax. Check if it's a privilege name
        if {[catch {map_privilege_to_luid $luid -system $opts(system)}]} {
            error "Invalid LUID '$luid'"
        }
        return $luid;                   # $luid is itself a priv name
    }

    return $name
}


#
# Map a privilege to a LUID
proc twapi::map_privilege_to_luid {priv args} {
    array set opts [parseargs args [list system.arg] -nulldefault]

    # First check for privilege names we might have generated
    if {[string match "Privilege-*" $priv]} {
        set priv [string range $priv 10 end]
    }

    # If already a LUID format, return as is
    if {[is_valid_luid_syntax $priv]} {
        return $priv
    }
    return [LookupPrivilegeValue $opts(system) $priv]
}


#
# Return 1/0 if in LUID format
proc twapi::is_valid_luid_syntax {luid} {
    return [regexp {^[[:xdigit:]]{8}-[[:xdigit:]]{8}$} $luid]
}


################################################################
# Functions related to ACE's and ACL's

#
# Create a new ACE
proc twapi::new_ace {type account rights args} {
    variable windefs

    array set opts [parseargs args {
        {self.bool 1}
        {recursecontainers.bool 0}
        {recurseobjects.bool 0}
        {recurseonelevelonly.bool 0}
    }]

    set sid [map_account_to_sid $account]

    set access_mask [_access_rights_to_mask $rights]

    switch -exact -- $type {
        allow -
        deny  -
        audit {
            set typecode [_ace_type_symbol_to_code $type]
        }
        default {
            error "Invalid or unsupported ACE type '$type'"
        }
    }

    set inherit_flags 0
    if {! $opts(self)} {
        setbits inherit_flags $windefs(INHERIT_ONLY_ACE)
    }

    if {$opts(recursecontainers)} {
        setbits inherit_flags $windefs(CONTAINER_INHERIT_ACE)
    }

    if {$opts(recurseobjects)} {
        setbits inherit_flags $windefs(OBJECT_INHERIT_ACE)
    }

    if {$opts(recurseonelevelonly)} {
        setbits inherit_flags $windefs(NO_PROPAGATE_INHERIT_ACE)
    }

    return [list $typecode $inherit_flags $access_mask $sid]
}

#
# Get the ace type (allow, deny etc.)
proc twapi::get_ace_type {ace} {
    return [_ace_type_code_to_symbol [lindex $ace 0]]
}


#
# Set the ace type (allow, deny etc.)
proc twapi::set_ace_type {ace type} {
    return [lreplace $ace 0 0 [_ace_type_symbol_to_code $type]]
}

#
# Get the access rights in an ACE
proc twapi::get_ace_rights {ace args} {
    array set opts [parseargs args {type.arg raw} -nulldefault]
    if {$opts(raw)} {
        return [format 0x%x [lindex $ace 2]]
    } else {
        return [_access_mask_to_rights [lindex $ace 2] $opts(type)]
    }
}

#
# Set the access rights in an ACE
proc twapi::set_ace_rights {ace rights} {
    return [lreplace $ace 2 2 [_access_rights_to_mask $rights]]
}


#
# Get the ACE sid
proc twapi::get_ace_sid {ace} {
    return [lindex $ace 3]
}

#
# Set the ACE sid
proc twapi::set_ace_sid {ace account} {
    return [lreplace $ace 3 3 [map_account_to_sid $account]]
}


#
# Get the inheritance options
proc twapi::get_ace_inheritance {ace} {
    variable windefs
    
    set inherit_opts [list ]
    set inherit_mask [lindex $ace 1]

    lappend inherit_opts -self \
        [expr {($inherit_mask & $windefs(INHERIT_ONLY_ACE)) == 0}]
    lappend inherit_opts -recursecontainers \
        [expr {($inherit_mask & $windefs(CONTAINER_INHERIT_ACE)) != 0}]
    lappend inherit_opts -recurseobjects \
        [expr {($inherit_mask & $windefs(OBJECT_INHERIT_ACE)) != 0}]
    lappend inherit_opts -recurseonelevelonly \
        [expr {($inherit_mask & $windefs(NO_PROPAGATE_INHERIT_ACE)) != 0}]
    lappend inherit_opts -inherited \
        [expr {($inherit_mask & $windefs(INHERITED_ACE)) != 0}]

    return $inherit_opts
}

#
# Set the inheritance options. Unspecified options are not set
proc twapi::set_ace_inheritance {ace args} {
    variable windefs

    array set opts [parseargs args {
        self.bool
        recursecontainers.bool
        recurseobjects.bool
        recurseonelevelonly.bool
    }]
    
    set inherit_flags [lindex $ace 1]
    if {[info exists opts(self)]} {
        if {$opts(self)} {
            resetbits inherit_flags $windefs(INHERIT_ONLY_ACE)
        } else {
            setbits   inherit_flags $windefs(INHERIT_ONLY_ACE)
        }
    }

    foreach {
        opt                 mask
    } {
        recursecontainers   CONTAINER_INHERIT_ACE
        recurseobjects      OBJECT_INHERIT_ACE
        recurseonelevelonly NO_PROPAGATE_INHERIT_ACE
    } {
        if {[info exists opts($opt)]} {
            if {$opts($opt)} {
                setbits inherit_flags $windefs($mask)
            } else {
                resetbits inherit_flags $windefs($mask)
            }
        }
    }

    return [lreplace $ace 1 1 $inherit_flags]
}


#
# Sort ACE's in the standard recommended Win2K order
proc twapi::sort_aces {aces} {
    variable windefs

    _init_ace_type_symbol_to_code_map

    foreach type [array names twapi::_ace_type_symbol_to_code_map] {
        set direct_aces($type) [list ]
        set inherited_aces($type) [list ]
    }
    
    # Sort order is as follows: all direct (non-inherited) ACEs come
    # before all inherited ACEs. Within these groups, the order should be
    # access denied ACEs, access denied ACEs for objects/properties,
    # access allowed ACEs, access allowed ACEs for objects/properties,
    foreach ace $aces {
        set type [get_ace_type $ace]
        if {[lindex $ace 1] & $windefs(INHERITED_ACE)} {
            lappend inherited_aces($type) $ace
        } else {
            lappend direct_aces($type) $ace
        }
    }

    # TBD - check this order
    return [concat \
                $direct_aces(deny) \
                $direct_aces(deny_object) \
                $direct_aces(deny_callback) \
                $direct_aces(deny_callback_object) \
                $direct_aces(allow) \
                $direct_aces(allow_object) \
                $direct_aces(allow_compound) \
                $direct_aces(allow_callback) \
                $direct_aces(allow_callback_object) \
                $direct_aces(audit) \
                $direct_aces(audit_object) \
                $direct_aces(audit_callback) \
                $direct_aces(audit_callback_object) \
                $direct_aces(alarm) \
                $direct_aces(alarm_object) \
                $direct_aces(alarm_callback) \
                $direct_aces(alarm_callback_object) \
                $inherited_aces(deny) \
                $inherited_aces(deny_object) \
                $inherited_aces(deny_callback) \
                $inherited_aces(deny_callback_object) \
                $inherited_aces(allow) \
                $inherited_aces(allow_object) \
                $inherited_aces(allow_compound) \
                $inherited_aces(allow_callback) \
                $inherited_aces(allow_callback_object) \
                $inherited_aces(audit) \
                $inherited_aces(audit_object) \
                $inherited_aces(audit_callback) \
                $inherited_aces(audit_callback_object) \
                $inherited_aces(alarm) \
                $inherited_aces(alarm_object) \
                $inherited_aces(alarm_callback) \
                $inherited_aces(alarm_callback_object)]
}

#
# Pretty print an ACE
proc twapi::get_ace_text {ace args} {
    array set opts [parseargs args {
        {resourcetype.arg raw}
        {offset.arg ""}
    } -maxleftover 0]

    if {$ace eq "null"} {
        return "Null"
    }

    set offset $opts(offset)
    array set bools {0 No 1 Yes}
    array set inherit_flags [get_ace_inheritance $ace]
    append inherit_text "${offset}Inherited: $bools($inherit_flags(-inherited))\n"
    append inherit_text "${offset}Include self: $bools($inherit_flags(-self))\n"
    append inherit_text "${offset}Recurse containers: $bools($inherit_flags(-recursecontainers))\n"
    append inherit_text "${offset}Recurse objects: $bools($inherit_flags(-recurseobjects))\n"
    append inherit_text "${offset}Recurse single level only: $bools($inherit_flags(-recurseonelevelonly))\n"
    
    set rights [get_ace_rights $ace -type $opts(resourcetype)]
    if {[lsearch -glob $rights *_all_access] >= 0} {
        set rights "All"
    } else {
        set rights [join $rights ", "]
    }

    append result "${offset}Type: [string totitle [get_ace_type $ace]]\n"
    append result "${offset}User: [map_account_to_name [get_ace_sid $ace]]\n"
    append result "${offset}Rights: $rights\n"
    append result $inherit_text

    return $result
}

#
# Create a new ACL
proc twapi::new_acl {{aces ""}} {
    variable windefs

    set acl_rev $windefs(ACL_REVISION)
    
    foreach ace $aces {
        set ace_typecode [lindex $ace 0]
        if {$ace_typecode != $windefs(ACCESS_ALLOWED_ACE_TYPE) &&
            $ace_typecode != $windefs(ACCESS_DENIED_ACE_TYPE) &&
            $ace_typecode != $windefs(SYSTEM_AUDIT_ACE_TYPE)} {
            set acl_rev $windefs(ACL_REVISION_DS)
            break
        }
    }

    return [list $acl_rev $aces]
}

#
# Return the list of ACE's in an ACL
proc twapi::get_acl_aces {acl} {
    return [lindex $acl 1]
}

#
# Set the ACE's in an ACL
proc twapi::set_acl_aces {acl aces} {
    # Note, we call new_acl since when ACEs change, the rev may also change
    return [new_acl $aces]
}

#
# Append to the ACE's in an ACL
proc twapi::append_acl_aces {acl aces} {
    return [set_acl_aces $acl [concat [get_acl_aces $acl] $aces]]
}

#
# Prepend to the ACE's in an ACL
proc twapi::prepend_acl_aces {acl aces} {
    return [set_acl_aces $acl [concat $aces [get_acl_aces $acl]]]
}

#
# Arrange the ACE's in an ACL in a standard order
proc twapi::sort_acl_aces {acl} {
    return [set_acl_aces $acl [sort_aces [get_acl_aces $acl]]]
}

#
# Return the ACL revision of an ACL
proc twapi::get_acl_rev {acl} {
    return [lindex $acl 0]
}


#
# Create a new security descriptor
proc twapi::new_security_descriptor {args} {
    array set opts [parseargs args {
        owner.arg
        group.arg
        dacl.arg
        sacl.arg
    }]

    set secd [Twapi_InitializeSecurityDescriptor]

    foreach field {owner group dacl sacl} {
        if {[info exists opts($field)]} {
            set secd [set_security_descriptor_$field $secd $opts($field)]
        }
    }

    return $secd
}

#
# Return the control bits in a security descriptor
proc twapi::get_security_descriptor_control {secd} {
    if {[_null_secd $secd]} {
        error "Attempt to get control field from NULL security descriptor."
    }

    set control [lindex $secd 0]
    
    set retval [list ]
    if {$control & 0x0001} {
        lappend retval owner_defaulted
    }
    if {$control & 0x0002} {
        lappend retval group_defaulted
    }
    if {$control & 0x0004} {
        lappend retval dacl_present
    }
    if {$control & 0x0008} {
        lappend retval dacl_defaulted
    }
    if {$control & 0x0010} {
        lappend retval sacl_present
    }
    if {$control & 0x0020} {
        lappend retval sacl_defaulted
    }
    if {$control & 0x0100} {
        lappend retval dacl_auto_inherit_req
    }
    if {$control & 0x0200} {
        lappend retval sacl_auto_inherit_req
    }
    if {$control & 0x0400} {
        lappend retval dacl_auto_inherited
    }
    if {$control & 0x0800} {
        lappend retval sacl_auto_inherited
    }
    if {$control & 0x1000} {
        lappend retval dacl_protected
    }
    if {$control & 0x2000} {
        lappend retval sacl_protected
    }
    if {$control & 0x4000} {
        lappend retval rm_control_valid
    }
    if {$control & 0x8000} {
        lappend retval self_relative
    }
    return $retval
}

#
# Return the owner in a security descriptor
proc twapi::get_security_descriptor_owner {secd} {
    if {[_null_secd $secd]} {
        win32_error 87 "Attempt to get owner field from NULL security descriptor."
    }
    return [lindex $secd 1]
}

#
# Set the owner in a security descriptor
proc twapi::set_security_descriptor_owner {secd account} {
    if {[_null_secd $secd]} {
        set secd [new_security_descriptor]
    }
    set sid [map_account_to_sid $account]
    return [lreplace $secd 1 1 $sid]
}

#
# Return the group in a security descriptor
proc twapi::get_security_descriptor_group {secd} {
    if {[_null_secd $secd]} {
        win32_error 87 "Attempt to get group field from NULL security descriptor."
    }
    return [lindex $secd 2]
}

#
# Set the group in a security descriptor
proc twapi::set_security_descriptor_group {secd account} {
    if {[_null_secd $secd]} {
        set secd [new_security_descriptor]
    }
    set sid [map_account_to_sid $account]
    return [lreplace $secd 2 2 $sid]
}

#
# Return the DACL in a security descriptor
proc twapi::get_security_descriptor_dacl {secd} {
    if {[_null_secd $secd]} {
        win32_error 87 "Attempt to get DACL field from NULL security descriptor."
    }
    return [lindex $secd 3]
}

#
# Set the dacl in a security descriptor
proc twapi::set_security_descriptor_dacl {secd acl} {
    if {[_null_secd $secd]} {
        set secd [new_security_descriptor]
    }
    return [lreplace $secd 3 3 $acl]
}

#
# Return the SACL in a security descriptor
proc twapi::get_security_descriptor_sacl {secd} {
    if {[_null_secd $secd]} {
        win32_error 87 "Attempt to get SACL field from NULL security descriptor."
    }
    return [lindex $secd 4]
}

#
# Set the sacl in a security descriptor
proc twapi::set_security_descriptor_sacl {secd acl} {
    if {[_null_secd $secd]} {
        set secd [new_security_descriptor]
    }
    return [lreplace $secd 4 4 $acl]
}

#
# Get the specified security information for the given object
proc twapi::get_resource_security_descriptor {restype name args} {
    variable windefs

    array set opts [parseargs args {
        owner
        group
        dacl
        sacl
        all
        handle
    }]

    set wanted 0

    foreach field {owner group dacl sacl} {
        if {$opts($field) || $opts(all)} {
            set wanted [expr {$wanted | $windefs([string toupper $field]_SECURITY_INFORMATION)}]
        }
    }

    # Note if no options specified, we ask for everything except
    # SACL's which require special privileges
    if {! $wanted} {
        foreach field {owner group dacl} {
            set wanted [expr {$wanted | $windefs([string toupper $field]_SECURITY_INFORMATION)}]
        }
        set opts($field) 1
    }

    if {$opts(handle)} {
        set secd [Twapi_GetSecurityInfo \
                      [CastToHANDLE $name] \
                      [_map_resource_symbol_to_type $restype false] \
                      $wanted]
    } else {
        # GetNamedSecurityInfo seems to fail with a overlapped i/o
        # in progress error under some conditions. If this happens
        # try getting with resource-specific API's if possible.
        try {
            set secd [Twapi_GetNamedSecurityInfo \
                          $name \
                          [_map_resource_symbol_to_type $restype true] \
                          $wanted]
        } onerror {} {
            # TBD - see what other resource-specific API's there are
            if {$restype eq "share"} {
                set secd [lindex [get_share_info $name -secd] 1]
            } else {
                # Throw the same error
                error $errorResult $errorInfo $errorCode
            }
        }
    }

    return $secd
}


#
# Set the specified security information for the given object
# See http://search.cpan.org/src/TEVERETT/Win32-Security-0.50/README
# for a good discussion even though that applies to Perl
proc twapi::set_resource_security_descriptor {restype name secd args} {
    variable windefs

    array set opts [parseargs args {
        handle
        owner
        group
        dacl
        sacl
        all
        protect_dacl
        unprotect_dacl
        protect_sacl
        unprotect_sacl
    }]

    set mask 0

    if {[min_os_version 5 0]} {
        # Only win2k and above. Ignore otherwise

        if {$opts(protect_dacl) && $opts(unprotect_dacl)} {
            error "Cannot specify both -protect_dacl and -unprotect_dacl."
        }

        if {$opts(protect_dacl)} {
            setbits mask $windefs(PROTECTED_DACL_SECURITY_INFORMATION)
        }
        if {$opts(unprotect_dacl)} {
            setbits mask $windefs(UNPROTECTED_DACL_SECURITY_INFORMATION)
        }

        if {$opts(protect_sacl) && $opts(unprotect_sacl)} {
            error "Cannot specify both -protect_sacl and -unprotect_sacl."
        }

        if {$opts(protect_sacl)} {
            setbits mask $windefs(PROTECTED_SACL_SECURITY_INFORMATION)
        }
        if {$opts(unprotect_sacl)} {
            setbits mask $windefs(UNPROTECTED_SACL_SECURITY_INFORMATION)
        }

    }

    if {$opts(owner) || $opts(all)} {
        set opts(owner) [get_security_descriptor_owner $secd]
        setbits mask $windefs(OWNER_SECURITY_INFORMATION)
    } else {
        set opts(owner) ""
    }

    if {$opts(group) || $opts(all)} {
        set opts(group) [get_security_descriptor_group $secd]
        setbits mask $windefs(GROUP_SECURITY_INFORMATION)
    } else {
        set opts(group) ""
    }

    if {$opts(dacl) || $opts(all)} {
        set opts(dacl) [get_security_descriptor_dacl $secd]
        setbits mask $windefs(DACL_SECURITY_INFORMATION)
    } else {
        set opts(dacl) null
    }

    if {$opts(sacl) || $opts(all)} {
        set opts(sacl) [get_security_descriptor_sacl $secd]
        setbits mask $windefs(SACL_SECURITY_INFORMATION)
    } else {
        set opts(sacl) null
    }

    if {$opts(handle)} {
        SetSecurityInfo \
            [CastToHANDLE $name] \
            [_map_resource_symbol_to_type $restype false] \
            $mask \
            $opts(owner) \
            $opts(group) \
            $opts(dacl) \
            $opts(sacl)
    } else {
        SetNamedSecurityInfo \
            $name \
            [_map_resource_symbol_to_type $restype true] \
            $mask \
            $opts(owner) \
            $opts(group) \
            $opts(dacl) \
            $opts(sacl)
    }
}

#
# Return the text for a security descriptor
proc twapi::get_security_descriptor_text {secd args} {
    if {[_null_secd $secd]} {
        return "null"
    }

    array set opts [parseargs args {
        {resourcetype.arg raw}
    } -maxleftover 0]

    append result "Flags:\t[get_security_descriptor_control $secd]\n"
    append result "Owner:\t[map_account_to_name [get_security_descriptor_owner $secd]]\n"
    append result "Group:\t[map_account_to_name [get_security_descriptor_group $secd]]\n"

    set acl [get_security_descriptor_dacl $secd]
    append result "DACL Rev: [get_acl_rev $acl]\n"
    set index 0
    foreach ace [get_acl_aces $acl] {
        append result "\tDACL Entry [incr index]\n"
        append result "[get_ace_text $ace -offset "\t    " -resourcetype $opts(resourcetype)]"
    }

    set acl [get_security_descriptor_sacl $secd]
    append result "SACL Rev: [get_acl_rev $acl]\n"
    set index 0
    foreach ace [get_acl_aces $acl] {
        append result "\tSACL Entry $index\n"
        append result "[get_ace_text $ace -offset "\t    " -resourcetype $opts(resourcetype)]"
    }

    return $result
}

#
# Get a token for a user
proc twapi::open_user_token {username password args} {
    variable windefs

    array set opts [parseargs args {
        domain.arg
        {type.arg batch}
        {provider.arg default}
    } -nulldefault]

    set typedef "LOGON32_LOGON_[string toupper $opts(type)]"
    if {![info exists windefs($typedef)]} {
        error "Invalid value '$opts(type)' specified for -type option"
    }

    set providerdef "LOGON32_PROVIDER_[string toupper $opts(provider)]"
    if {![info exists windefs($typedef)]} {
        error "Invalid value '$opts(provider)' specified for -provider option"
    }
    
    # If username is of the form user@domain, then domain must not be specified
    # If username is not of the form user@domain, then domain is set to "."
    # if it is empty
    if {[regexp {^([^@]+)@(.+)} $username dummy user domain]} {
        if {[string length $opts(domain)] == 0} {
            error "The -domain option must not be specified when the username is of in UPN format (user@domain)"
        }
    } else {
        if {[string length $opts(domain)] == 0} {
            set opts(domain) "."
        }
    }

    return [LogonUser $username $opts(domain) $password $windefs($typedef) $windefs($providerdef)]
}


#
# Impersonate a user given a token
proc twapi::impersonate_token {token} {
    ImpersonateLoggedOnUser $token
}


#
# Impersonate a user
proc twapi::impersonate_user {args} {
    set token [eval open_user_token $args]
    try {
        impersonate_token $token
    } finally {
        close_token $token
    }
}


#
# Revert to process token
proc twapi::revert_to_self {{opt ""}} {
    RevertToSelf
}


#
# Impersonate self
proc twapi::impersonate_self {level} {
    switch -exact -- $level {
        anonymous      { set level 0 }
        identification { set level 1 }
        impersonation  { set level 2 }
        delegation     { set level 3 }
        default {
            error "Invalid impersonation level $level"
        }
    }
    ImpersonateSelf $level
}


#
# Log off
proc twapi::logoff {args} {
    array set opts [parseargs args {force forceifhung}]
    set flags 0
    if {$opts(force)} {setbits flags 0x4}
    if {$opts(forceifhung)} {setbits flags 0x10}
    ExitWindowsEx $flags 0
}

#
# Lock the workstation
proc twapi::lock_workstation {} {
    LockWorkStation
}

#
# Set a thread token - currently only for current thread
proc twapi::set_thread_token {token} {
    SetThreadToken NULL $token
}

#
# Reset a thread token - currently only for current thread
proc twapi::reset_thread_token {} {
    SetThreadToken NULL NULL
}

#
# Get a handle to a LSA policy
proc twapi::get_lsa_policy_handle {args} {
    array set opts [parseargs args {
        {system.arg ""}
        {access.arg policy_read}
    } -maxleftover 0]

    set access [_access_rights_to_mask $opts(access)]
    return [Twapi_LsaOpenPolicy $opts(system) $access]
}

#
# Close a LSA policy handle
proc twapi::close_lsa_policy_handle {h} {
    LsaClose $h
    return
}

#
# Get rights for an account
proc twapi::get_account_rights {account args} {
    array set opts [parseargs args {
        {system.arg ""}
    } -maxleftover 0]

    set sid [map_account_to_sid $account -system $opts(system)]

    try {
        set lsah [get_lsa_policy_handle -system $opts(system) -access policy_lookup_names]
        return [Twapi_LsaEnumerateAccountRights $lsah $sid]
    } onerror {TWAPI_WIN32 2} {
        # No specific rights for this account
        return [list ]
    } finally {
        if {[info exists lsah]} {
            close_lsa_policy_handle $lsah
        }
    }
}

#
# Get accounts having a specific right
proc twapi::find_accounts_with_right {right args} {
    array set opts [parseargs args {
        {system.arg ""}
        name
    } -maxleftover 0]

    try {
        set lsah [get_lsa_policy_handle \
                      -system $opts(system) \
                      -access {
                          policy_lookup_names
                          policy_view_local_information
                      }]
        set accounts [list ]
        foreach sid [Twapi_LsaEnumerateAccountsWithUserRight $lsah $right] {
            if {$opts(name)} {
                if {[catch {lappend accounts [lookup_account_sid $sid]}]} {
                    # No mapping for SID - can happen if account has been
                    # deleted but LSA policy not updated accordingly
                    lappend accounts $sid
                }
            } else {
                lappend accounts $sid
            }
        }
        return $accounts
    } onerror {TWAPI_WIN32 259} {
        # No accounts have this right
        return [list ]
    } finally {
        if {[info exists lsah]} {
            close_lsa_policy_handle $lsah
        }
    }

}

#
# Add/remove rights to an account
proc twapi::_modify_account_rights {operation account rights args} {
    set switches {
        system.arg
        handle.arg
    }    

    switch -exact -- $operation {
        add {
            # Nothing to do
        }
        remove {
            lappend switches all
        }
        default {
            error "Invalid operation '$operation' specified"
        }
    }

    array set opts [parseargs args $switches -maxleftover 0]

    if {[info exists opts(system)] && [info exists opts(handle)]} {
        error "Options -system and -handle may not be specified together"
    }

    if {[info exists opts(handle)]} {
        set lsah $opts(handle)
        set sid $account
    } else {
        if {![info exists opts(system)]} {
            set opts(system) ""
        }

        set sid [map_account_to_sid $account -system $opts(system)]
        # We need to open a policy handle ourselves. First try to open
        # with max privileges in case the account needs to be created
        # and then retry with lower privileges if that fails
        catch {
            set lsah [get_lsa_policy_handle \
                          -system $opts(system) \
                          -access {
                              policy_lookup_names
                              policy_create_account
                          }]
        }
        if {![info exists lsah]} {
            set lsah [get_lsa_policy_handle \
                          -system $opts(system) \
                          -access policy_lookup_names]
        }
    }

    try {
        if {$operation == "add"} {
            Twapi_LsaAddAccountRights $lsah $sid $rights
        } else {
            Twapi_LsaRemoveAccountRights $lsah $sid $opts(all) $rights
        }
    } finally {
        # Close the handle if we opened it
        if {! [info exists opts(handle)]} {
            close_lsa_policy_handle $lsah
        }
    }
}

interp alias {} twapi::add_account_rights {} twapi::_modify_account_rights add
interp alias {} twapi::remove_account_rights {} twapi::_modify_account_rights remove

#
# Get a new LUID
proc twapi::new_luid {} {
    return [AllocateLocallyUniqueId]
}

#
# TBD - maybe these UUID functions should not be in the security module
# Get a new uuid
proc twapi::new_uuid {{opt ""}} {
    if {[string length $opt]} {
        if {[string equal $opt "-localok"]} {
            set local_ok 1
        } else {
            error "Invalid or unknown argument '$opt'"
        }
    } else {
        set local_ok 0
    }
    return [UuidCreate $local_ok] 
}
proc twapi::nil_uuid {} {
    return [UuidCreateNil]
}


#
# Get the description of a privilege
proc twapi::get_privilege_description {priv} {
    if {[catch {LookupPrivilegeDisplayName "" $priv} desc]} {
        switch -exact -- $priv {
            # The above function will only return descriptions for
            # privileges, not account rights. Hard code descriptions
            # for some account rights
            SeBatchLogonRight { set desc "Log on as a batch job" }
            SeDenyBatchLogonRight { set desc "Deny logon as a batch job" }
            SeDenyInteractiveLogonRight { set desc "Deny logon locally" }
            SeDenyNetworkLogonRight { set desc "Deny access to this computer from the network" }
            SeDenyServiceLogonRight { set desc "Deny logon as a service" }
            SeInteractiveLogonRight { set desc "Log on locally" }
            SeNetworkLogonRight { set desc "Access this computer from the network" }
            SeServiceLogonRight { set desc "Log on as a service" }
            default {set desc ""}
        }
    }
    return $desc
}


# Return list of logon sesionss
proc twapi::find_logon_sessions {args} {
    array set opts [parseargs args {
        user.arg
        type.arg
        tssession.arg
    } -maxleftover 0]

    set luids [LsaEnumerateLogonSessions]
    if {! ([info exists opts(user)] || [info exists opts(type)] ||
           [info exists opts(tssession)])} {
        return $luids
    }


    # Need to get the data for each session to see if it matches
    set result [list ]
    if {[info exists opts(user)]} {
        set sid [map_account_to_sid $opts(user)]
    }
    if {[info exists opts(type)]} {
        set logontypes [list ]
        foreach logontype $opts(type) {
            lappend logontypes [_logon_session_type_code $logontype]
        }
    }

    foreach luid $luids {
        try {
            unset -nocomplain session
            array set session [LsaGetLogonSessionData $luid]

            # For the local system account, no data is returned on some
            # platforms
            if {[array size session] == 0} {
                set session(Sid) S-1-5-18; # SYSTEM
                set session(Session) 0
                set session(LogonType) 0
            }
            if {[info exists opts(user)] && $session(Sid) ne $sid} {
                continue;               # User id does not match
            }

            if {[info exists opts(type)] && [lsearch -exact $logontypes $session(LogonType)] < 0} {
                continue;               # Type does not match
            }

            if {[info exists opts(tssession)] && $session(Session) != $opts(tssession)} {
                continue;               # Term server session does not match
            }

            lappend result $luid

        } onerror {TWAPI_WIN32 1312} {
            # Session no longer exists. Just skip
            continue
        }
    }

    return $result
}


# Return data for a logon session
proc twapi::get_logon_session_info {luid args} {
    array set opts [parseargs args {
        all
        authpackage
        dnsdomain
        logondomain
        logonid
        logonserver
        logontime
        type
        sid
        user
        tssession
        userprincipal
    } -maxleftover 0]

    array set session [LsaGetLogonSessionData $luid]

    # Some fields may be missing on Win2K
    foreach fld {LogonServer DnsDomainName Upn} {
        if {![info exists session($fld)]} {
            set session($fld) ""
        }
    }

    array set result [list ]
    foreach {opt index} {
        authpackage AuthenticationPackage
        dnsdomain   DnsDomainName
        logondomain LogonDomain
        logonid     LogonId
        logonserver LogonServer
        logontime   LogonTime
        type        LogonType
        sid         Sid
        user        UserName
        tssession   Session
        userprincipal Upn
    } {
        if {$opts(all) || $opts($opt)} {
            set result(-$opt) $session($index)
        }
    }

    if {[info exists result(-type)]} {
        set result(-type) [_logon_session_type_symbol $result(-type)]
    }

    return [array get result]
}



################################################################
# Utility and helper functions



# Returns an sid field from a token
proc twapi::_get_token_sid_field {tok field options} {
    array set opts [parseargs options {name}]
    set owner [GetTokenInformation $tok $twapi::windefs($field)]
    if {$opts(name)} {
        set owner [lookup_account_sid $owner]
    }
    return $owner
}


#
# Map a token attribute mask to list of attribute names
proc twapi::_map_token_attr {attr names prefix} {
    variable windefs

    set attrs [list ]
    foreach attr_name $names {
        set attr_mask $windefs(${prefix}_[string toupper $attr_name])
        if {[expr {$attr & $attr_mask}]} {
            lappend attrs $attr_name
        }
    }

    return $attrs
}

#
# Set/reset the given bits in the usri3_flags field for a user account
# mask indicates the mask of bits to set. values indicates the values
# of those bits
proc twapi::_change_usri3_flags {username mask values args} {
    array set opts [parseargs args {
        system.arg
    } -nulldefault -maxleftover 0]

    # Get current flags
    array set data [NetUserGetInfo $opts(system) $username 1]

    # Turn off mask bits and write flags back
    set flags [expr {$data(usri3_flags) & (~ $mask)}]
    # Set the specified bits
    set flags [expr {$flags | ($values & $mask)}]

    # Write new flags back
    Twapi_NetUserSetInfo_flags $opts(system) $username $flags
}


#
# Map a set of access right symbols to a flag. Concatenates
# all the arguments, and then OR's the individual elements. Each
# element may either be a integer or one of the access rights
proc twapi::_access_rights_to_mask {args} {
    variable windefs

    set rights 0
    foreach right [eval concat $args] {
        if {![string is integer $right]} {
            if {$right == "token_all_access"} {
                if {[min_os_version 5 0]} {
                    set right $windefs(TOKEN_ALL_ACCESS_WIN2K)
                } else {
                    set right $windefs(TOKEN_ALL_ACCESS_WIN2K)
                }
            } else {
                if {[catch {set right $windefs([string toupper $right])}]} {
                    error "Invalid access right symbol '$right'"
                }
            }
        }
        set rights [expr {$rights | $right}]
    }

    return $rights
}


#
# Map an access mask to a set of rights
proc twapi::_access_mask_to_rights {access_mask {type ""}} {
    variable windefs

    set rights [list ]

    # The returned list will include rights that map to multiple bits
    # as well as the individual bits. We first add the multiple bits
    # and then the individual bits (since we clear individual bits
    # after adding)

    #
    # Check standard multiple bit masks
    #
    foreach x {STANDARD_RIGHTS_REQUIRED STANDARD_RIGHTS_READ STANDARD_RIGHTS_WRITE STANDARD_RIGHTS_EXECUTE STANDARD_RIGHTS_ALL SPECIFIC_RIGHTS_ALL} {
        if {($windefs($x) & $access_mask) == $windefs($x)} {
            lappend rights [string tolower $x]
        }
    }
    #
    # Check type specific multiple bit masks
    #
    switch -exact -- $type {
        file {
            set masks [list FILE_ALL_ACCESS FILE_GENERIC_READ FILE_GENERIC_WRITE FILE_GENERIC_EXECUTE]
        }
        pipe {
            set masks [list FILE_ALL_ACCESS]
        }
        service {
            set masks [list SERVICE_ALL_ACCESS]
        }
        registry {
            set masks [list KEY_READ KEY_WRITE KEY_EXECUTE KEY_ALL_ACCESS]
        }
        process {
            set masks [list PROCESS_ALL_ACCESS]
        }
        thread {
            set masks [list THREAD_ALL_ACCESS]
        }
        token {
            set masks [list TOKEN_READ TOKEN_WRITE TOKEN_EXECUTE]
            # TOKEN_ALL_ACCESS depends on platform
            if {[min_os_version 5 0]} {
                set token_all_access $windefs(TOKEN_ALL_ACCESS_WIN2K)
            } else {
                set token_all_access $windefs(TOKEN_ALL_ACCESS_WIN2K)
            }
            if {($token_all_access & $access_mask) == $token_all_access} {
                lappend rights "token_all_access"
            }
        }
        desktop {
            # THere is no desktop all access bits
        }
        winsta {
            set masks [list WINSTA_ALL_ACCESS]
        }
        default {
            set masks [list ]
        }
    }

    foreach x $masks {
        if {($windefs($x) & $access_mask) == $windefs($x)} {
            lappend rights [string tolower $x]
        }
    }


    #
    # OK, now map individual bits

    # First map the common bits
    foreach x {DELETE READ_CONTROL WRITE_DAC WRITE_OWNER SYNCHRONIZE} {
        if {$windefs($x) & $access_mask} {
            lappend rights [string tolower $x]
            resetbits access_mask $windefs($x)
        }
    }

    # Then the generic bits
    foreach x {GENERIC_READ GENERIC_WRITE GENERIC_EXECUTE GENERIC_ALL} {
        if {$windefs($x) & $access_mask} {
            lappend rights [string tolower $x]
            resetbits access_mask $windefs($x)
        }
    }

    # Then the type specific
    switch -exact -- $type {
        file {
            set masks {
                FILE_READ_DATA
                FILE_WRITE_DATA
                FILE_APPEND_DATA
                FILE_READ_EA
                FILE_WRITE_EA
                FILE_EXECUTE
                FILE_DELETE_CHILD
                FILE_READ_ATTRIBUTES
                FILE_WRITE_ATTRIBUTES
            }
        }
        pipe {
            set masks {
                FILE_READ_DATA
                FILE_WRITE_DATA
                FILE_CREATE_PIPE_INSTANCE
                FILE_READ_ATTRIBUTES
                FILE_WRITE_ATTRIBUTES
            }
        }
        service {
            set masks {
                SERVICE_QUERY_CONFIG
                SERVICE_CHANGE_CONFIG
                SERVICE_QUERY_STATUS
                SERVICE_ENUMERATE_DEPENDENTS
                SERVICE_START
                SERVICE_STOP
                SERVICE_PAUSE_CONTINUE
                SERVICE_INTERROGATE
                SERVICE_USER_DEFINED_CONTROL
            }
        }
        registry {
            set masks {
                KEY_QUERY_VALUE
                KEY_SET_VALUE
                KEY_CREATE_SUB_KEY
                KEY_ENUMERATE_SUB_KEYS
                KEY_NOTIFY
                KEY_CREATE_LINK
                KEY_WOW64_32KEY
                KEY_WOW64_64KEY
                KEY_WOW64_RES
            }
        }
        process {
            set masks {
                PROCESS_TERMINATE
                PROCESS_CREATE_THREAD
                PROCESS_SET_SESSIONID
                PROCESS_VM_OPERATION
                PROCESS_VM_READ
                PROCESS_VM_WRITE
                PROCESS_DUP_HANDLE
                PROCESS_CREATE_PROCESS
                PROCESS_SET_QUOTA
                PROCESS_SET_INFORMATION
                PROCESS_QUERY_INFORMATION
                PROCESS_SUSPEND_RESUME
            }
        }
        thread {
            set masks {
                THREAD_TERMINATE
                THREAD_SUSPEND_RESUME
                THREAD_GET_CONTEXT
                THREAD_SET_CONTEXT
                THREAD_SET_INFORMATION
                THREAD_QUERY_INFORMATION
                THREAD_SET_THREAD_TOKEN
                THREAD_IMPERSONATE
                THREAD_DIRECT_IMPERSONATION
            }
        }
        token {
            set masks {
                TOKEN_ASSIGN_PRIMARY
                TOKEN_DUPLICATE
                TOKEN_IMPERSONATE
                TOKEN_QUERY
                TOKEN_QUERY_SOURCE
                TOKEN_ADJUST_PRIVILEGES
                TOKEN_ADJUST_GROUPS
                TOKEN_ADJUST_DEFAULT
                TOKEN_ADJUST_SESSIONID
            }
        }
        desktop {
            set masks {
                DESKTOP_READOBJECTS
                DESKTOP_CREATEWINDOW
                DESKTOP_CREATEMENU
                DESKTOP_HOOKCONTROL
                DESKTOP_JOURNALRECORD
                DESKTOP_JOURNALPLAYBACK
                DESKTOP_ENUMERATE
                DESKTOP_WRITEOBJECTS
                DESKTOP_SWITCHDESKTOP
            }
        }
        windowstation -
        winsta {
            set masks {
                WINSTA_ENUMDESKTOPS
                WINSTA_READATTRIBUTES
                WINSTA_ACCESSCLIPBOARD
                WINSTA_CREATEDESKTOP
                WINSTA_WRITEATTRIBUTES
                WINSTA_ACCESSGLOBALATOMS
                WINSTA_EXITWINDOWS
                WINSTA_ENUMERATE
                WINSTA_READSCREEN
            }
        }
        default {
            set masks [list ]
        }
    }

    foreach x $masks {
        if {$windefs($x) & $access_mask} {
            lappend rights [string tolower $x]
            resetbits access_mask $windefs($x)
        }
    }

    # Finally add left over bits if any
    for {set i 0} {$i < 32} {incr i} {
        set x [expr {1 << $i}]
        if {$access_mask & $x} {
            lappend rights [format 0x%.8X $x]
        }
    }

    return $rights
}


#
# Map an ace type symbol (eg. allow) to the underlying ACE type code
proc twapi::_ace_type_symbol_to_code {type} {
    _init_ace_type_symbol_to_code_map
    return $::twapi::_ace_type_symbol_to_code_map($type)
}


#
# Map an ace type code to an ACE type symbol
proc twapi::_ace_type_code_to_symbol {type} {
    _init_ace_type_symbol_to_code_map
    return $::twapi::_ace_type_code_to_symbol_map($type)
}


# Init the arrays used for mapping ACE type symbols to codes and back
proc twapi::_init_ace_type_symbol_to_code_map {} {
    variable windefs

    if {[info exists ::twapi::_ace_type_symbol_to_code_map]} {
        return
    }

    # Define the array. Be careful to "normalize" the integer values
    array set ::twapi::_ace_type_symbol_to_code_map \
        [list \
             allow [expr { $windefs(ACCESS_ALLOWED_ACE_TYPE) + 0 }] \
             deny [expr  { $windefs(ACCESS_DENIED_ACE_TYPE) + 0 }] \
             audit [expr { $windefs(SYSTEM_AUDIT_ACE_TYPE) + 0 }] \
             alarm [expr { $windefs(SYSTEM_ALARM_ACE_TYPE) + 0 }] \
             allow_compound [expr { $windefs(ACCESS_ALLOWED_COMPOUND_ACE_TYPE) + 0 }] \
             allow_object [expr   { $windefs(ACCESS_ALLOWED_OBJECT_ACE_TYPE) + 0 }] \
             deny_object [expr    { $windefs(ACCESS_DENIED_OBJECT_ACE_TYPE) + 0 }] \
             audit_object [expr   { $windefs(SYSTEM_AUDIT_OBJECT_ACE_TYPE) + 0 }] \
             alarm_object [expr   { $windefs(SYSTEM_ALARM_OBJECT_ACE_TYPE) + 0 }] \
             allow_callback [expr { $windefs(ACCESS_ALLOWED_CALLBACK_ACE_TYPE) + 0 }] \
             deny_callback [expr  { $windefs(ACCESS_DENIED_CALLBACK_ACE_TYPE) + 0 }] \
             allow_callback_object [expr { $windefs(ACCESS_ALLOWED_CALLBACK_OBJECT_ACE_TYPE) + 0 }] \
             deny_callback_object [expr  { $windefs(ACCESS_DENIED_CALLBACK_OBJECT_ACE_TYPE) + 0 }] \
             audit_callback [expr { $windefs(SYSTEM_AUDIT_CALLBACK_ACE_TYPE) + 0 }] \
             alarm_callback [expr { $windefs(SYSTEM_ALARM_CALLBACK_ACE_TYPE) + 0 }] \
             audit_callback_object [expr { $windefs(SYSTEM_AUDIT_CALLBACK_OBJECT_ACE_TYPE) + 0 }] \
             alarm_callback_object [expr { $windefs(SYSTEM_ALARM_CALLBACK_OBJECT_ACE_TYPE) + 0 }] \
                 ]

    # Now define the array in the other direction
    foreach {sym code} [array get ::twapi::_ace_type_symbol_to_code_map] {
        set ::twapi::_ace_type_code_to_symbol_map($code) $sym
    }
}

#
# Construct a security attributes structure out of a security descriptor
# and inheritance flave
proc twapi::_make_secattr {secd inherit} {
    if {$inherit} {
        set sec_attr [list $secd 1]
    } else {
        if {$secd == ""} {
            # If a security descriptor not specified, keep
            # all security attributes as an empty list (ie. NULL)
            set sec_attr [list ]
        } else {
            set sec_attr [list $secd 0]
        }
    }
    return $sec_attr
}

#
# Map a resource symbol type to value
proc twapi::_map_resource_symbol_to_type {sym {named true}} {
    if {[string is integer $sym]} {
        return $sym
    }

    # Note "window" is not here because window stations and desktops
    # do not have unique names and cannot be used with Get/SetNamedSecurityInfo
    switch -exact -- $sym {
        file      { return 1 }
        service   { return 2 }
        printer   { return 3 }
        registry  { return 4 }
        share     { return 5 }
        kernelobj { return 6 }
    }
    if {$named} {
        error "Resource type '$restype' not valid for named resources."
    }

    switch -exact -- $sym {
        windowstation    { return 7 }
        directoryservice { return 8 }
        directoryserviceall { return 9 }
        providerdefined { return 10 }
        wmiguid { return 111 }
        registrywow6432key { return 12 }
    }

    error "Resource type '$restype' not valid"
}

#
# Map impersonation level to symbol
proc twapi::_map_impersonation_level ilevel {
    switch -exact -- $ilevel {
        0 { return "anonymous" }
        1 { return "identification" }
        2 { return "impersonation" }
        3 { return "delegation" }
        default { return $ilevel }
    }
}

#
# Valid LUID syntax
proc twapi::_is_valid_luid_syntax luid {
    return [regexp {^[[:xdigit:]]{8}-[[:xdigit:]]{8}$} $luid]
}


# Delete rights for an account
proc twapi::_delete_rights {account system} {
    # Remove the user from the LSA rights database. Ignore any errors
    catch {
        remove_account_rights $account {} -all -system $system

        # On Win2k SP1 and SP2, we need to delay a bit for notifications
        # to complete before deleting the account.
        # See http://support.microsoft.com/?id=316827
        foreach {major minor sp dontcare} [get_os_version] break
        if {($major == 5) && ($minor == 0) && ($sp < 3)} {
            after 1000
        }
    }
}

# Variable that maps logon session type codes to integer values
# See ntsecapi.h for definitions
set twapi::::logon_session_type_map {
    0
    1
    interactive
    network
    batch
    service
    proxy
    unlockworkstation
    networkclear
    newcredentials
    remoteinteractive
    cachedinteractive
    cachedremoteinteractive
    cachedunlockworkstation
}

# REturns the logon session type value for a symbol
proc twapi::_logon_session_type_code {type} {
    # Type may be an integer or one of the strings below
    set code [lsearch -exact $::twapi::logon_session_type_map $type]
    if {$code >= 0} {
        return $code
    }

    if {![string is integer -strict $type]} {
        error "Invalid logon session type '$type' specified"
    }
    return $type
}

# Returns the logon session type symbol for an integer value
proc twapi::_logon_session_type_symbol {code} {
    set symbol [lindex $::twapi::logon_session_type_map $code]
    if {$symbol eq ""} {
        return $code
    } else {
        return $symbol
    }
}

# Returns true if null security descriptor
proc twapi::_null_secd {secd} {
    if {[llength $secd] == 0} {
        return 1
    } else {
        return 0
    }
}

# Returns true if a valid ACL
proc twapi::_is_valid_acl {acl} {
    if {$acl eq "null"} {
        return 1
    } else {
        return [IsValidAcl $acl]
    }
}

# Returns true if a valid ACL
proc twapi::_is_valid_security_descriptor {secd} {
    if {[_null_secd $secd]} {
        return 1
    } else {
        return [IsValidSecurityDescriptor $secd]
    }
}
