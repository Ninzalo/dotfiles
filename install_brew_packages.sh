#!/bin/bash
set -eo pipefail

# Function to check formula installation
is_formula_installed() {
    brew list --formula | grep -qw "$1"
}

# Function to check cask installation
is_cask_installed() {
    brew list --cask | grep -qw "$1"
}

# Function to handle installations with error trapping
safe_install() {
    local type=$1
    shift
    for pkg in "$@"; do
        if [[ -z "$pkg" ]]; then continue; fi
        echo "Installing $type: $pkg..."
        if [[ "$type" == "cask" ]]; then
            brew install --cask "$pkg" || echo "Error installing cask: $pkg"
        else
            brew install "$pkg" || echo "Error installing formula: $pkg"
        fi
    done
}

# Handle Homebrew installation
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Homebrew is ready. Checking packages..."

# Tap repositories
TAPS=(
  "arl/arl"
)

# Package lists
FORMULAE=(
  neovim
  tmux
  fzf
  zoxide
  jesseduffield/lazygit/lazygit
  lazygit
  make
  jq
  gnu-sed
  yarn
  git
  ripgrep
  grep
  stow
  wget
  powerlevel10k
  eza
  sshpass
  poetry
  gitmux
  node
  npm
  nmap
  pre-commit
  python
  go
  zsh-autosuggestions
  zsh-syntax-highlighting
  jordanbaird-ice
  curl
)

CASKS=(
  alacritty
  ghostty
  rectangle
  hyperkey
  db-browser-for-sqlite
  docker
  orbstack
  blender
)

# Tap repositories
for tap in "${TAPS[@]}"; do
    if ! brew tap | grep -q "^${tap}\$"; then
        echo "Tapping $tap..."
        brew tap "$tap" || echo "Error tapping $tap"
    fi
done

# Prepare install lists
declare -a to_upgrade_formulae to_install_formulae
declare -a to_upgrade_casks to_install_casks

# Check formulae
for formula in "${FORMULAE[@]}"; do
    if is_formula_installed "$formula"; then
        to_upgrade_formulae+=("$formula")
    else
        to_install_formulae+=("$formula")
    fi
done

# Check casks
for cask in "${CASKS[@]}"; do
    if is_cask_installed "$cask"; then
        to_upgrade_casks+=("$cask")
    else
        to_install_casks+=("$cask")
    fi
done

# Perform upgrades and installations
if [[ ${#to_upgrade_formulae[@]} -gt 0 ]]; then
    echo "Upgrading formulae: ${to_upgrade_formulae[*]}"
    brew upgrade "${to_upgrade_formulae[@]}" || echo "Formula upgrade failed"
fi

if [[ ${#to_install_formulae[@]} -gt 0 ]]; then
    safe_install "formula" "${to_install_formulae[@]}"
fi

if [[ ${#to_upgrade_casks[@]} -gt 0 ]]; then
    echo "Upgrading casks: ${to_upgrade_casks[*]}"
    brew upgrade --cask "${to_upgrade_casks[@]}" || echo "Cask upgrade failed"
fi

if [[ ${#to_install_casks[@]} -gt 0 ]]; then
    safe_install "cask" "${to_install_casks[@]}"
fi

echo "All operations completed successfully."
