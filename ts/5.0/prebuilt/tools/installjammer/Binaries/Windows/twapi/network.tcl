#
# Copyright (c) 2004, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

# TBD _ maybe more information is available through PDH? Perhaps even on NT?

namespace eval twapi {

    array set IfTypeTokens {
        1  other
        6  ethernet
        9  tokenring
        15 fddi
        23 ppp
        24 loopback
        28 slip
    }

    array set IfOperStatusTokens {
        0 nonoperational
        1 wanunreachable
        2 disconnected
        3 wanconnecting
        4 wanconnected
        5 operational
    }

    # Various pieces of information come from different sources. Moreover,
    # the same information may be available from multiple APIs. In addition
    # older versions of Windows may not have all the APIs. So we try
    # to first get information from older API's whenever we have a choice
    # These tables map fields to positions in the corresponding API result.
    # -1 means rerieving is not as simple as simply indexing into a list

    # GetIfEntry is available from NT4 SP4 onwards
    array set GetIfEntry_opts {
        type                2
        mtu                 3
        speed               4
        physicaladdress     5
        adminstatus         6
        operstatus          7
        laststatuschange    8
        inbytes             9
        inunicastpkts      10
        innonunicastpkts   11
        indiscards         12
        inerrors           13
        inunknownprotocols 14
        outbytes           15
        outunicastpkts     16
        outnonunicastpkts  17
        outdiscards        18
        outerrors          19
        outqlen            20
        description        21
    }
    
    # GetIpAddrTable also exists in NT4 SP4+
    array set GetIpAddrTable_opts {
        ipaddresses -1
        ifindex     -1
        reassemblysize -1 
    }

    # Win2K and up
    array set GetAdaptersInfo_opts {
        adaptername     0
        adapterdescription     1
        adapterindex    3
        dhcpenabled     5
        defaultgateway  7
        dhcpserver      8
        havewins        9
        primarywins    10
        secondarywins  11
        dhcpleasestart 12
        dhcpleaseend   13
    }

    # Win2K and up
    array set GetPerAdapterInfo_opts {
        autoconfigenabled 0
        autoconfigactive  1
        dnsservers        2
    }

    # Win2K and up
    array set GetInterfaceInfo_opts {
        ifname  -1
    }

}

#
# Get the list of local IP addresses
proc twapi::get_ip_addresses {} {
    set addrs [list ]
    foreach entry [GetIpAddrTable] {
        set addr [lindex $entry 0]
        if {[string compare $addr "0.0.0.0"]} {
            lappend addrs $addr
        }
    }
    return $addrs
}

#
# Get the list of interfaces
proc twapi::get_netif_indices {} {
    # Win2K+ only - return [lindex [get_network_info -interfaces] 1]

    # NT4 SP4+
    set indices [list ]
    foreach entry [GetIpAddrTable] {
        lappend indices [lindex $entry 1]
    }
    return $indices
}

#
# Get network related information
proc twapi::get_network_info {args} {
    # Map options into the positions in result of GetNetworkParams
    array set getnetworkparams_opts {
        hostname     0
        domain       1
        dnsservers   2
        dhcpscopeid  4
        routingenabled  5
        arpproxyenabled 6
        dnsenabled      7
    }

    array set opts [parseargs args \
                        [concat [list all ipaddresses interfaces] \
                             [array names getnetworkparams_opts]]]
    set result [list ]
    foreach opt [array names getnetworkparams_opts] {
        if {!$opts(all) && !$opts($opt)} continue
        if {![info exists netparams]} {
            set netparams [GetNetworkParams]
        }
        lappend result -$opt [lindex $netparams $getnetworkparams_opts($opt)]
    }

    if {$opts(all) || $opts(ipaddresses) || $opts(interfaces)} {
        set addrs     [list ]
        set interfaces [list ]
        foreach entry [GetIpAddrTable] {
            set addr [lindex $entry 0]
            if {[string compare $addr "0.0.0.0"]} {
                lappend addrs $addr
            }
            lappend interfaces [lindex $entry 1]
        }
        if {$opts(all) || $opts(ipaddresses)} {
            lappend result -ipaddresses $addrs
        }
        if {$opts(all) || $opts(interfaces)} {
            lappend result -interfaces $interfaces
        }
    }

    return $result
}

