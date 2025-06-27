# Secure Token Reset & FileVault Repair Tool (macOS + Jamf Self Service)

This script allows a Jamf-managed macOS device to:
- List all local user accounts (excluding system/service users)
- Show Secure Token status (enabled/disabled) for each
- Prompt the user to select a target account via dropdown
- Disable and re-enable Secure Token for that account
- Verify and repair FileVault unlock access
- Log all activity to a local log file
- Provide user-friendly macOS popups for all inputs and results

---

## Use Case

This tool is designed for environments where:
- Secure Token or FileVault access is broken or misconfigured
- A migrated or manually created user is missing Secure Token
- A user cannot unlock FileVault at startup despite having a valid password

---

## How It Works

1. User launches the script via **Jamf Self Service**
2. The script:
   - Lists all valid local users with Secure Token status
   - Prompts for selection of a user to reset
   - Asks for that user's password and an admin with Secure Token
3. The script:
   - Disables and re-enables Secure Token for the selected user
   - Checks if the user is a FileVault unlock user
   - If not, adds them using 'fdesetup add'
4. The script logs results and shows a final summary popup

---

## Requirements

- macOS 10.13 or later (Secure Token introduced in High Sierra)
- Admin account with **Secure Token**
- Jamf Pro with Self Service enabled
- SecureToken-enabled admin user credentials known at runtime

---

## Important Notes

- The script runs in the context of **root** via Jamf
- It uses **AppleScript dialogs** ('osascript') for GUI prompts
- All inputs are sanitized and hidden where appropriate
- If credentials lack Secure Token, the user is prompted to verify and try again
- A detailed log is stored at: '/Library/Logs/secure_token_reset.log'

---

## Security Considerations

- Passwords are only handled in memory
- No credentials are written to disk
- Ensure Self Service policies using this script are limited to IT or trusted technicians

---

## Log Output

All output, including token status, command results, and errors, are logged to:
'Library/Logs/secure_token_reset.log'

