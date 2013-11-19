#############################################################################
#   qutils.tcl                                                              #
#                                                                           #
# Author: quentin <quentin@minster.io>                                      #
#                                                                           #
# Useful Tcl utilities.                                                     #
#############################################################################

package provide qutils 1.0


# Define the qutils namespace and export all its commands
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
#   listVar     list variable to strip indices from
#   indices     indices to strip from the list
#
# Globals: NONE
#
# Variables: NONE
#
# Return: NONE
#############################################################################
proc ::qutils::lremove {listVar indices} {
    upvar 1 $listVar list
    # Sort the indices in decreasing order (so that indices get removed from
    # the end of the list first and don't impact removal of other indices)
    set indices [lsort -integer -decreasing $indices]
    # Remove each index
    foreach i $indices {
        set list [lreplace $list $i $i]
    }
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

