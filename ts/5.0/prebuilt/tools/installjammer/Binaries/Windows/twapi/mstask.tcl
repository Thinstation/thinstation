#
# Copyright (c) 2006 Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

# Task scheduler API

namespace eval twapi {
    variable CLSID_ITaskScheduler {{148BD52A-A2AB-11CE-B11F-00AA00530503}}
    variable CLSID_ITask          {{148BD520-A2AB-11CE-B11F-00AA00530503}}
}

#
# Return an instance of the task scheduler
proc twapi::itaskscheduler_new {args} {
    array set opts [parseargs args {
        system.arg
    } -maxleftover 0]

    # Get ITaskScheduler interface
    set its [Twapi_CoCreateInstance $twapi::CLSID_ITaskScheduler NULL 1 [name_to_iid ITaskScheduler] ITaskScheduler]
    if {![info exists opts(system)]} {
        return $its
    }
    try {
        itaskscheduler_set_target_system $its $opts(system)
    } onerror {} {
        iunknown_release $its
        # Rethrow the original error
        error $errorResult $errorInfo $errorCode
    }
    return $its
}

interp alias {} ::twapi::itaskscheduler_release {} ::twapi::iunknown_release

# Return a new task interface
proc twapi::itaskscheduler_new_itask {its taskname} {
    set iid_itask [name_to_iid ITask]
    set iunk [ITaskScheduler_NewWorkItem $its $taskname $twapi::CLSID_ITask $iid_itask]
    try {
        set itask [IUnknown_QueryInterface $iunk $iid_itask ITask]
    } finally {
        iunknown_release $iunk
    }
    return $itask
}

#
# Get an existing task
proc twapi::itaskscheduler_get_itask {its taskname} {
    set iid_itask [name_to_iid ITask]
    set iunk [ITaskScheduler_Activate $its $taskname $iid_itask]
    try {
        set itask [IUnknown_QueryInterface $iunk $iid_itask ITask]
    } finally {
        iunknown_release $iunk
    }
    return $itask
}

#
# Deletes an existing task
interp alias {} ::twapi::itaskscheduler_delete_task {} ::twapi::ITaskScheduler_Delete

#
# Check if an itask exists
proc twapi::itaskscheduler_task_exists {its taskname} {
    return [expr {[ITaskScheduler_IsOfType $its $taskname [name_to_iid ITask]] == 0 ? true : false}]
}

#
# Set the target computer for a task
interp alias {} ::twapi::itaskscheduler_set_target_system {} ::twapi::ITaskScheduler_SetTargetComputer

# Get the target computer for a task
interp alias {} ::twapi::itaskscheduler_get_target_system {} ::twapi::ITaskScheduler_GetTargetComputer

#
# Return list of tasks
proc twapi::itaskscheduler_get_tasks {its} {
    set ienum [ITaskScheduler_Enum $its]
    try {
        set result [list ]
        set more 1
        while {$more} {
            foreach {more items} [IEnumWorkItems_Next $ienum 20] break
            set result [concat $result $items]
        }
    } finally {
        iunknown_release $ienum
    }
    return $result
}

