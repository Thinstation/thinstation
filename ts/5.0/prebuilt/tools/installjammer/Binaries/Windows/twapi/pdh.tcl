#
# Copyright (c) 2003, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

namespace eval twapi {
}

# TBD - how do we know when to refresh items
# - have a begin/end explicitly done by applications
# - have a standard -refresh option
# - distinguish between internal and external routines


#
# Return list of toplevel performance objects
proc twapi::get_perf_objects {args} {
    variable windefs

    array set opts [parseargs args {
        datasource.arg
        machine.arg
        {detail.arg wizard}
        refresh
    } -nulldefault]
    
    # NT 4.0 requires datasource to be null
    if {[string length $opts(datasource)] && ![min_os_version 5 0]} {
        error "Option -datasource is invalid on Windows NT 4.0 platforms"
    }

    set detail_index "PERF_DETAIL_[string toupper $opts(detail)]"
    if {![info exists windefs($detail_index)]} {
        error "Invalid value '$opts(detail)' specified for -detail option"
    }

    # TBD - PdhEnumObjects enables the SeDebugPrivilege the first time it
    # is called. Should we reset it if it was not already enabled?
    # This seems to only happen on the first call

    return [PdhEnumObjects $opts(datasource) $opts(machine) \
                $windefs($detail_index) $opts(refresh)]
}

#
# Return list of items within a performance object
proc twapi::get_perf_object_items {objname args} {
    variable windefs

    array set opts [parseargs args {
        datasource.arg
        machine.arg
        {detail.arg wizard}
        refresh
    } -nulldefault]
    
    # NT 4.0 requires datasource to be null
    if {[string length $opts(datasource)] && ![min_os_version 5 0]} {
        error "Option -datasource is invalid on Windows NT 4.0 platforms"
    }

    set detail_index "PERF_DETAIL_[string toupper $opts(detail)]"
    if {![info exists windefs($detail_index)]} {
        error "Invalid value '$opts(detail)' specified for -detail option"
    }

    if {$opts(refresh)} {
        _refresh_perf_objects $opts(machine) $opts(datasource)
    }

    return [PdhEnumObjectItems $opts(datasource) $opts(machine) \
                $objname $windefs($detail_index) 0]
}

#
# Connect to the specified machine
proc twapi::connect_perf {machine} {
    PdhConnectMachine($machine)
}

#
# Construct a counter path
proc twapi::make_perf_counter_path {object counter args} {
    array set opts [parseargs args {
        machine.arg
        instance.arg
        parent.arg
        instanceindex.int
        {localize.bool false}
    } -nulldefault]
    
    if {$opts(instanceindex) < -1} {
        # Note -1 allowed for instance index
        error "Invalid value '$opts(instanceindex)' specified for -instanceindex option"
    }

    if {$opts(localize)} {
        # Need to localize the counter names
        set object [_localize_perf_counter $object]
        set counter [_localize_perf_counter $counter]
        # TBD - not sure we need to localize parent
        set opts(parent) [_localize_perf_counter $opts(parent)]
    }

    return [PdhMakeCounterPath $opts(machine) $object $opts(instance) \
                $opts(parent) $opts(instanceindex) $counter 0]

}

#
# Parse a counter path and return the individual elements
proc twapi::parse_perf_counter_path {counter_path} {
    array set counter_elems [PdhParseCounterPath $counter_path 0]

    lappend result machine       $counter_elems(szMachineName)
    lappend result object        $counter_elems(szObjectName)
    lappend result instance      $counter_elems(szInstanceName)
    lappend result instanceindex $counter_elems(dwInstanceIndex)
    lappend result parent        $counter_elems(szParentInstance)
    lappend result counter       $counter_elems(szCounterName)

    return $result
}

#
# Validate a counter path - error if invalid
proc twapi::validate_perf_counter_path {counter_path} {
    PdhValidatePath $counter_path
}

#
# Open a query that will be used as a container for counters
proc twapi::open_perf_query {args} {

    array set opts [parseargs args {
        datasource.arg
        cookie.int
    } -nulldefault]
    
    # NT 4.0 requires datasource to be null
    if {[string length $opts(datasource)] && ![min_os_version 5 0]} {
        error "Option -datasource is invalid on Windows NT 4.0 platforms"
    }
    
    if {! [string is integer -strict $opts(cookie)]} {
        error "Non-integer value '$opts(cookie)' specified for -cookie option"
    }
    
    return [PdhOpenQuery $opts(datasource) $opts(cookie)]
}

