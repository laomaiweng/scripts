#############################################################################
#   debug.tcl                                                               #
#                                                                           #
# Author: laomaiweng <laomaiweng AT minster DOT io>                         #
#                                                                           #
# Useful procedures for debugging Tcl code.                                 #
# Procedures get nopped if environment variable TCL_DEBUG is unset.         #
#                                                                           #
# History:                                                                  #
# * v1.1    add [step] and [interact]
# * v1.0    initial version                                                 #
#############################################################################

package provide debug 1.1


# Define the debug namespace
namespace eval debug {
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
#   puts return value
#############################################################################
proc ::debug::puts {args} {
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
proc ::debug::stacktrace {} {
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
proc ::debug::step {proc {yesno 1}} {
    # Add/remove a trace on the proc's execution
    set mode [expr {$yesno? "add" : "remove"}]
    trace $mode execution $proc {enterstep leavestep} ::debug::interact
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
proc ::debug::interact {args} {
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
#############################################################################
#
# Body
#
#############################################################################
#############################################################################

# Nop all debug procedures if the TCL_DEBUG environment variable is not set
if {![info exists ::env(TCL_DEBUG)]} {
    # Nop all debug procs
    foreach proc [info procs ::debug::*] {
        proc $proc args {}
    }
    # Set debug flag to false
    set debug 0
}

