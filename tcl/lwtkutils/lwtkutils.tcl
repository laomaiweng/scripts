#############################################################################
#   lwtkutils - Laomai Weng's Tk Utilities                                  #
#                                                                           #
# Author: laomaiweng <laomaiweng AT minster DOT io>                         #
#                                                                           #
# Useful Tk utilities.                                                      #
#                                                                           #
# History:                                                                  #
# * v1.0    initial version                                                 #
#############################################################################

package provide lwtkutils 1.0


# Package dependencies
#package require cmdline


# Define the lwtkutils namespace and export its procedures
namespace eval lwtkutils {
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
# Scroll a combobox widget using the mouse wheel.
# Bind to the combobox's <MouseWheel> event.
# Triggers a <<ComboboxSelected>> event after selecting the new value.
#
# Works with non-Tk/ttk combobox widgets as long as they provide the
# following subcommands:
# * `cget -values`
# * `current`
#
# Arguments:
#   w           combobox widget to scroll
#   delta       scroll delta
#   fillproc    optional procedure to call to fill the combobox if empty
#
# Globals: NONE
#
# Variables: NONE
#
# Return: NONE
#############################################################################
proc ::lwtkutils::ScrollCombobox {w delta {fillproc ""}} {
    # Refill the combobox if provided with a combobox-filling procedure
    set l [llength [$w cget -values]]
    if {$l == 0 && $fillproc ne ""} {
        {*}$fillproc
        set l [llength [$w cget -values]]
        if {$l == 0} {return}
    }

    # Get the current index
    set index [$w current]

    # Update the index
    if {$index == -1} {
        set index [expr {$delta > 0 ? $l-1 : 0}]
    } else {
        incr index [expr {$delta > 0 ? -1 : 1}]
    }
    if {$index < 0 || $l <= $index} {return}

    # Select the new index
    $w current $index
    event generate $cb <<ComboboxSelected>>

    return
}


################################ End of file ################################
