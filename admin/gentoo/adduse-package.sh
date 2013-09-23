#!/bin/bash
# quentin - r3

if [[ $# -lt 2 ]]
then
    echo "Usage: ${0##*/} <atom> <USE flags>"
    echo "  Add or remove package-specific USE flags."
    exit
fi

USEFILE=/etc/portage/package.use
ATOM="$1"
shift

# Check for the atom
LINE="`grep -F "$ATOM" "$USEFILE"`"
if [[ -n "$LINE" ]]
then    # Atom found
    # Sanity check: only 1 atom
    [[ `echo "$LINE" | wc -l` -gt 1 ]] && { echo "Error: more than 1 line match this atom!" >&2 ; exit 1 ; }

    # Extract then suppress any ending comment
    COMMENT="`echo "$LINE" | grep -P -o "[ \t]*#[^#]*$"`"
    LINE="`echo "$LINE" | sed -e "s|[ \t]*#[^#]*$||"`"

    for FLAG in "$@"
    do
        # Check if the flag is already there
        echo "$LINE " | grep -q " $FLAG "   ## Spaces are important
        if [[ $? -eq 1 ]]
        then    # Not there
            # Check if we want to enable or disable the flag
            if [[ "${FLAG::1}" == "-" ]]
            then    # Disable
                # Check if flag is currently enabled
                echo "$LINE " | grep -q " ${FLAG#-} "   ## Spaces are important
                if [[ $? -eq 0 ]]
                then    # Currently enabled
                    # Disable it
                    LINE="`echo "$LINE " | sed -e "s| ${FLAG#-} | $FLAG |g"`"   ## Spaces are important
                    LINE="${LINE%% }"
                else    # Not present
                    # Append it
                    LINE="$LINE $FLAG"
                fi
            else    # Enable
                # Check if flag is currently disabled
                echo "$LINE " | grep -q " -$FLAG "  ## Spaces are important
                if [[ $? -eq 0 ]]
                then    # Currently disabled
                    # Enable it
                    LINE="`echo "$LINE " | sed -e "s| -$FLAG | $FLAG |g"`"  ## Spaces are important
                    LINE="${LINE%% }"
                else    # Not present
                    # Append it
                    LINE="$LINE $FLAG"
                fi
            fi
        fi
    done

    # Add the comment back
    [[ -n "$COMMENT" ]] && LINE="$LINE$COMMENT"

    # Apply the new line
    sed -i -e "\|$ATOM| c $LINE" "$USEFILE"
    echo "$LINE"
else    # Atom not found
    # Append it
    echo "$ATOM $@" | tee -a "$USEFILE"
fi

