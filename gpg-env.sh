#!/bin/bash

set -e

# --- Configuration ---
# Default GPG_ENV_PREFIX to empty, can be overridden by environment variable.
# Example: export GPG_ENV_PREFIX="dev" will make the script look for ".env.dev.gpg".
GPG_ENV_PREFIX="${GPG_ENV_PREFIX:-}"

# Construct GPG_ENV_FILE based on GPG_ENV_PREFIX.
# If GPG_ENV_PREFIX is "dev", GPG_ENV_FILE becomes ".env.dev.gpg".
# If GPG_ENV_PREFIX is empty, GPG_ENV_FILE becomes ".env.gpg".
if [ -n "$GPG_ENV_PREFIX" ]; then
  GPG_ENV_FILE=".env.${GPG_ENV_PREFIX}.gpg"
else
  GPG_ENV_FILE=".env.gpg"
fi

# Default GPG_ENV_INIT_FILE to .env, or .env.<prefix> if GPG_ENV_PREFIX is set.
# This is the plaintext file that 'init' encrypts initially.
if [ -n "$GPG_ENV_PREFIX" ]; then
  DEFAULT_INIT_FILE_NAME=".env.${GPG_ENV_PREFIX}"
else
  DEFAULT_INIT_FILE_NAME=".env"
fi
GPG_ENV_INIT_FILE="${GPG_ENV_INIT_FILE:-$DEFAULT_INIT_FILE_NAME}"


# Modify EDITOR variable:
# 1. Prioritize GPG_ENV_EDITOR if set.
# 2. Fallback to existing EDITOR environment variable.
# 3. Default to 'vim' if neither is set.
EDITOR="${GPG_ENV_EDITOR:-${EDITOR:-vim}}"

# --- Helper Functions ---

# usage: Prints the script's usage instructions.
function usage() {
  echo "Usage: $0 <command>"
  echo ""
  echo "Commands:"
  echo "  init              : Initializes a new encrypted environment file ($GPG_ENV_FILE) from a plaintext file ($GPG_ENV_INIT_FILE)."
  echo "                    Requires $GPG_ENV_INIT_FILE to exist first."
  echo "  edit              : Decrypts $GPG_ENV_FILE, opens it in '$EDITOR', and re-encrypts on save."
  echo "  view              : Decrypts and prints the content of $GPG_ENV_FILE to stdout."
  echo "  import            : Decrypts $GPG_ENV_FILE and prints 'export' commands to stdout."
  echo "                    Designed to be used with 'eval \"\$($0 import)\"' to load variables."
  echo "  status            : Shows the current status of the GPG-encrypted environment file and available environments."
  echo "  enable-direnv     : Configures the current directory's .envrc file to automatically load secrets via direnv."
  echo "                    Appends 'eval \"\$($0 import)\"' to .envrc if not present."
  echo "  update-pass       : Changes the passphrase for the encrypted environment file ($GPG_ENV_FILE)."
  echo ""
  echo "Configuration Environment Variables (can be set before running commands):"
  echo "  GPG_ENV_FILE      : Path to the encrypted environment file (default: .env.gpg or .env.<prefix>.gpg)"
  echo "  GPG_ENV_INIT_FILE : Path to the initial plaintext file for 'init' command (default: .env or .env.<prefix>)"
  echo "  GPG_ENV_EDITOR    : Editor to use for 'edit' command (overrides EDITOR)"
  echo "  GPG_ENV_PREFIX    : Prefix for the environment file (e.g., 'dev' for '.env.dev.gpg')"
  exit 1
}

# gpg_decrypt: Decrypts a GPG file.
# Reads the passphrase from stdin (file descriptor 0).
# Outputs the decrypted content to stdout.
# Arguments:
#   $1: Path to the GPG-encrypted file.
function gpg_decrypt() {
  gpg --quiet --batch --yes --decrypt --passphrase-fd 0 "$1"
}