# Sets the specified properties of the ITask
proc twapi::itask_configure {itask args} {

    array set opts [parseargs args {
        application.arg
        maxruntime.int
        params.arg
        priority.arg
        workingdir.arg
        account.arg
        password.arg
        comment.arg
        creator.arg
        data.arg
        idlewait.int
        idlewaitdeadline.int
        interactive.bool
        deletewhendone.bool
        disabled.bool
        hidden.bool
        runonlyifloggedon.bool
        startonlyifidle.bool
        resumesystem.bool
        killonidleend.bool
        restartonidleresume.bool
        donstartonbatteries.bool
        killifonbatteries.bool
    } -maxleftover 0]

    if {[info exists opts(priority)]} {
        switch -exact -- $opts(priority) {
            normal      {set opts(priority) 0x00000020}
            abovenormal {set opts(priority) 0x00008000}
            belownormal {set opts(priority) 0x00004000}
            high        {set opts(priority) 0x00000080}
            realtime    {set opts(priority) 0x00000100}
            idle        {set opts(priority) 0x00000040}
            default     {error "Unknown priority '$opts(priority)'. Must be one of 'normal', 'high', 'idle' or 'realtime'"}
        }
    }

    foreach {opt fn} {
        application ITask_SetApplicationName
        maxruntime  ITask_SetMaxRunTime
        params      ITask_SetParameters
        workingdir  ITask_SetWorkingDirectory
        priority    ITask_SetPriority
        comment            IScheduledWorkItem_SetComment
        creator            IScheduledWorkItem_SetCreator
        data               IScheduledWorkItem_SetWorkItemData
        errorretrycount    IScheduledWorkItem_SetErrorRetryCount
        errorretryinterval IScheduledWorkItem_SetErrorRetryInterval
    } {
        if {[info exists opts($opt)]} {
            $fn  $itask $opts($opt)
        }
    }

    if {[info exists opts(account)]} {
        if {$opts(account) ne ""} {
            if {![info exists opts(password)]} {
                error "Option -password must be specified if -account is specified"
            }
        } else {
            # System account. Set password to NULL pointer indicated
            # by magic null pointer
            set opts(password) $::twapi::nullptr
        }
        IScheduledWorkItem_SetAccountInformation $itask $opts(account) $opts(password)
    }

    if {[info exists opts(idlewait)] || [info exists opts(idlewaitdeadline)]} {
        # If either one is not specified, get the current settings
        if {! ([info exists opts(idlewait)] &&
               [info exists opts(idlewaitdeadline)]) } {
            foreach {idle dead} [IScheduledWorkItem_GetIdleWait $itask] break
            if {![info exists opts(idlewait)]} {
                set opts(idlewait) $idle
            }
            if {![info exists opts(idlewaitdeadline)]} {
                set opts(idlewaitdeadline) $dead
            }
        }
        IScheduledWorkItem_SetIdleWait $itask $opts(idlewait) $opts(idlewaitdeadline)
    }

    # Finally figure out and set the flags if needed
    if {[info exists opts(interactive)] ||
        [info exists opts(deletewhendone)] ||
        [info exists opts(disabled)] ||
        [info exists opts(hidden)] ||
        [info exists opts(runonlyifloggedon)] ||
        [info exists opts(startonlyifidle)] ||
        [info exists opts(resumesystem)] ||
        [info exists opts(killonidleend)] ||
        [info exists opts(restartonidleresume)] ||
        [info exists opts(donstartonbatteries)] ||
        [info exists opts(killifonbatteries)]} {

        # First, get the current flags
        set flags [IScheduledWorkItem_GetFlags $itask]
        foreach {opt val} {
            interactive         0x1
            deletewhendone      0x2
            disabled            0x4
            startonlyifidle     0x10
            hidden              0x200
            runonlyifloggedon   0x2000
            resumesystem        0x1000
            killonidleend       0x20
            restartonidleresume 0x800
            donstartonbatteries 0x40
            killifonbatteries   0x80
        } {
            # Set / reset the bit if specified
            if {[info exists opts($opt)]} {
                if {$opts($opt)} {
                    setbits flags $opts($opt)
                } else {
                    resetbits flags $opts($opt)
                }
            }
        }

        # Now set the new value of flags
        IScheduledWorkItem_SetFlags $itask $flags
    }


    return
}

