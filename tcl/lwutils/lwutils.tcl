#############################################################################
#   lwutils - Laomai Weng's Tcl Utilities                                   #
#                                                                           #
# Author: laomaiweng <laomaiweng AT minster DOT io>                         #
#                                                                           #
# Useful Tcl utilities.                                                     #
#                                                                           #
# History:                                                                  #
# * v1.4    add [foreachelse]                                               #
# * v1.3    add [dict assign]                                               #
# * v1.2    add [file dereference]                                          #
#           rename into 'lwutils'                                           #
#           replace [scriptName] with [info script]                         #
# * v1.1    add [info pcexists] and [string is]                             #
# * v1.0    initial version                                                 #
#############################################################################

package provide lwutils 1.4.0


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
proc ::lwutils::reEscape {str} {
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
        return -code error "wrong number of arguments: should be \"$usage\""
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
        return -code error "wrong number of arguments: should be \"$usage\""
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
# Assign the value of multiple keys in a dictionary.
#
# Arguments:
#   dict        dictionary value to assign values from
#   key         key to get from the dictionary
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
    set usage "dict assign dictionaryValue key variable ?key variable ...?"
    if {([llength $args] < 2) || (([llength $args] % 2) ne 0)} {
        return -code error "wrong number of arguments: should be \"$usage\""
    }

    # Loop over the (key,variable) pairs
    foreach {key variable} $args {
        # Assign the dict's value for the key to the given caller variable
        upvar $variable v
        set v [dict get $dict $key]
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
        return -code error "wrong number of arguments: should be \"$usage\""
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


################################ End of file ################################
