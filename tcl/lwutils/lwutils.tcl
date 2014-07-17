#############################################################################
#   lwutils - Laomai Weng's Tcl Utilities                                   #
#                                                                           #
# Author: laomaiweng <laomaiweng AT minster DOT io>                         #
#                                                                           #
# Useful Tcl utilities.                                                     #
#                                                                           #
# History:                                                                  #
# * v1.7    add [unoctalize] and [compareVersions]                          #
# * v1.6    add [string sequence]                                           #
# * v1.5    update [dict assign] to handle nested dicts                     #
# * v1.4    add [foreachelse]                                               #
# * v1.3    add [dict assign]                                               #
# * v1.2    add [file dereference]                                          #
#           rename into 'lwutils'                                           #
#           replace [scriptName] with [info script]                         #
# * v1.1    add [info pcexists] and [string is]                             #
# * v1.0    initial version                                                 #
#############################################################################

package provide lwutils 1.7.0


# Package dependencies
package require cmdline


# Define the lwutils namespace and export its procedures
namespace eval lwutils {
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
proc ::lwutils::die {message {code 1} {prefix "Error: "}} {
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
proc ::lwutils::ensembleExtend {ensemble subcommand proc} {
    set map [namespace ensemble configure $ensemble -map]
    dict set map $subcommand $proc
    namespace ensemble configure $ensemble -map $map
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
proc ::lwutils::lremove {list indices} {
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
proc ::lwutils::unoctalize {int} {
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
proc ::lwutils::compareVersions {v1 v2} {
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
proc ::lwutils::stringEscape {str} {
    return [regsub -all {\W} $str {\\&}]
}

# Extend the string ensemble with [string escape]
::lwutils::ensembleExtend string escape ::lwutils::stringEscape

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
proc ::lwutils::stringPad {string length {char " "} {atleast 0}} {
    # Pad the string with the given character
    append string [string repeat $char $atleast] [string repeat $char [expr {$length-[string length $string]-$atleast}]]
    # Return the padded string
    return $string
}

# Extend the string ensemble with [string pad]
::lwutils::ensembleExtend string pad ::lwutils::stringPad

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
proc ::lwutils::stringIs {args} {
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
::lwutils::ensembleExtend string is ::lwutils::stringIs

#############################################################################
# Custom ::tcl::info::script subcommand to the info ensemble.
#
# Options:
#   -bare       return the script name without leading path nor trailing .tcl
#
# Arguments:
#   filename    new script name (optional)
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   currently evaluated script name
#############################################################################
proc ::lwutils::infoScript {args} {
    # Parse the arguments
    set usage "info script ?options? ?filename?"
    set options {
        {bare       "strip leading path and trailing .tcl"}
    }
    array set params [::cmdline::getoptions args $options "$usage\noptions:"]
    if {[llength $args] > 1} {
        return -code error "wrong # args: should be \"$usage\""
    }

    # Query mode: use the current script name
    if {[llength $args] eq 0} {
        set filename [::tcl::info::script]
    # Update mode: use the provided script name
    } else {
        lassign $args filename
    }

    # Process the script name
    if {$params(bare)} {
        # Strip the path
        set filename [file tail $filename]
        # Strip any trailing .tcl extension
        if {[file extension $filename] eq ".tcl"} {
            set filename [file rootname $filename]
        }
    }

    # Query mode: return the script name
    if {[llength $args] eq 0} {
        return $filename
    # Update mode: update the script name
    } else {
        ::tcl::info::script $filename
    }
}

# Replace the info ensemble's [info script]
::lwutils::ensembleExtend info script ::lwutils::infoScript

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
proc ::lwutils::infoPCExists {args} {
    # Parse the arguments
    set usage "info pcexists ?options? name"
    set options {
        {proc       "test for existence of a proc only"}
        {command    "test for existence of a command only"}
    }
    array set params [::cmdline::getoptions args $options "$usage\noptions:"]
    if {[llength $args] ne 1} {
        return -code error "wrong # args: should be \"$usage\""
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
::lwutils::ensembleExtend info pcexists ::lwutils::infoPCExists

#############################################################################
# Dereference the last component in a file name until an actual file is reached.
#
# Arguments:
#   name        file name to dereference
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   dereferenced file name
#############################################################################
proc ::lwutils::fileDereference {args} {
    # Parse the arguments
    set usage "file dereference name"
    if {[llength $args] ne 1} {
        return -code error "wrong # args: should be \"$usage\""
    }
    lassign $args name

    # While the file name is a link
    while {[file type $name] eq "link"} {
        # Read the link target
        set link [file readlink $name]
        # If the link target is relative, prepend the file dirname
        if {[file pathtype $link] eq "relative"} {
            set name [file join [file dirname $name] $link]
        } else {
            set name $link
        }
    }

    # Return the fully dereferenced name
    return $name
}

# Extend the file ensemble with [file dereference]
::lwutils::ensembleExtend file dereference ::lwutils::fileDereference

#############################################################################
# Assign the value of multiple key paths in a dictionary.
#
# NB: This proc uses key paths: a list of keys, for nested dicts.
#     This means that even when accessing the first level of the dict, the
#     given key path arguments must be lists, otherwise single keys that look
#     like lists will cause an attempt at reaching a nested dict.
#     E.g.:
#       $ set d [dict create a A [list b c] "B C"]
#       > a A {b c} {B C}
#
#       $ dict assign $d [list a] va [list [list b c]] vbc
#       # OK: triggers [dict get $d [list b c]]
#
#       $ dict assign $d a va [list b c] vbc
#       > key "b" not known in dictionary
#       # KO: triggers [dict get $d b c]
#       #     works for 'a' though
#
# Arguments:
#   dict        dictionary value to assign values from
#   keyPath     dictionary key path to the value to get (each item is the
#               list goes one nested dict deeper: 
#   variable    variable name in which to store the value for the key
#
# Globals: NONE
#
# Variables: NONE
#
# Return: NONE
#############################################################################
proc ::lwutils::dictAssign {dict args} {
    # Parse the arguments
    set usage "dict assign dictionaryValue keyPath variable ?keyPath variable ...?"
    if {([llength $args] < 2) || (([llength $args] % 2) ne 0)} {
        return -code error "wrong # args: should be \"$usage\""
    }

    # Loop over the (key,variable) pairs
    foreach {keypath variable} $args {
        # Assign the dict's value for the key to the given caller variable
        upvar $variable v
        set v [dict get $dict {*}$keypath]
    }
}

# Extend the dict ensemble with [dict assign]
::lwutils::ensembleExtend dict assign ::lwutils::dictAssign

#############################################################################
# Foreach loop with an else body executed when the list is empty.
# With multiple lists, the else body is executed iff all are empty.
#
# Arguments:
#   varList     list of variable names to assign consecutive elements of the
#               following list to
#   list        list to iterate over
#   body        body to execute for each list element
#   else body   body to execute if all lists to iterate over are empty
#
# Globals: NONE
#
# Variables: NONE
#
# Return: NONE
#############################################################################
proc ::lwutils::foreachelse {args} {
    # Parse the arguments
    set usage "foreach varList list ?varList list ...? body else body"
    if {([llength $args] < 5) || (([llength $args] % 2) ne 1) || ([lindex $args end-1] ne "else")} {
        return -code error "wrong # args: should be \"$usage\""
    }
    set pairs [lrange $args 0 end-3]
    set body [lindex $args end-2]
    set elsebody [lindex $args end]

    # Test for emptiness
    set empty 1
    foreach {v l} $pairs {
        if {[llength $l]} {
            # Found a non-empty list: bail out
            set empty 0
            break
        }
    }

    # Either run the loop or its else body
    if {$empty} {
        uplevel 1 $elsebody
    } else {
        uplevel 1 [list foreach {*}$pairs $body]
    }
}

#############################################################################
# Generate a sequence of characters, using the given first and last
# characters.
#
# Arguments:
#   first       first character in the sequence
#   last        last character in the sequence
#   incr        character increment (default: 1)
#
# Globals: NONE
#
# Variables: NONE
#
# Return:
#   list of characters
#############################################################################
proc ::lwutils::stringSequence {first last {incr 1}} {
    # Test for invalid increment
    if {$incr eq 0} {
        return -code error "null increment"
    }

    # Get the first and last characters as integers
    scan ${first}${last} %c%c ifirst ilast

    # Loop from first to last character
    set sequence {}
    set loop [expr {$incr > 0 ? {$i <= $ilast} : {$i >= $ilast}}]
    for {set i $ifirst} $loop {incr i $incr} {
        lappend sequence [format %c $i]
    }

    # Return the result
    return $sequence
}

# Extend the info ensemble with [string sequence]
::lwutils::ensembleExtend string sequence ::lwutils::stringSequence


################################ End of file ################################
