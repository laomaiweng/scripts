#############################################################################
#   debug.tcl                                                               #
#                                                                           #
# Author: quentin <quentin@minster.io>                                      #
#                                                                           #
# Useful procedures for debugging Tcl code.                                 #
# Procedures get nopped if environment variable TCL_DEBUG is unset.         #
#############################################################################

package provide debug 1.0


# Define the Debug namespace
namespace eval Debug {
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
proc Debug::puts {args} {
    return [puts {*}$args]
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
proc Debug::stacktrace {} {
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
#############################################################################
#
# Body
#
#############################################################################
#############################################################################

# Nop all debug procedures if the TCL_DEBUG environment variable is not set
if {![info exists ::env(TCL_DEBUG)]} {
    # Nop all debug procs
    foreach proc [info procs ::Debug::*] {
        proc $proc args {}
    }
}