#
# Close a query - all related counter handles will also be closed
proc twapi::close_perf_query {hquery} {
    PdhCloseQuery $hquery
}

#
# Add a counter to a query
proc twapi::add_perf_counter {hquery counter_path args} {
    array set opts [parseargs args {
        cookie.int
    } -nulldefault]
    
    set hcounter [PdhAddCounter $hquery $counter_path $opts(cookie)]
    return $hcounter
}

#
# Remove a counter
proc twapi::remove_perf_counter {hcounter} {
    PdhRemoveCounter $hcounter
}


#
# Get snapshot of counters in a query
proc twapi::collect_perf_query_data {hquery} {
    PdhCollectQueryData $hquery
}

#
# Get the value of a counter in a query
# TBD - add some way of getting the cookie associated with the counter
proc twapi::get_hcounter_value {hcounter args} {
    variable windefs

    #puts "$hcounter"
    array set opts [parseargs args {
        {format.arg long {long large double}}
        scale.arg
        var.arg
        full.bool
    } -nulldefault]
    
    set format $windefs(PDH_FMT_[string toupper $opts(format)])

    switch -exact -- $opts(scale) {
        ""        { set scale 0 }
        none      { set scale $windefs(PDH_FMT_NOSCALE) }
        nocap     { set scale $windefs(PDH_FMT_NOCAP) }
        x1000     { set scale $windefs(PDH_FMT_1000) }
        default {
            error "Invalid value '$opts(scale)' specified for -scale option"
        }
    }

    set flags [expr {$format | $scale}]

    set status 1
    set result ""
    try {
        set result [PdhGetFormattedCounterValue $hcounter $flags]
    } onerror {TWAPI_WIN32 0x800007d1} {
        # Error is that no such instance exists.
        # If result is being returned in a variable, then
        # we will not generate an error but pass back a return value
        # of 0
        if {[string length $opts(var)] == 0} {
            # Pass on the error
            error $errorResult $errorInfo $errorCode
        }
        set status 0
    }
    if {! $opts(full)} {
        # Only care about the value, not type
        set result [lindex $result 0]
    }
    
    if {[string length $opts(var)]} {
        uplevel [list set $opts(var) $result]
        return $status
    } else {
        return $result
    }
}


#
# Get the value of a counter identified by the path
proc twapi::get_counter_path_value {counter_path args} {
    variable windefs

    array set opts [parseargs args {
        interval.int
        {format.arg long}
        scale.arg
        datasource.arg
        var.arg
        full.bool
    } -nulldefault]
    
    if {$opts(interval) < 0} {
        error "Negative value '$opts(interval)' specified for option -interval"
    }

    # Open the query
    set hquery [open_perf_query -datasource $opts(datasource)]
    try {
        set hcounter [add_perf_counter $hquery $counter_path]
        collect_perf_query_data $hquery
        if {$opts(interval)} {
            after $opts(interval)
            collect_perf_query_data $hquery
        }
        if {[string length $opts(var)]} {
            # Need to pass up value in a variable if so requested
            upvar $opts(var) myvar
            set opts(var) myvar
        }
        set value [get_hcounter_value $hcounter -format $opts(format) \
                       -scale $opts(scale) -full $opts(full) \
                       -var $opts(var)]
    } finally {
        if {[info exists hcounter]} {
            remove_perf_counter $hcounter
        }
        close_perf_query $hquery
    }

    return $value
}


