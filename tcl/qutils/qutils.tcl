#############################################################################
#   qutils - Q Tcl Utilities                                                #
#                                                                           #
# Author: quentin <quentin AT minster DOT io>                               #
#                                                                           #
# Useful Tcl utilities.                                                     #
#                                                                           #
# History:                                                                  #
# * v1.1    add [info pcexists] and [string is]                             #
# * v1.0    initial version                                                 #
#############################################################################

package provide qutils 1.1.1


# Package dependencies
package require cmdline


# Define the qutils namespace and export its procedures
namespace eval qutils {
    namespace export *
}


#############################################################################
#############################################################################
#
# Procedures
#
#############################################################################
#############################################################################

#############################################################################
# Get the script name.
#
# Arguments: NONE
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   script basename (no leading path, no trailing .tcl)
#############################################################################
proc ::qutils::scriptName {} {
    # Strip the path
    set base [file tail $::argv0]
    # Strip any trailing .tcl extension
    if {[file extension $base] eq ".tcl"} {
        set base [file rootname $base]
    }
    # Return the resulting basename
    return $base
}

#############################################################################
# Print an error message and bail out.
#
# Arguments:
#   message     error message
#   code        return code (default: 1)
#   prefix      optional prefix to the error message (default: "Error: ")
#
# Globals: NONE
#
# Variables: NONE
#
# Return: NONE
#############################################################################
proc ::qutils::die {message {code 1} {prefix "Error: "}} {
    # Print the message
    puts stderr ${prefix}${message}
    # Exit with the given return code
    exit $code
}

#############################################################################
# Extend a Tcl ensemble with a command/proc.
#
# Arguments:
#   ensemble    name of the ensemble
#   subcommand  name of the new subcommand
#   proc        fully qualified name of the associated procedure
#
# Globals: NONE
#
# Variables: NONE
#
# Return: NONE
#############################################################################
proc ::qutils::ensembleExtend {ensemble subcommand proc} {
    set map [namespace ensemble configure $ensemble -map]
    dict set map $subcommand $proc
    namespace ensemble configure $ensemble -map $map
}

#############################################################################
# Escape a string for use in a regexp pattern.
#
# Arguments:
#   str     string to escape
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   escaped string that can safely be used as a fixed string in a regexp
#############################################################################
proc ::qutils::reEscape {str} {
    regsub -all {\W} $str {\\&}
}

#############################################################################
# Remove indices from a list.
#
# Arguments:
#   list        list to remove indices from
#   indices     indices to remove from the list
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   list with indices removed
#############################################################################
proc ::qutils::lremove {list indices} {
    # Sort the indices in decreasing order (so that indices get removed from
    # the end of the list first and don't impact removal of other indices)
    set indices [lsort -integer -decreasing -unique $indices]
    # Remove the indices
    foreach i $indices {
        set list [lreplace $list $i $i]
    }
    # Return the list
    return $list
}

#############################################################################
# Pad a string up to a given target length.
# A minimum number of characters can be appended regardless of the current
# string length.
#
# Arguments:
#   string      string value to pad
#   length      length to pad up to
#   char        padding character (default: " ")
#   atleast     minimum length of padding (default: 0)
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   padded string
#############################################################################
proc ::qutils::stringPad {string length {char " "} {atleast 0}} {
    # Pad the string with the given character
    append string [string repeat $char $atleast] [string repeat $char [expr {$length-[string length $string]-$atleast}]]
    # Return the padded string
    return $string
}

# Extend the string ensemble with [string pad]
::qutils::ensembleExtend string pad ::qutils::stringPad

#############################################################################
# Custom ::tcl::string::is subcommand to the string ensemble.
#
# Arguments:
#   args    "class string" for the class check
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   result of the class check
#############################################################################
proc ::qutils::stringIs {args} {
    # Custom class check (doesn't handle standard ::tcl::string::is options)
    lassign $args class string
    switch -- $class {
        dict {
            # Check whether the string parses correctly as a dict
            return [expr {![catch {dict size $string}]}]
        }
    }
    # Default class check
    return [::tcl::string::is {*}$args]
}

# Replace the string ensemble's [string is]
::qutils::ensembleExtend string is ::qutils::stringIs

#############################################################################
# Returns whether a string is an existing procedure or command name,
# in the caller's namespace.
#
# Options:
#   -proc       test for existence of a proc only
#   -command    test for existence of a command only
#
# Arguments:
#   name    procedure or command name to test for existence
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   boolean indicating whether the procedure or command exists
#############################################################################
proc ::qutils::infoPCExists {args} {
    # Parse the arguments
    set usage "info pcexists ?options? name"
    set options {
        {proc       "test for existence of a proc only"}
        {command    "test for existence of a command only"}
    }
    array set params [::cmdline::getoptions args $options "$usage\noptions:"]
    if {[llength $args] ne 1} {
        return -code error "wrong number of arguments: should be \"$usage\""
    }
    lassign $args name
    set testall [expr {!($params(proc) || $params(command))}]

    # Test for existence
    set exists 0
    if {$params(proc) || $testall} {
        set exists [expr {$exists || [uplevel 1 expr "{\[info procs $name\] ne \"\"}"]}]
    }
    if {$params(command) || $testall} {
        set exists [expr {$exists || [uplevel 1 expr "{\[info commands $name\] ne \"\"}"]}]
    }

    # Return the result
    return $exists
}

# Extend the info ensemble with [info pcexists]
::qutils::ensembleExtend info pcexists ::qutils::infoPCExists


################################## End of file #################################