proc twapi::get_netif_info {interface args} {
    variable IfTypeTokens
    variable GetIfEntry_opts
    variable GetIpAddrTable_opts
    variable GetAdaptersInfo_opts
    variable GetPerAdapterInfo_opts
    variable GetInterfaceInfo_opts
    
    array set opts [parseargs args \
                        [concat [list all unknownvalue.arg] \
                             [array names GetIfEntry_opts] \
                             [array names GetIpAddrTable_opts] \
                             [array names GetAdaptersInfo_opts] \
                             [array names GetPerAdapterInfo_opts] \
                             [array names GetInterfaceInfo_opts]]]

    array set result [list ]

    # If NT4.0 SP4 or before, NONE of this is available
    # If we don't want errors, just return unknown placeholder
    if {![min_os_version 4 0 4]} {
        if {[string length $opts(unknownvalue)]} {
            foreach opt [array names opts] {
                if {$opt == "all" || $opt == "unknownvalue"} continue
                if {$opts($opt) || $opts(all)} {
                    set result(-$opt) $opts(unknownvalue)
                }
            }
            return [array get result]
        }
        # Else we will just go on and barf when a function is not available
    }

    set nif $interface
    if {![string is integer $nif]} {
        if {![min_os_version 5]} {
            error "Interfaces must be identified by integer index values on Windows NT 4.0"
        }
        set nif [GetAdapterIndex $nif]
    }

    if {$opts(all) || $opts(ifindex)} {
        # This really is only useful if $interface had been specified as a name
        set result(-ifindex) $nif
    }

    if {$opts(all) ||
        [_array_non_zero_entry opts [array names GetIfEntry_opts]]} {
        set values [GetIfEntry $nif]
        foreach opt [array names GetIfEntry_opts] {
            if {$opts(all) || $opts($opt)} {
                set result(-$opt) [lindex $values $GetIfEntry_opts($opt)]
            }
        }
    }
    
    if {$opts(all) ||
        [_array_non_zero_entry opts [array names GetIpAddrTable_opts]]} {
        # Collect all the entries, sort by index, then pick out what
        # we want. This assumes there may be multiple entries with the
        # same ifindex
        foreach entry [GetIpAddrTable] {
            foreach {addr ifindex netmask broadcast reasmsize} $entry break
            lappend ipaddresses($ifindex) [list $addr $netmask $broadcast]
            set reassemblysize($ifindex) $reasmsize
        }
        foreach opt {ipaddresses reassemblysize} {
            if {$opts(all) || $opts($opt)} {
                if {![info exists ${opt}($nif)]} {
                    error "No interface exists with index $nif"
                }
                set result(-$opt) [set ${opt}($nif)]
            }
        }
    }

    # Remaining options only available on Win2K and up
    if {![min_os_version 5]} {
        if {[string length $opts(unknownvalue)]} {
            set win2kopts [concat [array names GetAdaptersInfo_opts] \
                               [array names GetPerAdapterInfo_opts] \
                               [array names GetInterfaceInfo_opts]]
            foreach opt $win2kopts {
                if {$opts($opt) || $opts(all)} {
                    set result(-$opt) $opts(unknownvalue)
                }
            }
            return [array get result]
        }
        # Else we will just go on and barf when a function is not available
    }

    # Proceed with win2k and above
    if {$opts(all) ||
        [_array_non_zero_entry opts [array names GetAdaptersInfo_opts]]} {
        foreach entry [GetAdaptersInfo] {
            if {$nif != [lindex $entry 3]} continue; # Different interface
            foreach opt [array names GetAdaptersInfo_opts] {
                if {$opts(all) || $opts($opt)} {
                    set result(-$opt) [lindex $entry $GetAdaptersInfo_opts($opt)]
                }
            }
        }
    }

    if {$opts(all) ||
        [_array_non_zero_entry opts [array names GetPerAdapterInfo_opts]]} {
        if {$result(-type) == 24} {
            # Loopback - we have to make this info up
            set values {0 0 {}}
        } else {
            set values [GetPerAdapterInfo $nif]
        }
        foreach opt [array names GetPerAdapterInfo_opts] {
            if {$opts(all) || $opts($opt)} {
                set result(-$opt) [lindex $values $GetPerAdapterInfo_opts($opt)]
            }
        }
    }

    if {$opts(all) || $opts(ifname)} {
        array set ifnames [eval concat [GetInterfaceInfo]]
        if {$result(-type) == 24} {
            set result(-ifname) "loopback"
        } else {
            if {![info exists ifnames($nif)]} {
                error "No interface exists with index $nif"
            }
            set result(-ifname) $ifnames($nif)
        }
    }

    # Some fields need to be translated to more mnemonic names
    if {[info exists result(-type)]} {
        if {[info exists IfTypeTokens($result(-type))]} {
            set result(-type) $IfTypeTokens($result(-type))
        } else {
            set result(-type) "other"
        }
    }
    if {[info exists result(-physicaladdress)]} {
        set result(-physicaladdress) [_hwaddr_binary_to_string $result(-physicaladdress)]
    }
    foreach opt {-primarywins -secondarywins} {
        if {[info exists result($opt)]} {
            if {[string equal $result($opt) "0.0.0.0"]} {
                set result($opt) ""
            }
        }
    }
    if {[info exists result(-operstatus)] &&
        [info exists twapi::IfOperStatusTokens($result(-operstatus))]} {
        set result(-operstatus) $twapi::IfOperStatusTokens($result(-operstatus))
    }

    return [array get result]
}

