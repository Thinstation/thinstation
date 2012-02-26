#
# Copyright (c) 2003, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

namespace eval twapi {
}


#
# Get the default system/user lcid/langid 
proc twapi::get_user_default_lcid {} {return [GetUserDefaultLCID]}
proc twapi::get_system_default_lcid {} {return [GetSystemDefaultLCID]}
proc twapi::get_user_langid {} {return [GetUserDefaultLangID]}
# Compatibility alias
interp alias {} twapi::get_user_default_langid {} twapi::get_user_langid
proc twapi::get_system_langid {} {return [GetSystemDefaultLangID]}
# Compatibility alias
interp alias {} twapi::get_system_default_langid {} twapi::get_system_langid
proc twapi::get_user_ui_langid {} {
    # GetUserDefaultUILanguage does not exist on NT 4
    try {
        return [GetUserDefaultUILanguage]
    } onerror {TWAPI_WIN32 127} {
        return [get_user_langid]
    }
}
proc twapi::get_system_ui_langid {} {
    # GetSystemDefaultUILanguage does not exist on NT 4
    try {
        return [GetSystemDefaultUILanguage]
    } onerror {TWAPI_WIN32 127} {
        return [get_system_langid]
    }
}

proc twapi::get_lcid {} {
    return [GetThreadLocale]
}

#
# Format a number
proc twapi::format_number {number lcid args} {

    set number [_verify_number_format $number]

    set lcid [_map_default_lcid_token $lcid]

    # If no options specified, format according to the passed locale
    if {[llength $args] == 0} {
        return [GetNumberFormat 1 $lcid 0 $number 0 0 0 . "" 0]
    }

    array set opts [parseargs args {
        idigits.int
        ilzero.bool
        sgrouping.int
        sdecimal.arg
        sthousand.arg
        inegnumber.int
    }]

    # Check the locale for unspecified options
    foreach opt {idigits ilzero sgrouping sdecimal sthousand inegnumber} {
        if {![info exists opts($opt)]} {
            set opts($opt) [lindex [get_locale_info $lcid -$opt] 1]
        }
    }
        
    # If number of decimals is -1, see how many decimal places
    # in passed string
    if {$opts(idigits) == -1} {
        foreach {whole frac} [split $number .] break
        set opts(idigits) [string length $frac]
    }

    # Convert Locale format for grouping to integer calue
    if {![string is integer $opts(sgrouping)]} {
        # Format assumed to be of the form "N;M;....;0"
        set grouping 0
        foreach n [split $opts(sgrouping) {;}] {
            if {$n == 0} break
            set grouping [expr {$n + 10*$grouping}]
        }
        set opts(sgrouping) $grouping
    }

    set flags 0
    if {[info exists opts(nouseroverride)] && $opts(nouseroverride)} {
        setbits flags 0x80000000
    }
    return [GetNumberFormat 0 $lcid $flags $number $opts(idigits) \
                $opts(ilzero) $opts(sgrouping) $opts(sdecimal) \
                $opts(sthousand) $opts(inegnumber)]
}


#
# Format currency
proc twapi::format_currency {number lcid args} {

    set number [_verify_number_format $number]

    # Get semi-canonical form (get rid of preceding "+" etc.)
    # Also verifies number syntax
    set number [expr {$number+0}];

    set lcid [_map_default_lcid_token $lcid]

    # If no options specified, format according to the passed locale
    if {[llength $args] == 0} {
        return [GetCurrencyFormat 1 $lcid 0 $number 0 0 0 . "" 0 0 ""]
    }

    array set opts [parseargs args {
        idigits.int
        ilzero.bool
        sgrouping.int
        sdecimal.arg
        sthousand.arg
        inegcurr.int
        icurrency.int
        scurrency.arg
    }]

    # Check the locale for unspecified options
    foreach opt {idigits ilzero sgrouping sdecimal sthousand inegcurr icurrency scurrency} {
        if {![info exists opts($opt)]} {
            set opts($opt) [lindex [get_locale_info $lcid -$opt] 1]
        }
    }

    # If number of decimals is -1, see how many decimal places
    # in passed string
    if {$opts(idigits) == -1} {
        foreach {whole frac} [split $number .] break
        set opts(idigits) [string length $frac]
    }

    # Convert Locale format for grouping to integer calue
    if {![string is integer $opts(sgrouping)]} {
        # Format assumed to be of the form "N;M;....;0"
        set grouping 0
        foreach n [split $opts(sgrouping) {;}] {
            if {$n == 0} break
            set grouping [expr {$n + 10*$grouping}]
        }
        set opts(sgrouping) $grouping
    }

    set flags 0
    if {[info exists opts(nouseroverride)] && $opts(nouseroverride)} {
        setbits flags 0x80000000
    }

    return [GetCurrencyFormat 0 $lcid $flags $number $opts(idigits) \
                $opts(ilzero) $opts(sgrouping) $opts(sdecimal) \
                $opts(sthousand) $opts(inegcurr) \
                $opts(icurrency) $opts(scurrency)]
}


