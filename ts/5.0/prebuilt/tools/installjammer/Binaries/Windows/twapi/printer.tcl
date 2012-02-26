#
# Copyright (c) 2004-2006 Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

namespace eval twapi {
}

proc twapi::enumerate_printers {args} {
    array set opts [parseargs args {
        {location.arg all {local remote all any}}
    } -maxleftover 0]

    set result [list ]
    foreach elem [Twapi_EnumPrinters_Level4 \
                      [string map {all 6 any 6 local 2 remote 4} $opts(location)] \
                     ] {
        lappend result [list \
                            name [kl_get $elem pPrinterName] \
                            server [kl_get $elem pServerName] \
                            attrs [_symbolize_printer_attributes \
                                       [kl_get $elem Attributes]] \
                           ]
    }
    return $result
}


proc twapi::printer_properties_dialog {name args} {
    array set opts [parseargs args {
        {hwin.int 0}
        {page.arg ""}
    } -maxleftover 0]
    
    shell_object_properties_dialog $name -type printer -hwin $opts(hwin) -page $opts(page)
}



#
# Utilities
# 
proc twapi::_symbolize_printer_attributes {attr} {
    return [_make_symbolic_bitmask $attr {
        queued         0x00000001
        direct         0x00000002
        default        0x00000004
        shared         0x00000008
        network        0x00000010
        hidden         0x00000020
        local          0x00000040
        enabledevq       0x00000080
        keepprintedjobs   0x00000100
        docompletefirst 0x00000200
        workoffline   0x00000400
        enablebidi    0x00000800
        rawonly       0x00001000
        published      0x00002000
        fax            0x00004000
        ts             0x00008000
    }]
}