#
# Get the number of network interfaces
proc twapi::get_netif_count {} {
    return [GetNumberOfInterfaces]
}

#
# Get the address->h/w address table
proc twapi::get_arp_table {args} {
    array set opts [parseargs args {
        sort
        ifindex.int
        validonly
    }]

    set arps [list ]

    foreach arp [GetIpNetTable $opts(sort)] {
        foreach {ifindex hwaddr ipaddr type} $arp break
        if {$opts(validonly) && $type == 2} continue
        if {[info exists opts(ifindex)] && $opts(ifindex) != $ifindex} continue
        # Token for enry   0     1      2      3        4
        set type [lindex {other other invalid dynamic static} $type]
        if {$type == ""} {
            set type other
        }
        lappend arps [list $ifindex [_hwaddr_binary_to_string $hwaddr] $ipaddr $type]
    }
    return $arps
}

#
# Return IP address for a hw address
proc twapi::ipaddr_to_hwaddr {ipaddr {varname ""}} {
    foreach arp [GetIpNetTable] {
        if {[lindex $arp 3] == 2} continue;       # Invalid entry type
        if {[string equal $ipaddr [lindex $arp 2]]} {
            set result [_hwaddr_binary_to_string [lindex $arp 1]]
            break
        }
    }

    # If could not get from ARP table, see if it is one of our own
    # Ignore errors
    if {![info exists result]} {
        foreach ifindex [get_netif_indices] {
            catch {
                array set netifinfo [get_netif_info $ifindex -ipaddresses -physicaladdress]
                # Search list of ipaddresses
                foreach elem $netifinfo(-ipaddresses) {
                    if {[lindex $elem 0] eq $ipaddr} {
                        set result $netifinfo(-physicaladdress)
                        break
                    }
                }
            }
            if {[info exists result]} {
                break
            }
        }
    }

    if {[info exists result]} {
        if {$varname == ""} {
            return $result
        }
        upvar $varname var
        set var $result
        return 1
    } else {
        if {$varname == ""} {
            error "Could not map IP address $ipaddr to a hardware address"
        }
        return 0
    }
}

#
# Return hw address for a IP address
proc twapi::hwaddr_to_ipaddr {hwaddr {varname ""}} {
    set hwaddr [string map {- "" : ""} $hwaddr]
    foreach arp [GetIpNetTable] {
        if {[lindex $arp 3] == 2} continue;       # Invalid entry type
        if {[string equal $hwaddr [_hwaddr_binary_to_string [lindex $arp 1] ""]]} {
            set result [lindex $arp 2]
            break
        }
    }

    # If could not get from ARP table, see if it is one of our own
    # Ignore errors
    if {![info exists result]} {
        foreach ifindex [get_netif_indices] {
            catch {
                array set netifinfo [get_netif_info $ifindex -ipaddresses -physicaladdress]
                # Search list of ipaddresses
                set ifhwaddr [string map {- ""} $netifinfo(-physicaladdress)]
                if {[string equal -nocase $hwaddr $ifhwaddr]} {
                    set result [lindex [lindex $netifinfo(-ipaddresses) 0] 0]
                    break
                }
            }
            if {[info exists result]} {
                break
            }
        }
    }

    if {[info exists result]} {
        if {$varname == ""} {
            return $result
        }
        upvar $varname var
        set var $result
        return 1
    } else {
        if {$varname == ""} {
            error "Could not map hardware address $hwaddr to an IP address"
        }
        return 0
    }
}