# gpg_encrypt: Encrypts a file using symmetric AES256.
# Reads the passphrase from stdin (file descriptor 0).
# Outputs the encrypted content to the specified output file.
# Arguments:
#   $1: Path to the output encrypted file.
#   $2: Path to the plaintext file to encrypt.
function gpg_encrypt() {
  gpg --quiet --batch --yes --symmetric --cipher-algo AES256 --passphrase-fd 0 -o "$1" "$2"
}

# --- Commands ---

# cmd_init: Initializes a new encrypted environment file.
# It encrypts the content of GPG_ENV_INIT_FILE (default: .env) into GPG_ENV_FILE (default: .env.gpg).
function cmd_init() {
  if [ -f "$GPG_ENV_FILE" ]; then
    echo "Error: $GPG_ENV_FILE already exists."
    exit 1
  fi

  if [ ! -f "$GPG_ENV_INIT_FILE" ]; then
    echo "Error: $GPG_ENV_INIT_FILE not found. Create a plaintext file named '$GPG_ENV_INIT_FILE' first."
    exit 1
  fi

  echo "Enter passphrase to encrypt $GPG_ENV_INIT_FILE:"
  read -s passphrase # Read passphrase silently
  echo "$passphrase" | gpg_encrypt "$GPG_ENV_FILE" "$GPG_ENV_INIT_FILE"
  echo "$GPG_ENV_FILE created."
}

# cmd_edit: Decrypts the GPG file, opens it in the configured editor, then re-encrypts it.
# Ensures the temporary decrypted file is removed afterwards.
function cmd_edit() {
  if [ ! -f "$GPG_ENV_FILE" ]; then
    echo "Error: $GPG_ENV_FILE not found. Run 'init' first."
    exit 1
  fi

  echo "Enter passphrase to decrypt $GPG_ENV_FILE:"
  read -s passphrase

  temp_file=$(mktemp) # Create a secure temporary file
  trap 'rm -f "$temp_file"' EXIT # Ensure temp file is removed on script exit

  # Decrypt content to the temporary file
  echo "$passphrase" | gpg_decrypt "$GPG_ENV_FILE" > "$temp_file"

  # Check if decryption was successful (file exists and is not empty, implying correct passphrase)
  if [ ! -s "$temp_file" ]; then # -s checks if file exists and is not empty
      echo "Error: Decryption failed or file is empty. Check passphrase."
      exit 1
  fi

  # Open the temporary file in the configured editor
  "$EDITOR" "$temp_file"

  # Re-encrypt the content from the temporary file back into the GPG file
  echo "$passphrase" | gpg_encrypt "$GPG_ENV_FILE" "$temp_file"
  echo "$GPG_ENV_FILE updated."
}

# cmd_view: Decrypts and prints the content of the GPG file to standard output.
function cmd_view() {
  if [ ! -f "$GPG_ENV_FILE" ]; then
    echo "Error: $GPG_ENV_FILE not found. Run 'init' first."
    exit 1
  fi

  echo "Enter passphrase to decrypt $GPG_ENV_FILE:"
  read -s passphrase
  echo "$passphrase" | gpg_decrypt "$GPG_ENV_FILE"
}