proc twapi::itask_get_info {itask args} {
    # Note options errorretrycount and errorretryinterval are not implemented
    # by the OS so left out
    array set opts [parseargs args {
        all
        application
        maxruntime
        params
        priority
        workingdir
        account
        comment
        creator
        data
        idlewait
        idlewaitdeadline
        interactive
        deletewhendone
        disabled
        hidden
        runonlyifloggedon
        startonlyifidle
        resumesystem
        killonidleend
        restartonidleresume
        donstartonbatteries
        killifonbatteries
        lastruntime
        nextruntime
        status
    } -maxleftover 0]

    set result [list ]
    if {$opts(all) || $opts(priority)} {
        switch -exact -- [twapi::ITask_GetPriority $itask] {
            32    { set priority normal }
            64    { set priority idle }
            128   { set priority high }
            256   { set priority realtime }
            16384 { set priority belownormal }
            32768 { set priority abovenormal }
            default { set priority unknown }
        }
        lappend result -priority $priority
    }

    foreach {opt fn} {
        application ITask_GetApplicationName
        maxruntime  ITask_GetMaxRunTime
        params      ITask_GetParameters
        workingdir  ITask_GetWorkingDirectory
        account            IScheduledWorkItem_GetAccountInformation
        comment            IScheduledWorkItem_GetComment
        creator            IScheduledWorkItem_GetCreator
        data               IScheduledWorkItem_GetWorkItemData
    } {
        if {$opts(all) || $opts($opt)} {
            lappend result -$opt [$fn  $itask]
        }
    }
    
    if {$opts(all) || $opts(lastruntime)} {
        try {
            lappend result -lastruntime [_timelist_to_timestring [IScheduledWorkItem_GetMostRecentRunTime $itask]]
        } onerror {TWAPI_WIN32 267011} {
            # Not run yet at all
            lappend result -lastruntime {}
        }
    }

    if {$opts(all) || $opts(nextruntime)} {
        try {
            lappend result -nextruntime [_timelist_to_timestring [IScheduledWorkItem_GetNextRunTime $itask]]
        } onerror {TWAPI_WIN32 267010} {
            # Task is disabled
            lappend result -nextruntime disabled
        } onerror {TWAPI_WIN32 267015} {
            # No triggers set
            lappend result -nextruntime notriggers
        } onerror {TWAPI_WIN32 267016} {
            # No triggers set
            lappend result -nextruntime oneventonly
        }
    }

    if {$opts(all) || $opts(status)} {
        set status [IScheduledWorkItem_GetStatus $itask]
        if {$status == 0x41300} {
            set status ready
        } elseif {$status == 0x41301} {
            set status running
        } elseif {$status == 0x41302} {
            set status disabled
        } elseif {$status == 0x41305} {
            set status partiallydefined
        } else {
            set status unknown
        }
        lappend result -status $status
    }


    if {$opts(idlewait) || $opts(idlewaitdeadline)} {
        foreach {idle dead} [IScheduledWorkItem_GetIdleWait $itask] break
        if {$opts(idlewait)} {
            lappend result -idlewait $idle
        }
        if {$opts(idlewaitdeadline)} {
            lappend result -idlewaitdeadline $dead
        }
    }

    # Finally figure out and set the flags if needed
    if {$opts(interactive) ||
        $opts(deletewhendone) ||
        $opts(disabled) ||
        $opts(hidden) ||
        $opts(runonlyifloggedon) ||
        $opts(startonlyifidle) ||
        $opts(resumesystem) ||
        $opts(killonidleend) ||
        $opts(restartonidleresume) ||
        $opts(donstartonbatteries) ||
        $opts(killifonbatteries)} {

        # First, get the current flags
        set flags [IScheduledWorkItem_GetFlags $itask]
        foreach {opt val} {
            interactive         0x1
            deletewhendone      0x2
            disabled            0x4
            startonlyifidle     0x10
            hidden              0x200
            runonlyifloggedon   0x2000
            resumesystem        0x1000
            killonidleend       0x20
            restartonidleresume 0x800
            donstartonbatteries 0x40
            killifonbatteries   0x80
        } {
            if {$opts($opt)} {
                lappend result $opt [expr {($flags & $val) ? true : false}]
            }
        }
    }


    return $result
}

#
# Get the runtimes for a task within an interval
proc twapi::itask_get_runtimes_within_interval {itask args} {
    array set opts [parseargs args {
        start.arg
        end.arg
        {count.int 1}
        statusvar.arg
    } -maxleftover 0]

    if {[info exists opts(start)]} {
        set start [_timestring_to_timelist $opts(start)]
    } else {
        set start [_seconds_to_timelist [clock seconds]]
    }
    if {[info exists opts(end)]} {
        set end [_timestring_to_timelist $opts(end)]
    } else {
        set end {2038 1 1 0 0 0 0}
    }
    
    set result [list ]
    if {[info exists opts(statusvar)]} {
        upvar $opts(statusvar) status
    }
    foreach {status timelist} [IScheduledWorkItem_GetRunTimes $itask $start $end $opts(count)] break

    foreach time $timelist {
        lappend result [_timelist_to_timestring $time]
    }


    return $result
}

#
# Run a task
interp alias {} ::twapi::itask_run {} ::twapi::IScheduledWorkItem_Run

#
# Terminate a task
interp alias {} ::twapi::itask_end {} ::twapi::IScheduledWorkItem_Terminate

#
# Saves the specified ITask
proc twapi::itask_save {itask} {
    set ipersist [iunknown_query_interface $itask IPersistFile]
    try {
        IPersistFile_Save $ipersist "" 1
    } finally {
        iunknown_release $ipersist
    }
    return
}

#
# Show property editor for a task
proc twapi::itask_edit_dialog {itask args} {
    array set opts [parseargs args {
        {hwin.arg 0}
    } -maxleftover 0]

    return [twapi::IScheduledWorkItem_EditWorkItem $itask $opts(hwin)]
}


#
# Create a new trigger. Returns {index interfaceptr}
interp alias {} ::twapi::itask_new_itasktrigger {} ::twapi::IScheduledWorkItem_CreateTrigger