#
# Flush the arp table for a given interface
proc twapi::flush_arp_table {if_index} {
    FlushIpNetTable $if_index
}


#
# Return the list of TCP connections
proc twapi::get_tcp_connections {args} {
    variable tcp_statenames
    variable tcp_statevalues
    if {![info exists tcp_statevalues]} {
        array set tcp_statevalues {
            closed            1
            listen            2
            syn_sent          3
            syn_rcvd          4
            estab             5
            fin_wait1         6
            fin_wait2         7
            close_wait        8
            closing           9
            last_ack         10
            time_wait        11
            delete_tcb       12
        }
        foreach {name val} [array get tcp_statevalues] {
            set tcp_statenames($val) $name
        }
    }
    array set opts [parseargs args {
        state
        localaddr
        remoteaddr
        localport
        remoteport
        pid
        all
        matchstate.arg 
        matchlocaladdr.arg
        matchremoteaddr.arg
        matchlocalport.int
        matchremoteport.int
        matchpid.int
    } -maxleftover 0]

    if {! ($opts(state) || $opts(localaddr) || $opts(remoteaddr) || $opts(localport) || $opts(remoteport) || $opts(pid))} {
        set opts(all) 1
    }

    # Convert state to appropriate symbol if necessary
    if {[info exists opts(matchstate)]} {
        set matchstates [list ]
        foreach stateval $opts(matchstate) {
            if {[info exists tcp_statevalues($stateval)]} {
                lappend matchstates $stateval
                continue
            }
            if {[info exists tcp_statenames($stateval)]} {
                lappend matchstates $tcp_statenames($stateval)
                continue
            }
            error "Unrecognized connection state '$stateval' specified for option -matchstate"
        }
    }

    foreach opt {matchlocaladdr matchremoteaddr} {
        if {[info exists opts($opt)]} {
            # TBD - also allow DNS addresses
            # TBD - validate IP address
        }
    }

    # Get the complete list of connections
    set conns [list ]
    foreach entry [AllocateAndGetTcpExTableFromStack 0 0] {
        foreach {state localaddr localport remoteaddr remoteport pid} $entry {
            break
        }
        if {[string equal $remoteaddr 0.0.0.0]} {
            # Socket not connected. WIndows passes some random value 
            # for remote port in this case. Set it to 0
            set remoteport 0
        }
        if {[info exists opts(matchpid)]} {
            # See if this platform even returns the PID
            if {$pid == ""} {
                error "Connection process id not available on this system."
            }
            if {$pid != $opts(matchpid)} {
                continue
            }
        }
        if {[info exists opts(matchlocaladdr)] &&
            $opts(matchlocaladdr) != $localaddr} {
            continue
        }
        if {[info exists opts(matchremoteaddr)] &&
            $opts(matchremoteaddr) != $remoteaddr} {
            continue
        }
        if {[info exists opts(matchlocalport)] &&
            $opts(matchlocalport) != $localport} {
            continue
        }
        if {[info exists opts(matchremoteport)] &&
            $opts(matchremoteport) != $remoteport} {
            continue
        }
        if {[info exists tcp_statenames($state)]} {
            set state $tcp_statenames($state)
        }
        if {[info exists matchstates] && [lsearch -exact $matchstates $state] < 0} {
            continue
        }

        # OK, now we have matched. Include specified fields in the result
        set conn [list ]
        foreach opt {localaddr localport remoteaddr remoteport state pid} {
            if {$opts(all) || $opts($opt)} {
                lappend conn -$opt [set $opt]
            }
        }
        lappend conns $conn
    }
    return $conns
}