#
# Get various info about a locale
proc twapi::get_locale_info {lcid args} {

    set lcid [_map_default_lcid_token $lcid]

    variable locale_info_class_map
    if {![info exists locale_info_class_map]} {
        array set locale_info_class_map {
            ilanguage              0x00000001
            slanguage              0x00000002
            senglanguage           0x00001001
            sabbrevlangname        0x00000003
            snativelangname        0x00000004
            icountry               0x00000005
            scountry               0x00000006
            sengcountry            0x00001002
            sabbrevctryname        0x00000007
            snativectryname        0x00000008
            idefaultlanguage       0x00000009
            idefaultcountry        0x0000000A
            idefaultcodepage       0x0000000B
            idefaultansicodepage   0x00001004
            idefaultmaccodepage    0x00001011
            slist                  0x0000000C
            imeasure               0x0000000D
            sdecimal               0x0000000E
            sthousand              0x0000000F
            sgrouping              0x00000010
            idigits                0x00000011
            ilzero                 0x00000012
            inegnumber             0x00001010
            snativedigits          0x00000013
            scurrency              0x00000014
            sintlsymbol            0x00000015
            smondecimalsep         0x00000016
            smonthousandsep        0x00000017
            smongrouping           0x00000018
            icurrdigits            0x00000019
            iintlcurrdigits        0x0000001A
            icurrency              0x0000001B
            inegcurr               0x0000001C
            sdate                  0x0000001D
            stime                  0x0000001E
            sshortdate             0x0000001F
            slongdate              0x00000020
            stimeformat            0x00001003
            idate                  0x00000021
            ildate                 0x00000022
            itime                  0x00000023
            itimemarkposn          0x00001005
            icentury               0x00000024
            itlzero                0x00000025
            idaylzero              0x00000026
            imonlzero              0x00000027
            s1159                  0x00000028
            s2359                  0x00000029
            icalendartype          0x00001009
            ioptionalcalendar      0x0000100B
            ifirstdayofweek        0x0000100C
            ifirstweekofyear       0x0000100D
            sdayname1              0x0000002A
            sdayname2              0x0000002B
            sdayname3              0x0000002C
            sdayname4              0x0000002D
            sdayname5              0x0000002E
            sdayname6              0x0000002F
            sdayname7              0x00000030
            sabbrevdayname1        0x00000031
            sabbrevdayname2        0x00000032
            sabbrevdayname3        0x00000033
            sabbrevdayname4        0x00000034
            sabbrevdayname5        0x00000035
            sabbrevdayname6        0x00000036
            sabbrevdayname7        0x00000037
            smonthname1            0x00000038
            smonthname2            0x00000039
            smonthname3            0x0000003A
            smonthname4            0x0000003B
            smonthname5            0x0000003C
            smonthname6            0x0000003D
            smonthname7            0x0000003E
            smonthname8            0x0000003F
            smonthname9            0x00000040
            smonthname10           0x00000041
            smonthname11           0x00000042
            smonthname12           0x00000043
            smonthname13           0x0000100E
            sabbrevmonthname1      0x00000044
            sabbrevmonthname2      0x00000045
            sabbrevmonthname3      0x00000046
            sabbrevmonthname4      0x00000047
            sabbrevmonthname5      0x00000048
            sabbrevmonthname6      0x00000049
            sabbrevmonthname7      0x0000004A
            sabbrevmonthname8      0x0000004B
            sabbrevmonthname9      0x0000004C
            sabbrevmonthname10     0x0000004D
            sabbrevmonthname11     0x0000004E
            sabbrevmonthname12     0x0000004F
            sabbrevmonthname13     0x0000100F
            spositivesign          0x00000050
            snegativesign          0x00000051
            ipossignposn           0x00000052
            inegsignposn           0x00000053
            ipossymprecedes        0x00000054
            ipossepbyspace         0x00000055
            inegsymprecedes        0x00000056
            inegsepbyspace         0x00000057
            fontsignature          0x00000058
            siso639langname        0x00000059
            siso3166ctryname       0x0000005A
            idefaultebcdiccodepage 0x00001012
            ipapersize             0x0000100A
            sengcurrname           0x00001007
            snativecurrname        0x00001008
            syearmonth             0x00001006
            ssortname              0x00001013
            idigitsubstitution     0x00001014
        }
    }

    array set opts [parseargs args [array names locale_info_class_map]]

    set result [list ]
    foreach opt [array names opts] {
        if {$opts($opt)} {
            lappend result -$opt [GetLocaleInfo $lcid $locale_info_class_map($opt)]
        }
    }
    return $result
}


