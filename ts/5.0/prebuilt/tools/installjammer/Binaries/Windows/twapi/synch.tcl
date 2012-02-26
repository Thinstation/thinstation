#
# Copyright (c) 2004, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

namespace eval twapi {
}

#
# Create and return a handle to a mutex
proc twapi::create_mutex {args} {
    array set opts [parseargs args {
        {name.arg ""}
        {secd.arg ""}
        {inherit.bool 0}
        lock
    }]

    return [CreateMutex [_make_secattr $opts(secd) $opts(inherit)] $opts(lock) $opts(name)]
}

# Get handle to an existing mutex
proc twapi::get_mutex_handle {name args} {
    array set opts [parseargs args {
        {inherit.bool 0}
        {access.arg {mutex_all_access}}
    }]
    
    return [OpenMutex [_access_rights_to_mask $opts(access)] $opts(inherit) $name]
}

# Lock the mutex
proc twapi::lock_mutex {h args} {
    array set opts [parseargs args {
        {wait.int 1000}
    }]

    return [wait_on_handles [list $h] -wait $opts(wait)]
}


# Unlock the mutex
proc twapi::unlock_mutex {h} {
    ReleaseMutex $h
}

#
# Wait on multiple handles
proc twapi::wait_on_handles {hlist args} {
    array set opts [parseargs args {
        {all.bool 0}
        {wait.int 1000}
    }]

    return [WaitForMultipleObjects $hlist $opts(all) $opts(wait)]
}