#
# Delete a trigger
interp alias {} ::twapi::itask_delete_itasktrigger {} ::twapi::IScheduledWorkItem_DeleteTrigger

interp alias {} ::twapi::itask_release {} ::twapi::iunknown_release

#
# Get an existing trigger for the task
proc twapi::itask_get_itasktrigger {itask index} {
    return [IScheduledWorkItem_GetTrigger $itask $index]
}

#
# Get number of triggers in a task
proc twapi::itask_get_itasktrigger_count {itask} {
    return [IScheduledWorkItem_GetTriggerCount $itask]
}

#
# Get the trigger string description
interp alias {} ::twapi::twapi::itask_get_itasktrigger_string {} ::twapi::IScheduledWorkItem_GetTriggerString

#
# Get information about a trigger
proc twapi::itasktrigger_get_info {itt} {
    array set data [ITaskTrigger_GetTrigger $itt]

    set result(-begindate) "$data(wBeginYear)-$data(wBeginMonth)-$data(wBeginDay)"

    set result(-starttime) "$data(wStartHour):$data(wStartMinute)"

    if {$data(rgFlags) & 1} {
        set result(-enddate) "$data(wEndYear)-$data(wEndMonth)-$data(wEndDay)"
    } else {
        set result(-enddate) ""
    }

    set result(-duration) $data(MinutesDuration)
    set result(-interval) $data(MinutesInterval)
    if {$data(rgFlags) & 2} {
        set result(-killatdurationend) true
    } else {
        set result(-killatdurationend) false
    }

    if {$data(rgFlags) & 4} {
        set result(-disabled) true
    } else {
        set result(-disabled) false
    }

    switch -exact -- [lindex $data(type) 0] {
        0 {
            set result(-type) once
        }
        1 {
            set result(-type) daily
            set result(-period) [lindex $data(type) 1]
        }
        2 {
            set result(-type) weekly
            set result(-period) [lindex $data(type) 1]
            set result(-weekdays) [format 0x%x [lindex $data(type) 2]]
        }
        3 {
            set result(-type) monthlydate
            set result(-daysofmonth) [format 0x%x [lindex $data(type) 1]]
            set result(-months) [format 0x%x [lindex $data(type) 2]]
        }
        4 {
            set result(-type) monthlydow
            set result(-weekofmonth) [lindex {first second third fourth last} [lindex $data(type) 2]]
            set result(-weekdays) [format 0x%x [lindex $data(type) 2]]
            set result(-months) [format 0x%x [lindex $data(type) 3]]
        }
        5 {
            set result(-type) onidle
        }
        6 {
            set result(-type) atsystemstart
        }
        7 {
            set result(-type) atlogon
        }
    }
    return [array get result]
}


#
# Configure a task trigger
proc twapi::itasktrigger_configure {itt args} {
    array set opts [parseargs args {
        begindate.arg
        enddate.arg
        starttime.arg
        interval.int
        duration.int
        killatdurationend.bool
        disabled.bool
        type.arg
        weekofmonth.int
        {period.int 1}
        {weekdays.int 0x7f}
        {daysofmonth.int 0x7fffffff}
        {months.int 0xfff}
    } -maxleftover 0]


    array set data [ITaskTrigger_GetTrigger $itt]

    if {[info exists opts(begindate)]} {
        foreach {year month day} [split $opts(begindate) -] break
        # Note we trim leading zeroes else Tcl thinks its octal
        set data(wBeginYear) [scan $year %d]
        set data(wBeginMonth) [scan $month %d]
        set data(wBeginDay) [scan $day %d]
    }

    if {[info exists opts(starttime)]} {
        foreach {hour minute} [split $opts(starttime) :] break
        # Note we trim leading zeroes else Tcl thinks its octal
        set data(wStartHour) [scan $hour %d]
        set data(wStartMinute) [scan $minute %d]
    }

    if {[info exists opts(enddate)]} {
        if {$opts(enddate) ne ""} {
            setbits data(rgFlags) 1;        # Indicate end date is present
            foreach {year month day} [split $opts(enddate) -] break
            # Note we trim leading zeroes else Tcl thinks its octal
            set data(wEndYear) [scan $year %d]
            set data(wEndMonth) [scan $month %d]
            set data(wEndDay) [scan $day %d]
        } else {
            resetbits data(rgFlags) 1;  # Indicate no end date
        }
    }
        

    if {[info exists opts(duration)]} {
        set data(MinutesDuration) $opts(duration)
    }

    if {[info exists opts(interval)]} {
        set data(MinutesInterval) $opts(interval)
    }

    if {[info exists opts(killatdurationend)]} {
        if {$opts(killatdurationend)} {
            setbits data(rgFlags) 2
        } else {
            resetbits data(rgFlags) 2
        }
    }

    if {[info exists opts(disabled)]} {
        if {$opts(disabled)} {
            setbits data(rgFlags) 4
        } else {
            resetbits data(rgFlags) 4
        }
    }

    # Note the type specific options are only used if -type is specified
    if {[info exists opts(type)]} {
        switch -exact -- $opts(type) {
            once {
                set data(type) [list 0]
            }
            daily {
                set data(type) [list 1 $opts(period)]
            }
            weekly {
                set data(type) [list 2 $opts(period) $opts(weekdays)]
            }
            monthlydate {
                set data(type) [list 3 $opts(daysofmonth) $opts(months)]
            }
            monthlydow {
                set data(type) [list 4 $opts(weekofmonth) $opts(weekdays) $opts(months)]
            }
            onidle {
                set data(type) [list 5]
            }
            atsystemstart {
                set data(type) [list 6]
            }
            atlogon {
                set data(type) [list 7]
            }
        }
    }

    ITaskTrigger_SetTrigger $itt [array get data]
    return
}

