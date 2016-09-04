#############################################################################
#   lwdebug.tcl                                                             #
#                                                                           #
# Author: laomaiweng <laomaiweng AT minster DOT io>                         #
#                                                                           #
# Useful procedures for debugging Tcl code.                                 #
# Procedures get nopped if environment variable TCL_DEBUG is unset.         #
#                                                                           #
# History:                                                                  #
# * v1.3    add preserve- and scrub-lists                                   #
#           add [assert]                                                    #
# * v1.2    add [run]                                                       #
#           add [tee]                                                       #
#           rename package to 'lwdebug'                                     #
# * v1.1    add [step] and [interact]                                       #
# * v1.0    initial version                                                 #
#############################################################################

package provide lwdebug 1.2


# Define the lwdebug namespace
namespace eval lwdebug {
    # Debug flag
    variable debug 1

    # Lists of procs to preserve (even with debugging disabled) / scrub (even with debugging enabled)
    # Set those variables before doing [package require lwdebug]
    # Names must be unqualified (no ::lwdebug:: prefix)
    variable preservelist
    variable scrublist

    # Namespace for [tee]
    namespace eval tee {
        variable chans {}
    }

    # Namespace for [assert]
    namespace eval assert {
        variable rc 127
        variable cleanupscript {}
    }
}


#############################################################################
#############################################################################
#
# Procedures
#
#############################################################################
#############################################################################

#############################################################################
# Run debug code in the context of the caller.
# This code is NOT run (and hence has no performance impact) when debugging
# is disabled (the proc is nopped entirely).
#
# Arguments:
#   body    code to run
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   code return value
#############################################################################
proc ::lwdebug::run {body} {
    return [uplevel 1 $body]
}

#############################################################################
# Puts wrapper that only prints when debugging is enabled.
#
# Arguments:
#   args    arguments to puts
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   [puts] return value
#############################################################################
proc ::lwdebug::puts {args} {
    return [::puts {*}$args]
}

#############################################################################
# Get a stacktrace.
# Does not cope well with namespaces, may need some adjustments.
# NB: This is really different from [info errorstack], which only returns
#     the stacktrace where the last uncaught error occured.
#
# Arguments: NONE
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   string containing the current stacktrace
#############################################################################
proc ::lwdebug::stacktrace {} {
    set stack "Stack trace:\n"
    for {set i 1} {$i < [info level]} {incr i} {
        set lvl [info level -$i]
        set pname [lindex $lvl 0]
        append stack [string repeat " " $i]$pname
        foreach value [lrange $lvl 1 end] arg [info args $pname] {
            if {$value eq ""} {
                info default $pname $arg value
            }
            append stack " $arg='$value'"
        }
        append stack \n
    }
    return $stack
}

#############################################################################
# Turn on stepping for a procedure.
#
# Borrowed from:
#   https://en.wikibooks.org/wiki/Tcl_Programming/Debugging
#
# Arguments:
#   proc    name of the proc to instrument
#   yesno   whether to enable or disable stepping
#
# Globals: NONE
#
# Variables: NONE
#
# Return: NONE
#############################################################################
proc ::lwdebug::step {proc {yesno 1}} {
    # Add/remove a trace on the proc's execution
    set mode [expr {$yesno? "add" : "remove"}]
    trace $mode execution $proc {enterstep leavestep} ::lwdebug::interact
}

#############################################################################
# Stepping callback for a running procedure.
# Stepping must have been enabled on the procedure with the [step] proc.
#
# Borrowed from:
#   https://en.wikibooks.org/wiki/Tcl_Programming/Debugging
#
# Arguments:
#   args    arguments provided by the trace
#
# Globals: NONE
#
# Variables: NONE
#
# Return: NONE
#############################################################################
proc ::lwdebug::interact {args} {
    # Handle the leavestep
    if {[lindex $args end] eq "leavestep"} {
        puts "==>[lindex $args 2]"
        return
    }
    # Any other step: process user input
    puts -nonewline "$args --"
    while 1 {
        puts -nonewline "> "
        flush stdout
        gets stdin cmd
        if {$cmd eq "c" || $cmd eq ""} break
        catch {uplevel 1 $cmd} res
        if {[string length $res]} {puts $res}
    }
}

