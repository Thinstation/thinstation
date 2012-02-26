catch {wm withdraw .}
set ::env(IJTEST_DIR) [file normalize [file dirname [info script]]]
set ::env(IJTEST_TMP) [file join $::env(IJTEST_DIR) tmp]
set ::env(IJTEST_BIN) \
    [file normalize [file join $::env(IJTEST_DIR) .. installjammer]]

proc test {name desc args} {
    array set _args $args

    echo "$desc"
    set code [catch {uplevel #0 $_args(-body)} result]

    if {$code == 1} {
        return -code error $result
    }

    cd $::env(IJTEST_DIR)
}

proc echo {string} {
    puts  stdout $string
    flush stdout
}

proc readFile {file} {
    set fp [open $file]
    set x  [read $fp]
    close $fp
    return $x
}

proc makeDirectory {dir} {
    variable test
    if {![file exists $dir]} { file mkdir $dir }
    lappend test(dirs) $dir
}

proc project {project} {
    global info

    unset -nocomplain ::env(IJTEST_PROJECT)

    set mpi $project
    if {[file isdir $project]} { set mpi [file join $project $project.mpi] }
    if {![file exists $mpi]} { return }
    set ::env(IJTEST_PROJECT) $project

    uplevel #0 [list catch [list source $mpi]]
}

proc buildInstaller {args} {
    if {[info exists ::env(IJTEST_INSTALLER)]} {
        return $::env(IJTEST_INSTALLER)
    }
    eval rebuildInstaller $args
}

proc rebuildInstaller {args} {
    makeDirectory build
    makeDirectory output

    set project $::env(IJTEST_PROJECT)

    set opts [list]
    lappend opts --build-dir [file join $::env(IJTEST_DIR) build]
    lappend opts --output-dir [file join $::env(IJTEST_DIR) output]
    lappend opts --build-log-file [file join $::env(IJTEST_DIR) build build.log]
    eval lappend opts $args
    lappend opts --build [file join $::env(IJTEST_DIR) $project]
    set result [eval exec [list $::env(IJTEST_BIN)] $opts]

    if {[regexp {Installer: ([^\n]+)} $result -> installer]} {
        set ::env(IJTEST_INSTALLER) $installer
        return $installer
    }
}

proc runInstallerTest {script args} {
    if {![info exists ::env(IJTEST_INSTALLER)]} {
        if {![info exists ::env(IJTEST_PROJECT)]} {
            return -code error "could not find test installer"
        }
        buildInstaller $::env(IJTEST_PROJECT)
    }

    makeDirectory $::env(IJTEST_TMP)

    set tmp [file join $::env(IJTEST_TMP) script]
    set fp [open $tmp w]
    puts $fp $script
    puts $fp {
        ## Add an exit event to dump the info array for testing.
        inject enter exit {
            puts "array set info [list [array get info]]"
        }
    }
    close $fp

    set installer $::env(IJTEST_INSTALLER)
    catch {eval exec [list $installer --test-script $tmp] $args} res
    if {[string match "array set info*" $res]} { uplevel #0 $res }
}

proc runBuilderTest {script} {
    variable test

    if {![info exists test(builderSock)]} {
        set port 60006
        exec $::env(IJTEST_BIN) --command-port $port -- &
        set test(builderSock) [socket localhost $port]
        gets $test(builderSock) line
    }

    puts  $test(builderSock) $script
    flush $test(builderSock)
    set response {}
    while {[gets $test(builderSock) line] != -1} {
        if {$line eq "OK"} { break }
        lappend response $line
    }
    return [join $response \n]
}

proc runAllTests {} {
    foreach file [glob -nocomplain *.test] {
        echo "===== $file ====="
        project [file root $file].mpi
        uplevel #0 [list source $file]
        unset -nocomplain ::env(IJTEST_INSTALLER)
    }

    cleanupTests
    exit
}

proc cleanupTests {} {
    variable test

    if {[info exists test(builderSock)]} {
        puts  $test(builderSock) exit
        flush $test(builderSock)
    }

    if {[info exists test(dirs)]} {
        foreach dir $test(dirs) {
            file delete -force $dir
        }
    }
}
