gpg-env.sh - GPG Encrypted Environment Variable Manager
gpg-env.sh is a simple shell script designed to help you securely manage project-specific environment variables by encrypting them with GPG. It allows you to store sensitive information (like API keys, database credentials) in an encrypted file and decrypt them on demand, optionally integrating with direnv for automatic loading.

Table of Contents
Features

Prerequisites

Installation

Usage

Commands

Configuration Environment Variables

Integration with direnv (Recommended)

Security Considerations

Contributing

License

Features
Encrypt/Decrypt: Securely encrypts and decrypts your environment variables using GPG symmetric encryption (AES256).

Edit in Place: Decrypts the file, opens it in your preferred editor, and re-encrypts it automatically on save.

View Content: Safely view the decrypted contents of your environment file.

Import Variables: Generates export commands to load variables into your current shell session.

direnv Integration: Automates the loading and unloading of variables when entering/leaving project directories.

Passphrase Management: Easily update the passphrase for your encrypted environment file.

Environment Switching: Supports managing multiple environment files (e.g., dev, prod) using prefixes.

Status Check: Provides an overview of your current GPG environment setup and available encrypted files.

Prerequisites
Bash: The script is written in Bash.

GnuPG (GPG): You need GPG installed on your system. Most Linux distributions and macOS come with it pre-installed.

To check: gpg --version

mktemp: For creating secure temporary files (usually available by default).

direnv (Optional, but Recommended): For automatic environment loading.

To install: brew install direnv (macOS), sudo apt install direnv (Debian/Ubuntu), etc.

Remember to hook direnv into your shell (e.g., eval "$(direnv hook bash)" in ~/.bashrc).

Installation
Download the script:

curl -o gpg-env https://raw.githubusercontent.com/OppOops/gpg-env/refs/heads/main/gpg-env.sh # Replace with actual URL

(Or simply copy the script content into a file named gpg-env.sh)

Make it executable:

chmod +x gpg-env

Optional: Add to your PATH:
For easier access, move the script to a directory in your PATH (e.g., /usr/local/bin or ~/bin):

sudo mv gpg-env /usr/local/bin/
# OR
mkdir -p ~/bin && mv gpg-env ~/bin/

If you move it to ~/bin, ensure ~/bin is in your shell's PATH.

Usage
Navigate to your project's root directory where you want to manage your environment variables.

Commands
init: Initializes a new encrypted environment file.
Before running init, create a plaintext file named .env (or .env.<prefix> if using GPG_ENV_PREFIX) with your key-value pairs.

# Example: Create a plaintext .env file
echo "MY_API_KEY=supersecret123" > .env
echo "DB_USER=admin" >> .env

# Then initialize the encrypted file
./gpg-env.sh init
# Prompts for a passphrase to encrypt .env into .env.gpg

edit: Decrypts the current environment file, opens it in your configured editor, and re-encrypts it upon saving.

./gpg-env.sh edit
# Prompts for passphrase, opens editor, re-encrypts on save.

view: Decrypts and prints the content of the current environment file to your terminal.

./gpg-env.sh view
# Prompts for passphrase, prints content.

import: Decrypts the current environment file and outputs export commands. This is primarily used for direnv integration.

# To manually load variables (less common, direnv is preferred)
eval "$(./gpg-env.sh import)"
# Prompts for passphrase, then variables are loaded into current shell.

status: Shows the current GPG environment file in use, indicates if it exists, and lists all available encrypted environment files (.env*.gpg) in the current directory.

./gpg-env.sh status

enable-direnv: Configures your project's .envrc file to automatically load secrets via direnv.

./gpg-env.sh enable-direnv
# This will create/update .envrc with necessary lines.
# Follow the instructions to run 'direnv allow'.

update-pass: Changes the passphrase for the current encrypted environment file.

./gpg-env.sh update-pass
# Prompts for current and new passphrases.

Configuration Environment Variables
You can customize gpg-env.sh's behavior by setting these environment variables before running commands:

GPG_ENV_FILE: Specifies the path to the encrypted environment file.

Default: .env.gpg or .env.<GPG_ENV_PREFIX>.gpg

GPG_ENV_INIT_FILE: Specifies the path to the plaintext file used by init.

Default: .env or .env.<GPG_ENV_PREFIX>

GPG_ENV_EDITOR: Sets the editor to use for the edit command, overriding the system's EDITOR.

Example: export GPG_ENV_EDITOR="code --wait"

GPG_ENV_PREFIX: If set, the script will look for environment files with this prefix.

Example: export GPG_ENV_PREFIX="prod" will make init, edit, import, etc., operate on .env.prod.gpg (and expect .env.prod for init).

# Example: Initialize a 'staging' environment
echo "STAGING_API_KEY=xyz" > .env.staging
GPG_ENV_PREFIX=staging ./gpg-env.sh init
# This will create .env.staging.gpg

Integration with direnv (Recommended)
direnv is highly recommended for a seamless workflow. Once direnv is installed and hooked into your shell:

Run enable-direnv:

./gpg-env.sh enable-direnv

This command will create/update your project's .envrc file, adding lines to set gpg-env.sh's configuration variables (like GPG_ENV_PREFIX if it was set when you ran enable-direnv) and the eval "$($0 import)" command.

Allow direnv:

direnv allow

The first time you enter a directory with a new or modified .envrc, direnv will block and prompt you to allow it. This is a security feature.

Now, whenever you cd into your project directory, direnv will automatically execute the import command from gpg-env.sh, prompt you for your passphrase, and load your environment variables. When you cd out, direnv will automatically unset them.

Security Considerations
Passphrase Strength: The security of your encrypted environment file relies entirely on the strength of the passphrase you choose. Use a long, complex, and unique passphrase.

.gitignore: Always add .env* to your project's .gitignore file. This prevents accidentally committing your plaintext .env files, your encrypted .env.gpg files, or your .envrc file (which contains the eval command) to version control.

# .gitignore
.env*

Temporary Files: gpg-env.sh uses secure temporary files (mktemp) and trap to ensure they are cleaned up after use.

import Command Security: The import command outputs export statements to stdout. While eval captures this, be mindful in shared environments that the output could theoretically be intercepted if not handled carefully. This tool is primarily designed for local development and CI/CD environments where the shell context is controlled.

Portability: .gpg files are based on the OpenPGP standard and are highly portable. You can move your .env.gpg file to another system with GPG installed and decrypt it using the same passphrase.

Contributing
Feel free to open issues or submit pull requests on the GitHub repository if you have suggestions or improvements.

License
This project is licensed under the MIT License.