#############################################################################
# Setup a tee to duplicate the output from puts into other channel(s).
# Use - as channel to remove the tee.
#
# This proc replaces the puts command with a custom one. The old puts command
# is renamed as ::lwdebug::teeputs.
#
# Arguments:
#   args        channel(s) to tee output to (- to disable)
#
# Globals: NONE
#
# Variables:
#   tee::chans  channels to tee to
#
# Return: NONE
#############################################################################
proc ::lwdebug::tee {args} {
    variable tee::chans

    # Disable any existing tee
    if {[info command ::lwdebug::tee::puts] ne ""} {
        rename ::puts {}
        rename ::lwdebug::tee::puts ::puts
    }
    set tee::chans {}

    # Setup a new tee
    if {$args ne "-"} {
        # Test the channels
        foreach chan $args {
            if {$chan ni [chan names]} {
                return -code error "invalid chan: $chan"
            }
        }
        set tee::chans $args

        # Move puts out of the way
        rename ::puts ::lwdebug::tee::puts
        # Declare a tee-ing puts wrapper
        proc ::puts {args} {
            set text [lindex $args end]
            ::lwdebug::tee::puts {*}$args
            foreach chan $::lwdebug::tee::chans {
                ::lwdebug::tee::puts $chan $text
            }
        }
    }
}

#############################################################################
# Check a condition and terminate the program if it does not hold true.
# On failure, calls the cleanup script (if any, in the context of the caller,
# from variable $::lwdebug::assert::cleanupscript), prints an assert(3)-like
# message and aborts with exit code $::lwdebug::assert::rc (default: 127).
#
# Arguments:
#   cond        [expr] boolean condition to check
#   args        additional arguments/commands to the cleanup script
#
# Globals: NONE
#
# Variables:
#   assert::rc              exit code on failure
#   assert::cleanupscript   script to run on failure (for last-minute cleanup)
#
# Return: NONE
#############################################################################
proc ::lwdebug::assert {cond args} {
    variable assert::rc
    variable assert::cleanupscript

    # Check the condition
    if {!([uplevel 1 [list expr $cond]])} {
        # Condition failed: call the cleanup script with additional arguments
        try {
            uplevel 1 [concat $assert::cleanupscript $args]
        } on error {result options} {
            ::puts stderr "assert: Cleanup script failure: $result"
        }

        # Build and print the error message (as if printed by the caller)
        set frame [info frame -1]
        set framedesc [list "assert"]
        # This surely needs some polishing in case we're not in a straightforward proc invocation
        if {[dict exists $frame file] && [dict exists $frame line]} {
            lappend framedesc "[file tail [dict get $frame file]]:[dict get $frame line]"
        }
        if {[dict exists $frame proc]} {
            lappend framedesc "[dict get $frame proc]"
        }
        ::puts stderr "[join $framedesc ": "]: Assertion `$cond' failed."
        ::puts stderr "Aborted"

        # Bail out
        exit $assert::rc
    }
}


#############################################################################
#############################################################################
#
# Body
#
#############################################################################
#############################################################################

if {![info exists ::env(TCL_DEBUG)]} {
    # Debuging disabled: nop all debug procs except for those in the preserve list
    foreach proc [info procs ::lwdebug::*] {
        if {[namespace tail $proc] ni $::lwdebug::preservelist} {
            proc $proc args {}
        }
    }
    # Unset the debug flag
    set ::lwdebug::debug 0
} else {
    # Debugging enabled: nop debug procs that are in the scrub list
    foreach proc $::lwdebug::scrublist {
        if {[info procs ::lwdebug::$proc] ne ""} {
            proc ::lwdebug::$proc args {}
        }
    }
}