interp alias {} ::twapi::itasktrigger_release {} ::twapi::iunknown_release

#
# Create a new task from scratch. Basically a wrapper around the
# corresponding itaskscheduler, itask and itasktrigger calls
proc twapi::mstask_create {taskname args} {
    
    # The options are a combination of itask_configure and
    # itasktrigger_configure
    array set opts [parseargs args {
        system.arg
        application.arg
        maxruntime.int
        params.arg
        priority.arg
        workingdir.arg
        account.arg
        password.arg
        comment.arg
        creator.arg
        data.arg
        idlewait.int
        idlewaitdeadline.int
        interactive.bool
        deletewhendone.bool
        disabled.bool
        hidden.bool
        runonlyifloggedon.bool
        startonlyifidle.bool
        resumesystem.bool
        killonidleend.bool
        restartonidleresume.bool
        donstartonbatteries.bool
        killifonbatteries.bool
        begindate.arg
        enddate.arg
        starttime.arg
        interval.int
        duration.int
        killatdurationend.bool
        type.arg
        period.int
        weekdays.int
        daysofmonth.int
        months.int
    } -maxleftover 0]

    set its [itaskscheduler_new]
    try {
        if {[info exists opts(system)]} {
            itaskscheduler_set_target_system $opts(system)
        }

        set itask [itaskscheduler_new_itask $its $taskname]
        # Construct the command line for configuring the task
        set cmd [list itask_configure $itask]
        foreach opt {
            application
            maxruntime
            params
            priority
            workingdir
            account
            password
            comment
            creator
            data
            idlewait
            idlewaitdeadline
            interactive
            deletewhendone
            disabled
            hidden
            runonlyifloggedon
            startonlyifidle
            resumesystem
            killonidleend
            restartonidleresume
            donstartonbatteries
            killifonbatteries
        } {
            if {[info exists opts($opt)]} {
                lappend cmd -$opt $opts($opt)
            }
        }        
        eval $cmd

        # Now get a trigger and configure it
        set itt [lindex [itask_new_itasktrigger $itask] 1]
        set cmd [list itasktrigger_configure $itt -disabled false]
        foreach opt {
            begindate
            enddate
            interval
            starttime
            duration
            killatdurationend
            type
            period
            weekdays
            daysofmonth
            months
        } {
            if {[info exists opts($opt)]} {
                lappend cmd -$opt $opts($opt)
            }
        }
        eval $cmd

        # Save the task
        itask_save $itask

    } finally {
        iunknown_release $its
        if {[info exists itask]} {
            iunknown_release $itask
        }
        if {[info exists $itt]} {
            iunknown_release $itt
        }
    }
    return
}

#
# Delete a task
proc twapi::mstask_delete {taskname args} {
    # The options are a combination of itask_configure and
    # itasktrigger_configure
    array set opts [parseargs args {
        system.arg
    } -maxleftover 0]
    set its [itaskscheduler_new]
    try {
        if {[info exists opts(system)]} {
            itaskscheduler_set_target_system $opts(system)
        }
        itaskscheduler_delete_task $its $taskname
    } finally {
        iunknown_release $its
    }    
    return
}