#
# Constructs one or more counter paths for getting process information. 
# Returned as a list of sublists. Each sublist corresponds to a counter path 
# and has the form {counteroptionname datatype counterpath rate}
# datatype is the recommended format when retrieving counter value (eg. double)
# rate is 0 or 1 depending on whether the counter is a rate based counter or 
# not (requires at least two readings when getting the value)
proc twapi::get_perf_process_counter_paths {pids args} {
    variable _process_counter_opt_map

    if {![info exists _counter_opt_map]} {
        #  "descriptive string" format rate
        array set _process_counter_opt_map {
            privilegedutilization {"% Privileged Time"   double 1}
            processorutilization  {"% Processor Time"    double 1}
            userutilization       {"% User Time"         double 1}
            parent                {"Creating Process ID" long   0}
            elapsedtime           {"Elapsed Time"        large  0}
            handlecount           {"Handle Count"        long   0}
            pid                   {"ID Process"          long   0}
            iodatabytesrate       {"IO Data Bytes/sec"   large  1}
            iodataopsrate         {"IO Data Operations/sec"  large 1}
            iootherbytesrate      {"IO Other Bytes/sec"      large 1}
            iootheropsrate        {"IO Other Operations/sec" large 1}
            ioreadbytesrate       {"IO Read Bytes/sec"       large 1}
            ioreadopsrate         {"IO Read Operations/sec"  large 1}
            iowritebytesrate      {"IO Write Bytes/sec"      large 1}
            iowriteopsrate        {"IO Write Operations/sec" large 1}
            pagefaultrate         {"Page Faults/sec"         large 0}
            pagefilebytes         {"Page File Bytes"         large 0}
            pagefilebytespeak     {"Page File Bytes Peak"    large 0}
            poolnonpagedbytes     {"Pool Nonpaged Bytes"     large 0}
            poolpagedbytes        {"Pool Paged Bytes"        large 1}
            basepriority          {"Priority Base"           large 1}
            privatebytes          {"Private Bytes"           large 1}
            threadcount           {"Thread Count"            large 1}
            virtualbytes          {"Virtual Bytes"           large 1}
            virtualbytespeak      {"Virtual Bytes Peak"      large 1}
            workingset            {"Working Set"             large 1}
            workingsetpeak        {"Working Set Peak"        large 1}
        }
    }

    set optdefs {
        machine.arg
        datasource.arg
        all
        refresh
    }

    # Add counter names to option list
    foreach cntr [array names _process_counter_opt_map] {
        lappend optdefs $cntr
    }

    # Parse options
    array set opts [parseargs args $optdefs -nulldefault]

    # Force a refresh of object items
    if {$opts(refresh)} {
        # Silently ignore. The above counters are predefined and refreshing
        # is just a time-consuming no-op. Keep the option for backward
        # compatibility
        if {0} {
            _refresh_perf_objects $opts(machine) $opts(datasource)
        }
    }

    # TBD - could we not use get_perf_instance_counter_paths instead of rest of this code

    # Get the path to the process.
    set pid_paths [get_perf_counter_paths \
                       [_localize_perf_counter "Process"] \
                       [list [_localize_perf_counter "ID Process"]] \
                       $pids \
                       -machine $opts(machine) -datasource $opts(datasource) \
                       -all]

    if {[llength $pid_paths] == 0} {
        # No thread
        return [list ]
    }

    # Construct the requested counter paths
    set counter_paths [list ]
    foreach {pid pid_path} $pid_paths {

        # We have to filter out an entry for _Total which might be present
        # if pid includes "0"
        # TBD - does _Total need to be localized?
        if {$pid == 0 && [string match -nocase *_Total\#0* $pid_path]} {
            continue
        }

        # Break it down into components and store in array
        array set path_components [parse_perf_counter_path $pid_path]

        # Construct counter paths for this pid
        foreach {opt counter_info} [array get _process_counter_opt_map] {
            if {$opts(all) || $opts($opt)} {
                lappend counter_paths \
                    [list -$opt $pid [lindex $counter_info 1] \
                         [make_perf_counter_path $path_components(object) \
                              [_localize_perf_counter [lindex $counter_info 0]] \
                              -machine $path_components(machine) \
                              -parent $path_components(parent) \
                              -instance $path_components(instance) \
                              -instanceindex $path_components(instanceindex)] \
                         [lindex $counter_info 2] \
                        ]
            }
        }                        
    }

    return $counter_paths
}


# Returns the counter path for the process with the given pid. This includes
# the pid counter path element
proc twapi::get_perf_process_id_path {pid args} {
    return [get_unique_counter_path \
                [_localize_perf_counter "Process"] \
                [_localize_perf_counter "ID Process"] $pid]
}


#
# Constructs one or more counter paths for getting thread information. 
# Returned as a list of sublists. Each sublist corresponds to a counter path 
# and has the form {counteroptionname datatype counterpath rate}
# datatype is the recommended format when retrieving counter value (eg. double)
# rate is 0 or 1 depending on whether the counter is a rate based counter or 
# not (requires at least two readings when getting the value)
proc twapi::get_perf_thread_counter_paths {tids args} {
    variable _thread_counter_opt_map

    if {![info exists _thread_counter_opt_map]} {
        array set _thread_counter_opt_map {
            privilegedutilization {"% Privileged Time"       double 1}
            processorutilization  {"% Processor Time"        double 1}
            userutilization       {"% User Time"             double 1}
            contextswitchrate     {"Context Switches/sec"    long 1}
            elapsedtime           {"Elapsed Time"            large 0}
            pid                   {"ID Process"              long 0}
            tid                   {"ID Thread"               long 0}
            basepriority          {"Priority Base"           long 0}
            priority              {"Priority Current"        long 0}
            startaddress          {"Start Address"           large 0}
            state                 {"Thread State"            long 0}
            waitreason            {"Thread Wait Reason"      long 0}
        }
    }

    set optdefs {
        machine.arg
        datasource.arg
        all
        refresh
    }

    # Add counter names to option list
    foreach cntr [array names _thread_counter_opt_map] {
        lappend optdefs $cntr
    }

    # Parse options
    array set opts [parseargs args $optdefs -nulldefault]

    # Force a refresh of object items
    if {$opts(refresh)} {
        # Silently ignore. The above counters are predefined and refreshing
        # is just a time-consuming no-op. Keep the option for backward
        # compatibility
        if {0} {
            _refresh_perf_objects $opts(machine) $opts(datasource)
        }
    }

    # TBD - could we not use get_perf_instance_counter_paths instead of rest of this code

    # Get the path to the thread
    set tid_paths [get_perf_counter_paths \
                       [_localize_perf_counter "Thread"] \
                       [list [_localize_perf_counter "ID Thread"]] \
                       $tids \
                      -machine $opts(machine) -datasource $opts(datasource) \
                      -all]
    
    if {[llength $tid_paths] == 0} {
        # No thread
        return [list ]
    }

    # Now construct the requested counter paths
    set counter_paths [list ]
    foreach {tid tid_path} $tid_paths {
        # Break it down into components and store in array
        array set path_components [parse_perf_counter_path $tid_path]
        foreach {opt counter_info} [array get _thread_counter_opt_map] {
            if {$opts(all) || $opts($opt)} {
                lappend counter_paths \
                    [list -$opt $tid [lindex $counter_info 1] \
                         [make_perf_counter_path $path_components(object) \
                              [_localize_perf_counter [lindex $counter_info 0]] \
                              -machine $path_components(machine) \
                              -parent $path_components(parent) \
                              -instance $path_components(instance) \
                              -instanceindex $path_components(instanceindex)] \
                         [lindex $counter_info 2]
                    ]
            }
        }                            
    }

    return $counter_paths
}


# Returns the counter path for the thread with the given tid. This includes
# the tid counter path element
proc twapi::get_perf_thread_id_path {tid args} {

    return [get_unique_counter_path [_localize_perf_counter"Thread"] [_localize_perf_counter "ID Thread"] $tid]
}


#
# Constructs one or more counter paths for getting processor information. 
# Returned as a list of sublists. Each sublist corresponds to a counter path 
# and has the form {counteroptionname datatype counterpath rate}
# datatype is the recommended format when retrieving counter value (eg. double)
# rate is 0 or 1 depending on whether the counter is a rate based counter or 
# not (requires at least two readings when getting the value)
# $processor should be the processor number or "" to get total
proc twapi::get_perf_processor_counter_paths {processor args} {
    variable _processor_counter_opt_map

    if {![string is integer -strict $processor]} {
        if {[string length $processor]} {
            error "Processor id must be an integer or null to retrieve information for all processors"
        }
        set processor "_Total"
    }

    if {![info exists _processor_counter_opt_map]} {
        array set _processor_counter_opt_map {
            dpcutilization        {"% DPC Time"              double 1}
            interruptutilization  {"% Interrupt Time"        double 1}
            privilegedutilization {"% Privileged Time"       double 1}
            processorutilization  {"% Processor Time"        double 1}
            userutilization       {"% User Time"             double 1}
            apcbypassrate         {"APC Bypasses/sec"        double 1}
            dpcbypassrate         {"DPC Bypasses/sec"        double 1}
            dpcrate               {"DPC Rate"                double 1}
            dpcqueuerate          {"DPCs Queued/sec"         double 1}
            interruptrate         {"Interrupts/sec"          double 1}
        }
    }

    set optdefs {
        machine.arg
        datasource.arg
        all
        refresh
    }

    # Add counter names to option list
    foreach cntr [array names _processor_counter_opt_map] {
        lappend optdefs $cntr
    }

    # Parse options
    array set opts [parseargs args $optdefs -nulldefault -maxleftover 0]

    # Force a refresh of object items
    if {$opts(refresh)} {
        # Silently ignore. The above counters are predefined and refreshing
        # is just a time-consuming no-op. Keep the option for backward
        # compatibility
        if {0} {
            _refresh_perf_objects $opts(machine) $opts(datasource)
        }
    }

    # Now construct the requested counter paths
    set counter_paths [list ]
    foreach {opt counter_info} [array get _processor_counter_opt_map] {
        if {$opts(all) || $opts($opt)} {
            lappend counter_paths \
                [list $opt $processor [lindex $counter_info 1] \
                     [make_perf_counter_path \
                          [_localize_perf_counter "Processor"] \
                          [_localize_perf_counter [lindex $counter_info 0]] \
                          -machine $opts(machine) \
                          -instance $processor] \
                     [lindex $counter_info 2] \
                    ]
        }
    }

    return $counter_paths
}



#
# Returns a list comprising of the counter paths for counters with
# names in the list $counters from those instance(s) whose counter
# $key_counter matches the specified $key_counter_value
proc twapi::get_perf_instance_counter_paths {object counters
                                             key_counter key_counter_values
                                             args} {
    # Parse options
    array set opts [parseargs args {
        machine.arg
        datasource.arg
        {matchop.arg "exact"}
        skiptotal.bool
        refresh
    } -nulldefault]

    # Force a refresh of object items
    if {$opts(refresh)} {
        _refresh_perf_objects $opts(machine) $opts(datasource)
    }

    # Get the list of instances that have the specified value for the
    # key counter
    set instance_paths [get_perf_counter_paths $object \
                            [list $key_counter] $key_counter_values \
                            -machine $opts(machine) \
                            -datasource $opts(datasource) \
                            -matchop $opts(matchop) \
                            -skiptotal $opts(skiptotal) \
                            -all]

    # Loop through all instance paths, and all counters to generate 
    # We store in an array to get rid of duplicates
    array set counter_paths {}
    foreach {key_counter_value instance_path} $instance_paths {
        # Break it down into components and store in array
        array set path_components [parse_perf_counter_path $instance_path]

        # Now construct the requested counter paths
        foreach counter $counters {
            set counter_path \
                [make_perf_counter_path $path_components(object) \
                     $counter \
                     -machine $path_components(machine) \
                     -parent $path_components(parent) \
                     -instance $path_components(instance) \
                     -instanceindex $path_components(instanceindex)]
            set counter_paths($counter_path) ""
        }                            
    }

    return [array names counter_paths]


}


#
# Returns a list comprising of the counter paths for all counters
# whose values match the specified criteria
proc twapi::get_perf_counter_paths {object counters counter_values args} {
    array set opts [parseargs args {
        machine.arg
        datasource.arg
        {matchop.arg "exact"}
        skiptotal.bool
        all
        refresh
    } -nulldefault]

    if {$opts(refresh)} {
        _refresh_perf_objects $opts(machine) $opts(datasource)
    }

    set items [get_perf_object_items $object \
                   -machine $opts(machine) \
                   -datasource $opts(datasource)]
    foreach {object_counters object_instances} $items {break}

    if {[llength $counters]} {
        set object_counters $counters
    }
    set paths [_make_counter_path_list \
                   $object $object_instances $object_counters \
                   -skiptotal $opts(skiptotal) -machine $opts(machine)]
    set result_paths [list ]
    try {
        # Set up the query with the process id for all processes
        set hquery [open_perf_query -datasource $opts(datasource)]
        foreach path $paths {
            set hcounter [add_perf_counter $hquery $path]
            set lookup($hcounter) $path
        }

        # Now collect the info
        collect_perf_query_data $hquery
        
        # Now lookup each counter value to find a matching one
        foreach hcounter [array names lookup] {
            if {! [get_hcounter_value $hcounter -var value]} {
                # Counter or instance no longer exists
                continue
            }

            #puts "$lookup($hcounter): $value"
            set match_pos [lsearch -$opts(matchop) $counter_values $value]
            if {$match_pos >= 0} {
                lappend result_paths \
                    [lindex $counter_values $match_pos] $lookup($hcounter)
                if {! $opts(all)} {
                    break
                }
            }
        }
    } finally {
        # TBD - should we have a catch to throw errors?
        foreach hcounter [array names lookup] {
            remove_perf_counter $hcounter
        }
        close_perf_query $hquery
    }

    return $result_paths
}


#
# Returns the counter path for counter $counter with a value $value
# for object $object. Returns "" on no matches but exception if more than one
proc twapi::get_unique_counter_path {object counter value args} {
    set matches [eval [list get_perf_counter_paths $object [list $counter ] [list $value]] $args -all]
    if {[llength $matches] > 1} {
        error "Multiple counter paths found matching criteria object='$object' counter='$counter' value='$value"
    }
    return [lindex $matches 0]
}



#
# Utilities
# 
proc twapi::_refresh_perf_objects {machine datasource} {
    get_perf_objects -refresh
    return
}


#
# Return the localized form of a counter name
# TBD - assumes machine is local machine!
proc twapi::_localize_perf_counter {name} {
    variable _perf_counter_ids
    variable _localized_perf_counter_names
    
    set name_index [string tolower $name]

    # If we already have a translation, return it
    if {[info exists _localized_perf_counter_names($name_index)]} {
        return $_localized_perf_counter_names($name_index)
    }

    # TBD - windows NT 4.0 does not have the PdhLookup* functions
    if {! [min_os_version 5]} {
        set _localized_perf_counter_names($name_index) $name
        return $name
    }

    # Didn't already have it. Go generate the mappings

    # Get the list of counter names in English if we don't already have it
    if {![info exists _perf_counter_ids]} {
        foreach {id label} [registry get {HKEY_PERFORMANCE_DATA} {Counter 009}] {
            set _perf_counter_ids([string tolower $label]) $id
        }
    }

    # If we have do not have id for the given name, we will just use
    # the passed name as the localized version
    if {! [info exists _perf_counter_ids($name_index)]} {
        # Does not seem to exist. Just set localized name to itself
        return [set _localized_perf_counter_names($name_index) $name]
    }

    # We do have an id. THen try to get a translated name
    if {[catch {PdhLookupPerfNameByIndex "" $_perf_counter_ids($name_index)} xname]} {
        set _localized_perf_counter_names($name_index) $name
    } else {
        set _localized_perf_counter_names($name_index) $xname
    }

    return $_localized_perf_counter_names($name_index)
}


# Given a list of instances and counters, return a cross product of the 
# corresponding counter paths.
# Example: _make_counter_path_list "Process" (instance list) {{ID Process} {...}}
# TBD - bug - does not handle -parent in counter path
proc twapi::_make_counter_path_list {object instance_list counter_list args} {
    array set opts [parseargs args {
        machine.arg
        skiptotal.bool
    } -nulldefault]

    array set instances {}
    foreach instance $instance_list {
        if {![info exists instances($instance)]} {
            set instances($instance) 1
        } else {
            incr instances($instance)
        }
    }

    if {$opts(skiptotal)} {
        # TBD - does this need to be localized
        catch {array unset instances "*_Total"}
    }

    set counter_paths [list ]
    foreach {instance count} [array get instances] {
        while {$count} {
            incr count -1
            foreach counter $counter_list {
                lappend counter_paths [make_perf_counter_path \
                                           $object $counter \
                                           -machine $opts(machine) \
                                           -instance $instance \
                                           -instanceindex $count]
            }
        }
    }

    return $counter_paths
}


#
# Given a set of counter paths in the format returned by 
# get_perf_thread_counter_paths, get_perf_processor_counter_paths etc.
# return the counter information as a flat list of field value pairs
proc twapi::get_perf_values_from_metacounter_info {metacounters args} {
    array set opts [parseargs args {{interval.int 100}}]

    set result [list ]
    set counters [list ]
    if {[llength $metacounters]} {
        set hquery [open_perf_query]
        try {
            set counter_info [list ]
            set need_wait 0
            foreach counter_elem $metacounters {
                foreach {pdh_opt key data_type counter_path wait} $counter_elem {break}
                incr need_wait $wait
                set hcounter [add_perf_counter $hquery $counter_path]
                lappend counters $hcounter
                lappend counter_info $pdh_opt $key $counter_path $data_type $hcounter
            }
            
            collect_perf_query_data $hquery
            if {$need_wait} {
                after $opts(interval)
                collect_perf_query_data $hquery
            }
            
            foreach {pdh_opt key counter_path data_type hcounter} $counter_info {
                if {[get_hcounter_value $hcounter -format $data_type -var value]} {
                    lappend result $pdh_opt $key $value
                }
            }
        } onerror {} {
            #puts "Error: $msg"
        } finally {
            foreach hcounter $counters {
                remove_perf_counter $hcounter
            }
            close_perf_query $hquery
        }
    }

    return $result

}