#
# Return the list of UDP connections
proc twapi::get_udp_connections {args} {
    array set opts [parseargs args {
        localaddr
        localport
        pid
        all
        matchlocaladdr.arg
        matchlocalport.int
        matchpid.int
    } -maxleftover 0]

    if {! ($opts(localaddr) || $opts(localport) || $opts(pid))} {
        set opts(all) 1
    }

    if {[info exists opts(matchlocaladdr)]} {
        # TBD - also allow DNS addresses
        # TBD - validate IP address
    }

    # Get the complete list of connections
    set conns [list ]
    foreach entry [AllocateAndGetUdpExTableFromStack 0 0] {
        foreach {localaddr localport pid} $entry {
            break
        }
        if {[info exists opts(matchpid)]} {
            # See if this platform even returns the PID
            if {$pid == ""} {
                error "Connection process id not available on this system."
            }
            if {$pid != $opts(matchpid)} {
                continue
            }
        }
        if {[info exists opts(matchlocaladdr)] &&
            $opts(matchlocaladdr) != $localaddr} {
            continue
        }
        if {[info exists opts(matchlocalport)] &&
            $opts(matchlocalport) != $localport} {
            continue
        }

        # OK, now we have matched. Include specified fields in the result
        set conn [list ]
        foreach opt {localaddr localport pid} {
            if {$opts(all) || $opts($opt)} {
                lappend conn -$opt [set $opt]
            }
        }
        lappend conns $conn
    }
    return $conns
}

#
# Terminates a TCP connection. Does not generate an error if connection
# does not exist
proc twapi::terminate_tcp_connections {args} {
    array set opts [parseargs args {
        matchstate.int
        matchlocaladdr.arg
        matchremoteaddr.arg
        matchlocalport.int
        matchremoteport.int
        matchpid.int
    } -maxleftover 0]    

    # TBD - ignore 'no such connection' errors

    # If local and remote endpoints fully specified, just directly call
    # SetTcpEntry. Note pid must NOT be specified since we must then
    # fall through and check for that pid
    if {[info exists opts(matchlocaladdr)] && [info exists opts(matchlocalport)] &&
        [info exists opts(matchremoteaddr)] && [info exists opts(matchremoteport)] &&
        ! [info exists opts(matchpid)]} {
        # 12 is "delete" code
        SetTcpEntry [list 12 $opts(matchlocaladdr) $opts(matchlocalport) $opts(matchremoteaddr) $opts(matchremoteport)]
        return
    }

    # Get connection list and go through matching on each
    foreach conn [eval get_tcp_connections [get_array_as_options opts]] {
        array set aconn $conn
        # TBD - should we handle integer values of opts(state) ?
        if {[info exists opts(matchstate)] &&
            $opts(matchstate) != $aconn(-state)} {
            continue
        }
        if {[info exists opts(matchlocaladdr)] &&
            $opts(matchlocaladdr) != $aconn(-localaddr)} {
            continue
        }
        if {[info exists opts(matchlocalport)] &&
            $opts(matchlocalport) != $aconn(-localport)} {
            continue
        }
        if {[info exists opts(matchremoteaddr)] &&
            $opts(matchremoteaddr) != $aconn(-remoteaddr)} {
            continue
        }
        if {[info exists opts(remoteport)] &&
            $opts(matchremoteport) != $aconn(-remoteport)} {
            continue
        }
        if {[info exists opts(matchpid)] &&
            $opts(matchpid) != $aconn(-pid)} {
            continue
        }
        # Matching conditions fulfilled
        # 12 is "delete" code
        SetTcpEntry [list 12 $aconn(-localaddr) $aconn(-localport) $aconn(-remoteaddr) $aconn(-remoteport)]
    }
}


#
# Flush cache of host names and ports.
proc twapi::flush_network_name_cache {} {
    array unset ::twapi::port2name
    array unset ::twapi::addr2name
    array unset ::twapi::name2port
    array unset ::twapi::name2addr
}

