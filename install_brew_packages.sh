#!/bin/sh
set -e

# Check if Homebrew is installed.
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Homebrew is installed. Proceeding with taps and package installation..."

# --- 1. Tap required repositories ---
TAPS="
arl/arl
"

for tap in $TAPS; do
  echo "Tapping $tap..."
  brew tap "$tap"
done

# --- 2. Install formula packages ---
# These packages come from environment.systemPackages and homebrew.brews.
# Note: Package names are assumed to match the names given in your Nix configuration.
FORMULAE="
neovim
tmux
fzf
zoxide
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
"

for formula in $FORMULAE; do
  echo "Installing formula: $formula..."
  brew install "$formula" || echo "Warning: Installation of $formula failed."
done

# --- 3. Install cask packages ---
CASKS="
alacritty
ghostty
rectangle
hyperkey
db-browser-for-sqlite
docker
orbstack
"

for cask in $CASKS; do
  echo "Installing cask: $cask..."
  brew install --cask "$cask" || echo "Warning: Installation of $cask failed."
done

echo "Brew packages installation completed."
