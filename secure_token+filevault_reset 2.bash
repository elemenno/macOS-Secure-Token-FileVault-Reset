#!/bin/bash


#----------------------------------------------------------------------
#
#                   Created by Pat Servedio
#                           2025.06.13
Version=1.0
ScriptName=`basename "$0"`
ShowVersion="$ScriptName $Version"
#
#       Having trouble with Secure Token or FileVault access?
#
#           This tool will:
#               • List local user accounts with their Secure Token status
#               • Allow you to select which user to repair
#               • Temporarily disable and re-enable Secure Token
#               • Restore FileVault unlock access if needed
#
#           You will be prompted for:
#               • Your account password
#               • A Secure Token–enabled admin's username and password
#
#   Please save your work before continuing. You may be asked for your password again after logout or reboot.
#
#               A detailed log of the process is saved to:
#                   /var/tmp/secure_token_reset.log
#
#----------------------------------------------------------------------


# Log File

logFile="/Library/GMLogs/secure_token_reset.log"
exec 1>>"$logFile"
exec 2>&1


timestamp=$(date "+%Y-%m-%d %H:%M:%S")
echo "===== Secure Token & FileVault Reset Script Started at $timestamp ====="



# ---------- Functions Start ------------------------------------------

get_input() {
    /usr/bin/osascript <<EOF
        text returned of (display dialog "$1" default answer "" with title "Secure Token Reset" buttons {"OK"} default button "OK")
EOF
}

get_password() {
    /usr/bin/osascript <<EOF
        text returned of (display dialog "$1" default answer "" with hidden answer with title "Secure Token Reset" buttons {"OK"} default button "OK")
EOF
}

show_info() {
    /usr/bin/osascript -e 'display dialog "'"$1"'" buttons {"OK"} default button "OK" with title "Secure Token Reset"'
}

choose_from_dropdown() {
    /usr/bin/osascript <<EOF
        choose from list {$1} with prompt "Select a user account to reset Secure Token:" default items {""} without multiple selections allowed and empty selection allowed
EOF
}

# Confirm user wants to proceed
proceed=$(/usr/bin/osascript <<EOF
    button returned of (display dialog "Please save all work. This process will disable and re-enable Secure Token while the user is logged in. It may also adjust FileVault access. You may be prompted for your password again after reboot or logout.

Are you sure you want to continue?" buttons {"Cancel", "OK"} default button "OK" with title "Secure Token Reset Warning")
EOF
)

check_secure_token_error() {
    local output="$1"
    if echo "$output" | grep -q "Operation is not permitted without secure token unlock"; then
        /usr/bin/osascript -e 'display dialog "The credentials provided do not have Secure Token rights.\n\nPlease check that both the account and password are correct.\n\nIf this issue continues, contact IT support." buttons {"OK"} default button "OK" with title "Secure Token Error"'
        echo "Aborting due to Secure Token permission error."
        exit 1
    fi
}


# ----------- Functions End ----------------------------------



if [[ "$proceed" != "OK" ]]; then
    echo "User canceled operation."
    exit 1
fi


# Gather user list with Secure Token status
echo "Getting list of local users and Secure Token status..."
userChoices=""
userList=()


# Exclude system and service accounts
excludedUsers="^_|daemon|nobody|root|jamfadmin|mfe"

for user in $(dscl . list /Users UniqueID | awk '$2 >= 500 { print $1 }' | grep -vE "$excludedUsers"); do
    tokenStatus=$(/usr/sbin/sysadminctl -secureTokenStatus "$user" 2>&1 | grep -o "ENABLED\|DISABLED")
    echo "$user: Secure Token $tokenStatus"
    userList+=("\"$user [$tokenStatus]\"")
done

if [[ ${#userList[@]} -eq 0 ]]; then
    show_info "No valid local users found with UID ≥ 500."
    exit 1
fi


# Join user list into AppleScript-compatible format
joinedList=$(IFS=, ; echo "${userList[*]}")

# Dropdown menu to select user
targetSelection=$(choose_from_dropdown "$joinedList")
targetUser=$(echo "$targetSelection" | sed -E 's/ \[.*\]//')

if [[ -z "$targetUser" || "$targetUser" == "false" ]]; then
    echo "User canceled selection."
    exit 1
fi

echo "Selected user: $targetUser"


# Prompt for credentials
targetPass=$(get_password "Enter the password for user '$targetUser':")
adminUser=$(get_input "Enter the Secure Token admin username:")
adminPass=$(get_password "Enter the password for admin user '$adminUser':")


# Pre-check FileVault token
echo ""
echo "--- FileVault Unlock Status BEFORE ---"
if fdesetup list | grep -q "^$targetUser,"; then
    fvStatusBefore="Yes"
    echo "$targetUser IS a FileVault unlock user."
else
    fvStatusBefore="No"
    echo "$targetUser is NOT a FileVault unlock user."
fi


# Check Secure Token before
echo ""
echo "--- Secure Token Status BEFORE ---"
/usr/sbin/sysadminctl -secureTokenStatus "$targetUser"


# Disable Secure Token
echo ""
echo "--- Disabling Secure Token for $targetUser ---"
output=$(/usr/sbin/sysadminctl -secureTokenOff "$targetUser" -password "$targetPass" -adminUser "$adminUser" -adminPassword "$adminPass" 2>&1)
echo "$output"
check_secure_token_error "$output"

sleep 2


# Check after disabling
echo ""
echo "--- Secure Token Status AFTER Disabling ---"
/usr/sbin/sysadminctl -secureTokenStatus "$targetUser"


# Re-enable Secure Token
echo ""
echo "--- Re-enabling Secure Token for $targetUser ---"
output=$(/usr/sbin/sysadminctl -secureTokenOn "$targetUser" -password "$targetPass" -adminUser "$adminUser" -adminPassword "$adminPass" 2>&1)
echo "$output"
check_secure_token_error "$output"

sleep 2


# Final token check
echo ""
echo "--- Final Secure Token Status ---"
tokenStatus=$(/usr/sbin/sysadminctl -secureTokenStatus "$targetUser" 2>&1 | grep "Secure token is")
echo "$tokenStatus"


# Final FileVault check
echo ""
echo "--- FileVault Unlock Status AFTER ---"
if fdesetup list | grep -q "^$targetUser,"; then
    fvStatusAfter="Yes"
    echo "$targetUser IS a FileVault unlock user (after reset)."
else
    fvStatusAfter="No"
    echo "$targetUser is NOT a FileVault unlock user (after reset). Attempting to add..."
    
    echo "$adminPass" | fdesetup add -usertoadd "$targetUser" -user "$adminUser" -stdin <<< "$targetPass"
    
    if fdesetup list | grep -q "^$targetUser,"; then
        fvStatusAfter="Now Added"
        echo "$targetUser successfully added to FileVault unlock users."
    else
        fvStatusAfter="Failed to Add"
        echo "Failed to add $targetUser to FileVault unlock users."
    fi
fi


# Final popup
show_info "Secure Token reset completed for '$targetUser'.\n\nSecure Token: $tokenStatus\nFileVault Unlock Before: $fvStatusBefore\nFileVault Unlock After: $fvStatusAfter\n\nLog saved to: $logFile"

exit 0