#
# IP addr -> hostname
proc twapi::address_to_hostname {addr args} {
    variable addr2name

    array set opts [parseargs args {
        flushcache
        async.arg
    } -maxleftover 0]

    # Note as a special case, we treat 0.0.0.0 explicitly since
    # win32 getnameinfo translates this to the local host name which
    # is completely bogus.
    if {$addr eq "0.0.0.0"} {
        set addr2name($addr) $addr
        set opts(flushcache) 0
        # Now just fall thru to deal with async option etc.
    }


    if {[info exists addr2name($addr)]} {
        if {$opts(flushcache)} {
            unset addr2name($addr)
        } else {
            if {[info exists opts(async)]} {
                after idle [list after 0 $opts(async) [list $addr success $addr2name($addr)]]
                return ""
            } else {
                return $addr2name($addr)
            }
        }
    }

    # If async option, we will call back our internal function which
    # will update the cache and then invoke the caller's script
    if {[info exists opts(async)]} {
        Twapi_ResolveAddressAsync $addr "::twapi::_ResolveAddress_handler [list $opts(async)]"
        return ""
    }

    # Synchronous
    set name [lindex [twapi::getnameinfo [list $addr] 8] 0]
    if {$name eq $addr} {
        # Could not resolve.
        set name ""
    }

    set addr2name($addr) $name
    return $name
}

#
# host name -> IP addresses
proc twapi::hostname_to_address {name args} {
    variable name2addr

    set name [string tolower $name]

    array set opts [parseargs args {
        flushcache
        async.arg
    } -maxleftover 0]

    if {[info exists name2addr($name)]} {
        if {$opts(flushcache)} {
            unset name2addr($name)
        } else {
            if {[info exists opts(async)]} {
                after idle [list after 0 $opts(async) [list $name success $name2addr($name)]]
                return ""
            } else {
                return $name2addr($name)
            }
        }
    }

    # Do not have resolved name

    # If async option, we will call back our internal function which
    # will update the cache and then invoke the caller's script
    if {[info exists opts(async)]} {
        Twapi_ResolveHostnameAsync $name "::twapi::_ResolveHostname_handler [list $opts(async)]"
        return ""
    }

    # Resolve address synchronously
    set addrs [list ]
    catch {
        foreach endpt [twapi::getaddrinfo $name 0 0] {
            foreach {addr port} $endpt break
            lappend addrs $addr
        }
    }

    set name2addr($name) $addrs
    return $addrs
}

#
# Look up a port name
proc twapi::port_to_service {port} {
    variable port2name

    if {[info exists port2name($port)]} {
        return $port2name($port)
    }

    try {
        set name [lindex [twapi::getnameinfo [list 0.0.0.0 $port] 2] 1]
    } onerror {TWAPI_WIN32 11004} {
        # Lookup failed
        set name ""
    }

    # If we did not get a name back, check for some well known names
    # that windows does not translate. Note some of these are names
    # that windows does translate in the reverse direction!
    if {$name eq ""} {
        foreach {p n} {
            123 ntp
            137 netbios-ns
            138 netbios-dgm
            500 isakmp
            1900 ssdp
            4500 ipsec-nat-t
        } {
            if {$port == $p} {
                set name $n
                break
            }
        }
    }
        
    set port2name($port) $name
    return $name
}


#
# Port name -> number
proc twapi::service_to_port {name} {
    variable name2port

    # TBD - add option for specifying protocol
    set protocol 0

    if {[info exists name2port($name)]} {
        return $name2port($name)
    }

    if {[string is integer $name]} {
        return $name
    }

    if {[catch {
        # Return the first port
        set port [lindex [lindex [twapi::getaddrinfo "" $name $protocol] 0] 1]
    }]} {
        set port ""
    }
    set name2port($name) $port
    return $port
}


################################################################
# Utility procs

# Convert binary hardware address to string format
proc twapi::_hwaddr_binary_to_string {b {joiner -}} {
    if {[binary scan $b H* str]} {
        set s ""
        foreach {x y} [split $str ""] {
            lappend s $x$y
        }
        return [join $s $joiner]
    } else {
        error "Could not convert binary hardware address"
    }
}

# Callback for address resolution
proc twapi::_ResolveAddress_handler {script addr status hostname} {
    # Before invoking the callback, store result if available
    if {$status eq "success"} {
        set ::twapi::addr2name($addr) $hostname
    }
    eval $script [list $addr $status $hostname]
    return
}

# Callback for hostname resolution
proc twapi::_ResolveHostname_handler {script name status addrs} {
    # Before invoking the callback, store result if available
    if {$status eq "success"} {
        set ::twapi::name2addr($name) $addrs
    } elseif {$addrs == 11001} {
        # For compatibility with the sync version and address resolution,
        # We return an success if empty list if in fact the failure was
        # that no name->address mapping exists
        set status success
        set addrs [list ]
    }

    eval $script [list $name $status $addrs]
    return
}