proc twapi::map_code_page_to_name {cp} {
    variable code_page_names
    if {![info exists code_page_names]} {
        array set code_page_names {
            0   "System ANSI default"
            1   "System OEM default"
            37 "IBM EBCDIC - U.S./Canada"
            437 "OEM - United States"
            500 "IBM EBCDIC - International"
            708 "Arabic - ASMO 708"
            709 "Arabic - ASMO 449+, BCON V4"
            710 "Arabic - Transparent Arabic"
            720 "Arabic - Transparent ASMO"
            737 "OEM - Greek (formerly 437G)"
            775 "OEM - Baltic"
            850 "OEM - Multilingual Latin I"
            852 "OEM - Latin II"
            855 "OEM - Cyrillic (primarily Russian)"
            857 "OEM - Turkish"
            858 "OEM - Multlingual Latin I + Euro symbol"
            860 "OEM - Portuguese"
            861 "OEM - Icelandic"
            862 "OEM - Hebrew"
            863 "OEM - Canadian-French"
            864 "OEM - Arabic"
            865 "OEM - Nordic"
            866 "OEM - Russian"
            869 "OEM - Modern Greek"
            870 "IBM EBCDIC - Multilingual/ROECE (Latin-2)"
            874 "ANSI/OEM - Thai (same as 28605, ISO 8859-15)"
            875 "IBM EBCDIC - Modern Greek"
            932 "ANSI/OEM - Japanese, Shift-JIS"
            936 "ANSI/OEM - Simplified Chinese (PRC, Singapore)"
            949 "ANSI/OEM - Korean (Unified Hangeul Code)"
            950 "ANSI/OEM - Traditional Chinese (Taiwan; Hong Kong SAR, PRC)"
            1026 "IBM EBCDIC - Turkish (Latin-5)"
            1047 "IBM EBCDIC - Latin 1/Open System"
            1140 "IBM EBCDIC - U.S./Canada (037 + Euro symbol)"
            1141 "IBM EBCDIC - Germany (20273 + Euro symbol)"
            1142 "IBM EBCDIC - Denmark/Norway (20277 + Euro symbol)"
            1143 "IBM EBCDIC - Finland/Sweden (20278 + Euro symbol)"
            1144 "IBM EBCDIC - Italy (20280 + Euro symbol)"
            1145 "IBM EBCDIC - Latin America/Spain (20284 + Euro symbol)"
            1146 "IBM EBCDIC - United Kingdom (20285 + Euro symbol)"
            1147 "IBM EBCDIC - France (20297 + Euro symbol)"
            1148 "IBM EBCDIC - International (500 + Euro symbol)"
            1149 "IBM EBCDIC - Icelandic (20871 + Euro symbol)"
            1200 "Unicode UCS-2 Little-Endian (BMP of ISO 10646)"
            1201 "Unicode UCS-2 Big-Endian"
            1250 "ANSI - Central European"
            1251 "ANSI - Cyrillic"
            1252 "ANSI - Latin I"
            1253 "ANSI - Greek"
            1254 "ANSI - Turkish"
            1255 "ANSI - Hebrew"
            1256 "ANSI - Arabic"
            1257 "ANSI - Baltic"
            1258 "ANSI/OEM - Vietnamese"
            1361 "Korean (Johab)"
            10000 "MAC - Roman"
            10001 "MAC - Japanese"
            10002 "MAC - Traditional Chinese (Big5)"
            10003 "MAC - Korean"
            10004 "MAC - Arabic"
            10005 "MAC - Hebrew"
            10006 "MAC - Greek I"
            10007 "MAC - Cyrillic"
            10008 "MAC - Simplified Chinese (GB 2312)"
            10010 "MAC - Romania"
            10017 "MAC - Ukraine"
            10021 "MAC - Thai"
            10029 "MAC - Latin II"
            10079 "MAC - Icelandic"
            10081 "MAC - Turkish"
            10082 "MAC - Croatia"
            12000 "Unicode UCS-4 Little-Endian"
            12001 "Unicode UCS-4 Big-Endian"
            20000 "CNS - Taiwan"
            20001 "TCA - Taiwan"
            20002 "Eten - Taiwan"
            20003 "IBM5550 - Taiwan"
            20004 "TeleText - Taiwan"
            20005 "Wang - Taiwan"
            20105 "IA5 IRV International Alphabet No. 5 (7-bit)"
            20106 "IA5 German (7-bit)"
            20107 "IA5 Swedish (7-bit)"
            20108 "IA5 Norwegian (7-bit)"
            20127 "US-ASCII (7-bit)"
            20261 "T.61"
            20269 "ISO 6937 Non-Spacing Accent"
            20273 "IBM EBCDIC - Germany"
            20277 "IBM EBCDIC - Denmark/Norway"
            20278 "IBM EBCDIC - Finland/Sweden"
            20280 "IBM EBCDIC - Italy"
            20284 "IBM EBCDIC - Latin America/Spain"
            20285 "IBM EBCDIC - United Kingdom"
            20290 "IBM EBCDIC - Japanese Katakana Extended"
            20297 "IBM EBCDIC - France"
            20420 "IBM EBCDIC - Arabic"
            20423 "IBM EBCDIC - Greek"
            20424 "IBM EBCDIC - Hebrew"
            20833 "IBM EBCDIC - Korean Extended"
            20838 "IBM EBCDIC - Thai"
            20866 "Russian - KOI8-R"
            20871 "IBM EBCDIC - Icelandic"
            20880 "IBM EBCDIC - Cyrillic (Russian)"
            20905 "IBM EBCDIC - Turkish"
            20924 "IBM EBCDIC - Latin-1/Open System (1047 + Euro symbol)"
            20932 "JIS X 0208-1990 & 0121-1990"
            20936 "Simplified Chinese (GB2312)"
            21025 "IBM EBCDIC - Cyrillic (Serbian, Bulgarian)"
            21027 "Extended Alpha Lowercase"
            21866 "Ukrainian (KOI8-U)"
            28591 "ISO 8859-1 Latin I"
            28592 "ISO 8859-2 Central Europe"
            28593 "ISO 8859-3 Latin 3"
            28594 "ISO 8859-4 Baltic"
            28595 "ISO 8859-5 Cyrillic"
            28596 "ISO 8859-6 Arabic"
            28597 "ISO 8859-7 Greek"
            28598 "ISO 8859-8 Hebrew"
            28599 "ISO 8859-9 Latin 5"
            28605 "ISO 8859-15 Latin 9"
            29001 "Europa 3"
            38598 "ISO 8859-8 Hebrew"
            50220 "ISO 2022 Japanese with no halfwidth Katakana"
            50221 "ISO 2022 Japanese with halfwidth Katakana"
            50222 "ISO 2022 Japanese JIS X 0201-1989"
            50225 "ISO 2022 Korean"
            50227 "ISO 2022 Simplified Chinese"
            50229 "ISO 2022 Traditional Chinese"
            50930 "Japanese (Katakana) Extended"
            50931 "US/Canada and Japanese"
            50933 "Korean Extended and Korean"
            50935 "Simplified Chinese Extended and Simplified Chinese"
            50936 "Simplified Chinese"
            50937 "US/Canada and Traditional Chinese"
            50939 "Japanese (Latin) Extended and Japanese"
            51932 "EUC - Japanese"
            51936 "EUC - Simplified Chinese"
            51949 "EUC - Korean"
            51950 "EUC - Traditional Chinese"
            52936 "HZ-GB2312 Simplified Chinese"
            54936 "Windows XP: GB18030 Simplified Chinese (4 Byte)"
            57002 "ISCII Devanagari"
            57003 "ISCII Bengali"
            57004 "ISCII Tamil"
            57005 "ISCII Telugu"
            57006 "ISCII Assamese"
            57007 "ISCII Oriya"
            57008 "ISCII Kannada"
            57009 "ISCII Malayalam"
            57010 "ISCII Gujarati"
            57011 "ISCII Punjabi"
            65000 "Unicode UTF-7"
            65001 "Unicode UTF-8"
        }
    }
    set cp [expr {0+$cp}]
    if {[info exists code_page_names($cp)]} {
        return $code_page_names($cp)
    } else {
        return "Code page $cp"
    }
}

#
# Get the name of a language
proc twapi::map_langid_to_name {langid} {
    return [VerLanguageName $langid]
}

#
# Extract language and sublanguage values
proc twapi::extract_primary_langid {langid} {
    return [expr {$langid & 0x3ff}]
}
proc twapi::extract_sublanguage_langid {langid} {
    return [expr {($langid >> 10) & 0x3f}]
}

#
# Utility functions

proc twapi::_map_default_lcid_token {lcid} {
    if {$lcid == "systemdefault"} {
        return 2048
    } elseif {$lcid == "userdefault"} {
        return 1024
    }
    return $lcid
}

proc twapi::_verify_number_format {n} {
    set n [string trimleft $n 0]
    if {[regexp {^[+-]?[[:digit:]]*(\.)?[[:digit:]]*$} $n]} {
        return $n
    } else {
        error "Invalid numeric format. Must be of a sequence of digits with an optional decimal point and leading plus/minus sign"
    }
}