# cmd_import: Decrypts the GPG file and prints 'export' commands to stdout.
# This function is designed to be used with `eval "$(gpg-env.sh import)"`
# to load variables into the current shell session.
function cmd_import() {
  if [ ! -f "$GPG_ENV_FILE" ]; then
    echo "Error: $GPG_ENV_FILE not found. Run 'init' first." >&2 # Output error to stderr
    return 1 # Return non-zero status for shell sourcing
  fi

  echo "Enter passphrase to decrypt $GPG_ENV_FILE:" >&2 # Output prompt to stderr
  read -s passphrase

  # Decrypt content and capture it in a variable
  DECRYPTED_CONTENT=$(echo "$passphrase" | gpg_decrypt "$GPG_ENV_FILE")
  
  # Check if decryption was successful or if content is empty
  if [ $? -ne 0 ] || [ -z "$DECRYPTED_CONTENT" ]; then
      echo "Error: Decryption failed or decrypted content is empty. Check passphrase." >&2
      return 1
  fi

  # Parse decrypted content line by line and print 'export' commands
  while IFS='=' read -r key value; do
    # Skip empty lines and lines starting with '#' (comments)
    if [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    # Trim leading/trailing whitespace and remove quotes from key and value
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    # Print the export command. printf %q safely quotes the value for shell export.
    printf "export %s=%q\n" "$key" "$value"
  done <<< "$DECRYPTED_CONTENT" # Use here string to feed content to the while loop
}

# cmd_status: Shows the current status of the GPG-encrypted environment file and available environments.
function cmd_status() {
  echo ""
  local current_env_status=""
  if [ -n "$GPG_ENV_PREFIX" ]; then
    current_env_status+=" (GPG_ENV_PREFIX: '$GPG_ENV_PREFIX')"
  else
    current_env_status+=" (GPG_ENV_PREFIX: not set, using default)"
  fi

  # Check if the current environment file exists to mark it as 'active'
  if [ -f "$GPG_ENV_FILE" ]; then
    echo -e "$current_env_status" # Green and asterisk for activated
  else
    echo "$current_env_status" # No color/asterisk if file doesn't exist
    echo "Encrypted environment file ($GPG_ENV_FILE): NOT FOUND. Run 'init' to create it."
  fi

  echo "Available encrypted environment files in current directory:"
  local found_envs=()
  # Find files matching the pattern .env.*.gpg or .env.gpg
  for file in .env.*.gpg .env.gpg; do
    if [ -f "$file" ]; then
      local prefix="${file#*.env.}" # Remove .env. prefix
      prefix="${prefix%.gpg}"       # Remove .gpg suffix
      if [ "$prefix" = "gpg" ]; then # This means the file was .env.gpg
	found_envs+=("default ($file)")
      else
	found_envs+=("'$prefix' ($file)")
      fi
    fi
  done

  if [ ${#found_envs[@]} -eq 0 ]; then
    echo "  No *.env.gpg files found."
  else
    for env_name in "${found_envs[@]}"; do
      echo -e "\033[0;32m$env_name\033[0m"
    done
  fi

  echo "" # Add a newline for spacing
  echo "Remember to add '.env*' to your .gitignore if it contains sensitive information." # Modified .gitignore hint
  echo ""
}

# cmd_enable_direnv: Appends the direnv import line to .envrc and suggests 'direnv allow'.
# It also prepends GPG_ENV_FILE, GPG_ENV_INIT_FILE, GPG_ENV_EDITOR, and GPG_ENV_PREFIX
# with their current values to the .envrc, if they are not already present.
function cmd_enable_direnv() {
  local direnv_line="eval \"\$($0 import)\""
  local envrc_file=".envrc"

  if ! command -v direnv &> /dev/null; then
    echo "Error: direnv is not installed. Please install direnv first."
    return 1
  fi

  # Capture current values of configuration variables to write them to .envrc
  local current_gpg_env_file_val="$GPG_ENV_FILE"
  local current_gpg_env_init_file_val="$GPG_ENV_INIT_FILE"
  local current_gpg_env_editor_val="$EDITOR" # Use the resolved EDITOR value
  local current_gpg_env_prefix_val="$GPG_ENV_PREFIX"

  # Lines to prepend to .envrc for configuration
  # Use the current, resolved values of the variables
  local config_lines=(
    "export GPG_ENV_FILE=\"$current_gpg_env_file_val\""
    "export GPG_ENV_INIT_FILE=\"$current_gpg_env_init_file_val\""
    "export GPG_ENV_EDITOR=\"$current_gpg_env_editor_val\""
  )
  # Add GPG_ENV_PREFIX export only if it's explicitly set (not empty)
  if [ -n "$current_gpg_env_prefix_val" ]; then
    config_lines+=("export GPG_ENV_PREFIX=\"$current_gpg_env_prefix_val\"")
  else
    # If prefix is not set, ensure it's explicitly unset or set to empty in .envrc
    # to prevent accidental inheritance from parent directories if .envrc is sourced up.
    config_lines+=("unset GPG_ENV_PREFIX")
  fi

  if [ -f "$envrc_file" ]; then
    echo "Updating $envrc_file..."
    local temp_envrc=$(mktemp)

    # Add config lines if they don't exist
    for line in "${config_lines[@]}"; do
      # Check if the line (or a similar export for the same variable) already exists
      # This is a bit tricky to make robust. A simpler approach is to always prepend
      # and let later exports override, but for .envrc, explicit is often better.
      # For now, a simple grep -qF is used, which might miss if only value differs.
      # A more robust check might involve parsing the .envrc.
      if ! grep -qF "$line" "$envrc_file" && ! grep -qE "^export ${line%%=*}=" "$envrc_file"; then
        echo "$line" >> "$temp_envrc"
        echo "  Added config line: $line"
      fi
    done

    # Add the main import line if it doesn't exist
    if ! grep -qF "$direnv_line" "$envrc_file"; then
      echo "$direnv_line" >> "$temp_envrc"
      echo "  Added import line: $direnv_line"
    fi

    # Append existing content of .envrc to temp file
    cat "$envrc_file" >> "$temp_envrc"
    mv "$temp_envrc" "$envrc_file" # Overwrite original with new content
    
  else
    echo "Creating $envrc_file and adding configuration and import lines..."
    # Create new file with config and import lines
    for line in "${config_lines[@]}"; do
      echo "$line"
    done > "$envrc_file"
    echo "$direnv_line" >> "$envrc_file"
    echo "$envrc_file created with configuration and import lines."
  fi

  echo ""
  echo "Now, run 'direnv allow' in this directory to enable direnv to load your secrets:"
  echo "  direnv allow"
  echo "Remember to add '$envrc_file' to your .gitignore if it contains sensitive information."
}

# cmd_update_pass: Changes the passphrase for the encrypted environment file.
function cmd_update_pass() {
  if [ ! -f "$GPG_ENV_FILE" ]; then
    echo "Error: $GPG_ENV_FILE not found. Run 'init' first."
    exit 1
  fi

  echo "Enter CURRENT passphrase to decrypt $GPG_ENV_FILE:"
  read -s old_passphrase

  temp_file=$(mktemp)
  trap 'rm -f "$temp_file"' EXIT

  # Attempt to decrypt with old passphrase
  DECRYPT_OUTPUT=$(echo "$old_passphrase" | gpg_decrypt "$GPG_ENV_FILE" 2>&1)
  if [ $? -ne 0 ]; then
      echo "Error: Incorrect passphrase or decryption failed."
      echo "$DECRYPT_OUTPUT" # Show GPG's error output
      exit 1
  fi
  echo "$DECRYPT_OUTPUT" > "$temp_file" # Write decrypted content to temp file

  # Check if decrypted file is empty (might indicate wrong passphrase even if gpg returned 0)
  if [ ! -s "$temp_file" ]; then
      echo "Error: Decryption yielded empty content. Passphrase might be incorrect or file corrupted."
      exit 1
  fi

  echo "Enter NEW passphrase for $GPG_ENV_FILE:"
  read -s new_passphrase
  echo "Confirm NEW passphrase:"
  read -s confirm_new_passphrase

  if [ "$new_passphrase" != "$confirm_new_passphrase" ]; then
    echo "Error: New passphrases do not match."
    exit 1
  fi

  # Re-encrypt with the new passphrase
  echo "$new_passphrase" | gpg_encrypt "$GPG_ENV_FILE" "$temp_file"
  echo "$GPG_ENV_FILE passphrase updated successfully."
}


# --- Main execution logic ---
# Handles command-line arguments to call the appropriate function.
case "$1" in
  init)
    cmd_init
    ;;
  edit)
    cmd_edit
    ;;
  view)
    cmd_view
    ;;
  import)
    cmd_import
    ;;
  status)
    cmd_status
    ;;
  enable-direnv)
    cmd_enable_direnv
    ;;
  update-pass)
    cmd_update_pass
    ;;
  *)
    usage # If no valid command is given, show usage
    ;;
esac

