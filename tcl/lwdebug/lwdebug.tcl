#############################################################################
#   lwdebug.tcl                                                             #
#                                                                           #
# Author: laomaiweng <laomaiweng AT minster DOT io>                         #
#                                                                           #
# Useful procedures for debugging Tcl code.                                 #
# Procedures get nopped if environment variable TCL_DEBUG is unset.         #
#                                                                           #
# History:                                                                  #
# * v1.2    add [run]                                                       #
#           add [tee]                                                       #
#           rename package to 'lwdebug'                                     #
# * v1.1    add [step] and [interact]                                       #
# * v1.0    initial version                                                 #
#############################################################################

package provide lwdebug 1.2


# Define the lwdebug namespace
namespace eval lwdebug {
    variable debug 1
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
# Puts wrapper.
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
#   teechans    channels to tee to
#
# Return: NONE
#############################################################################
proc ::lwdebug::tee {args} {
    variable teechans

    # Disable any existing tee
    if {[info command ::lwdebug::teeputs] ne ""} {
        rename ::puts {}
        rename ::lwdebug::teeputs ::puts
    }
    set teechans {}

    # Setup a new tee
    if {$args ne "-"} {
        # Test the channels
        foreach chan $args {
            if {$chan ni [chan names]} {
                return -code error "invalid chan: $chan"
            }
        }
        set teechans $args

        # Move puts out of the way
        rename ::puts ::lwdebug::teeputs
        # Declare a tee-ing puts wrapper
        proc ::puts {args} {
            set text [lindex $args end]
            ::lwdebug::teeputs {*}$args
            foreach chan $::lwdebug::teechans {
                ::lwdebug::teeputs $chan $text
            }
        }
    }
}


#############################################################################
#############################################################################
#
# Body
#
#############################################################################
#############################################################################

# Disable debugging if the TCL_DEBUG environment variable is not set
if {![info exists ::env(TCL_DEBUG)]} {
    # Nop all debug procs
    foreach proc [info procs ::lwdebug::*] {
        proc $proc args {}
    }
    # Set the debug flag to false
    set ::lwdebug::debug 0
}

