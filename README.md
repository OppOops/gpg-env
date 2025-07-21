# gpg-env.sh - GPG Encrypted Environment Variable Manager

**gpg-env.sh** is a simple shell script designed to help you securely manage project-specific environment variables by encrypting them with GPG. It allows you to store sensitive information (like API keys, database credentials) in an encrypted file and decrypt them on demand, optionally integrating with **direnv** for automatic loading.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Commands](#commands)
- [Configuration Environment Variables](#configuration-environment-variables)
- [Integration with direnv (Recommended)](#integration-with-direnv-recommended)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Encrypt/Decrypt**: Securely encrypts and decrypts your environment variables using GPG symmetric encryption (AES256)
- **Edit in Place**: Decrypts the file, opens it in your preferred editor, and re-encrypts it automatically on save
- **View Content**: Safely view the decrypted contents of your environment file
- **Import Variables**: Generates export commands to load variables into your current shell session
- **direnv Integration**: Automates the loading and unloading of variables when entering/leaving project directories
- **Passphrase Management**: Easily update the passphrase for your encrypted environment file
- **Environment Switching**: Supports managing multiple environment files (e.g., dev, prod) using prefixes
- **Status Check**: Provides an overview of your current GPG environment setup and available encrypted files

## Prerequisites

- **Bash**: The script is written in Bash
- **GnuPG (GPG)**: You need GPG installed on your system. Most Linux distributions and macOS come with it pre-installed
  - To check: `gpg --version`
- **mktemp**: For creating secure temporary files (usually available by default)
- **direnv** (Optional, but Recommended): For automatic environment loading
  - To install: `brew install direnv` (macOS), `sudo apt install direnv` (Debian/Ubuntu), etc.
  - Remember to hook direnv into your shell (e.g., `eval "$(direnv hook bash)"` in `~/.bashrc`)

## Installation

1. **Download the script:**
   ```bash
   curl -o gpg-env.sh https://raw.githubusercontent.com/your-repo/gpg-env.sh/main/gpg-env.sh
   # Replace with actual URL
   ```
   *(Or simply copy the script content into a file named `gpg-env.sh`)*

2. **Make it executable:**
   ```bash
   chmod +x gpg-env.sh
   ```

3. **Optional: Add to your PATH:**
   For easier access, move the script to a directory in your PATH (e.g., `/usr/local/bin` or `~/bin`):
   ```bash
   sudo mv gpg-env.sh /usr/local/bin/
   # OR
   mkdir -p ~/bin && mv gpg-env.sh ~/bin/
   ```
   > **Note**: If you move it to `~/bin`, ensure `~/bin` is in your shell's PATH.

4. **Optional: Configure alias in .bashrc:**
   For convenience, you can add an alias to your shell configuration file to use `ge` instead of the full script name:
   ```bash
   echo 'alias ge="gpg-env.sh"' >> ~/.bashrc
   source ~/.bashrc
   ```
   If you didn't add the script to your PATH in step 3, use the full path to the script:
   ```bash
   echo 'alias ge="/path/to/gpg-env.sh"' >> ~/.bashrc
   source ~/.bashrc
   ```
   For other shells, add the alias to the appropriate configuration file:
   - **Zsh**: `~/.zshrc`
   - **Fish**: `~/.config/fish/config.fish` (using `alias ge="gpg-env.sh"`)
   - **Bash (macOS)**: `~/.bash_profile`

## Usage

Navigate to your project's root directory where you want to manage your environment variables.

## Commands

### `list`
Decrypts the environment file and lists only variable names. It skips empty lines and displays any preceding comments for a variable in cyan, next to the variable name.

```bash
./gpg-env.sh list
# OR with alias
ge list
# Prompts for passphrase, then shows variable names with comments
```

### `init`
Initializes a new encrypted environment file.

> **Important**: Before running `init`, create a plaintext file named `.env` (or `.env.<prefix>` if using `GPG_ENV_PREFIX`) with your key-value pairs.

```bash
# Example: Create a plaintext .env file
echo "MY_API_KEY=supersecret123" > .env
echo "DB_USER=admin" >> .env

# Then initialize the encrypted file
./gpg-env.sh init
# OR with alias
ge init
# Prompts for a passphrase to encrypt .env into .env.gpg
```

### `edit`
Decrypts the current environment file, opens it in your configured editor, and re-encrypts it upon saving.

```bash
./gpg-env.sh edit
# OR with alias
ge edit
# Prompts for passphrase, opens editor, re-encrypts on save
```

### `view`
Decrypts and prints the content of the current environment file to your terminal. When used without a specific variable, it displays all key-value pairs, skipping empty lines and integrating preceding comments in cyan, inline with their respective variables. If a variable is specified, it outputs only that variable's value.

```bash
# View all variables with their values and comments
./gpg-env.sh view
# OR with alias
ge view
# Prompts for passphrase, prints all content with comments

# View a specific variable's value only
./gpg-env.sh view MY_API_KEY
# OR with alias
ge view MY_API_KEY
# Prompts for passphrase, prints only the value of MY_API_KEY
```

### `import`
Decrypts the current environment file and outputs export commands. This is primarily used for direnv integration. You can import all variables or specify a single variable to import.

```bash
# Import all variables (less common, direnv is preferred)
eval "$(./gpg-env.sh import)"
# OR with alias
eval "$(ge import)"
# Prompts for passphrase, then all variables are loaded into current shell

# Import a specific variable only
eval "$(./gpg-env.sh import MY_API_KEY)"
# OR with alias
eval "$(ge import MY_API_KEY)"
# Prompts for passphrase, then only MY_API_KEY is loaded into current shell
```

### `status`
Shows the current GPG environment file in use, indicates if it exists, and lists all available encrypted environment files (`.env*.gpg`) in the current directory.

```bash
./gpg-env.sh status
# OR with alias
ge status
```

### `enable-direnv`
Configures your project's `.envrc` file to automatically load secrets via direnv.

```bash
./gpg-env.sh enable-direnv
# OR with alias
ge enable-direnv
# This will create/update .envrc with necessary lines
# Follow the instructions to run 'direnv allow'
```

### `update-pass`
Changes the passphrase for the current encrypted environment file.

```bash
./gpg-env.sh update-pass
# OR with alias
ge update-pass
# Prompts for current and new passphrases
```

## Configuration Environment Variables

You can customize gpg-env.sh's behavior by setting these environment variables before running commands:

| Variable | Description | Default |
|----------|-------------|---------|
| `GPG_ENV_FILE` | Specifies the path to the encrypted environment file | `.env.gpg` or `.env.<GPG_ENV_PREFIX>.gpg` |
| `GPG_ENV_INIT_FILE` | Specifies the path to the plaintext file used by init | `.env` or `.env.<GPG_ENV_PREFIX>` |
| `GPG_ENV_EDITOR` | Sets the editor to use for the edit command, overriding the system's EDITOR | *System default* |
| `GPG_ENV_PREFIX` | If set, the script will look for environment files with this prefix | *None* |

### Example: Using Environment Prefixes

```bash
# Example: Initialize a 'staging' environment
echo "STAGING_API_KEY=xyz" > .env.staging
GPG_ENV_PREFIX=staging ./gpg-env.sh init
# OR with alias
GPG_ENV_PREFIX=staging ge init
# This will create .env.staging.gpg
```

```bash
# Example: Using a custom editor
export GPG_ENV_EDITOR="code --wait"
./gpg-env.sh edit
# OR with alias
ge edit
```

## Integration with direnv (Recommended)

**direnv** is highly recommended for a seamless workflow. Once direnv is installed and hooked into your shell:

1. **Run `enable-direnv`:**
   ```bash
   ./gpg-env.sh enable-direnv
   # OR with alias
   ge enable-direnv
   ```
   This command will create/update your project's `.envrc` file, adding lines to set gpg-env.sh's configuration variables (like `GPG_ENV_PREFIX` if it was set when you ran `enable-direnv`) and the `eval "$($0 import)"` command.

2. **Allow direnv:**
   ```bash
   direnv allow
   ```
   > **Note**: The first time you enter a directory with a new or modified `.envrc`, direnv will block and prompt you to allow it. This is a security feature.

Now, whenever you `cd` into your project directory, direnv will automatically execute the import command from gpg-env.sh, prompt you for your passphrase, and load your environment variables. When you `cd` out, direnv will automatically unset them.

## Security Considerations

### **Passphrase Strength**
The security of your encrypted environment file relies entirely on the strength of the passphrase you choose. **Use a long, complex, and unique passphrase.**

### **.gitignore**
**Always add `.env*` to your project's `.gitignore` file.** This prevents accidentally committing your plaintext `.env` files, your encrypted `.env.gpg` files, or your `.envrc` file (which contains the eval command) to version control.

```gitignore
# .gitignore
.env*
```

### **Temporary Files**
gpg-env.sh uses secure temporary files (`mktemp`) and trap to ensure they are cleaned up after use.

### **import Command Security**
The import command outputs export statements to stdout. While eval captures this, be mindful in shared environments that the output could theoretically be intercepted if not handled carefully. This tool is primarily designed for local development and CI/CD environments where the shell context is controlled.

### **Portability**
`.gpg` files are based on the OpenPGP standard and are highly portable. You can move your `.env.gpg` file to another system with GPG installed and decrypt it using the same passphrase.

## Contributing

Feel free to open issues or submit pull requests on the GitHub repository if you have suggestions or improvements.

## License

This project is licensed under the **MIT License**.
