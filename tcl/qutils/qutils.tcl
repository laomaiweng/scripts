#############################################################################
#   qutils.tcl                                                              #
#                                                                           #
# Author: quentin <quentin@minster.io>                                      #
#                                                                           #
# Useful Tcl utilities.                                                     #
#############################################################################

package provide qutils 1.1


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
# Trim leading 0s from a string representing an integer to prevent it from
# being parsed as an octal number.
#
# Arguments:
#   int     string representing a base-10 integer
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   string representing a base-10 integer, leading 0s trimmed
#############################################################################
proc ::qutils::unoctalize {int} {
    if {$int ne ""} {
        set int10 [string trimleft $int 0]
        if {$int10 eq ""} {
            set int10 0
        }
        if {[string is entier -strict $int10]} {
            return $int10
        }
    }
    return $int
}

#############################################################################
# Returns -1, 0, or 1, depending on whether v1 is less than, equal to, or
# greater than v2.
#
# Arguments:
#   v1      version number
#   v2      version number
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   -1, 0, or 1 depending on the result of the comparison
#############################################################################
proc ::qutils::compareVersions {v1 v2} {
    # First, just check whether the version strings are the same
    if {$v1 eq $v2} {
        # Don't even bother checking further
        return 0
    }

    # Parse the version strings (that's a Gentoo PMS version string)
    # TODO: support more version string formats
    set version_rx {^(?:v?([0-9]+(?:\.[0-9]+)*)([a-z])?(?:_(alpha|beta|pre|rc|p)([0-9]*))?)$}
    if {![regexp -- $version_rx $v1 -> v1_patchlevel v1_letter v1_stage v1_stage#]} {
        return -code error "invalid version string: $v1"
    }
    if {![regexp -- $version_rx $v2 -> v2_patchlevel v2_letter v2_stage v2_stage#]} {
        return -code error "invalid version string: $v2"
    }

    # Compare the patchlevels
    foreach p1 [split $v1_patchlevel .] p2 [split $v2_patchlevel .] {
        set p1 [unoctalize $p1]
        set p2 [unoctalize $p2]
        if {$p1 ne $p2} {
            return [expr {($p1 > $p2) ? 1 : -1}]
        }
    }
    # Compare the letters
    if {$v1_letter ne $v2_letter} {
        return [expr {($v1_letter > $v2_letter) ? 1 : -1}]
    }
    # Compare the stages
    set stages [list alpha beta pre rc "" p]
    if {$v1_stage ne $v2_stage} {
        set s1 [lsearch -exact $stages $v1_stage]
        set s2 [lsearch -exact $stages $v2_stage]
        return [expr {($s1 > $s2) ? 1 : -1}]
    }
    # Compare the stage numbers
    set s1 [unoctalize ${v1_stage#}]
    set s2 [unoctalize ${v2_stage#}]
    if {$s1 ne $s2} {
        return [expr {($s1 > $s2) ? 1 : -1}]
    }

    # Done comparing: they're the same
    return 0
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
proc ::qutils::stringEscape {str} {
    return [regsub -all {\W} $str {\\&}]
}

# Extend the string ensemble with [string escape]
::qutils::ensembleExtend string escape ::qutils::stringEscape

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
proc ::qutils::infoPCExists {name} {
    # Check whether the name matches that of a procedure or command
    return [uplevel 1 expr "\{\[info procs $name\] ne \"\" || \[info commands $name\] ne \"\"\}"]
}

# Extend the info ensemble with [info pcexists]
::qutils::ensembleExtend info pcexists ::qutils::infoPCExists

