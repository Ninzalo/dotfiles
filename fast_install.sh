#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "Error: Invalid number of arguments. Expected 1, got $#."
  exit 1
fi

CONFIG_NAME=$1
USERNAME=$(id -un)

echo "Install Nix ..."
sh <(curl -L https://nixos.org/nix/install)
nix-shell -p neofetch --run neofetch
which nix
echo "Nix installed."

echo "Backup old dotfiles ..."
mv -rf ~/dotfiles ~/dotfiles-before-nix-dotfiles
mkdir -p ~/dotfiles
echo "Old dotfiles backed up."

echo "Backup old .config ..."
mv -rf ~/.config/ ~/.config-before-nix-dotfiles
mkdir -p ~/.config
echo "Old .config backed up."

echo "Backup old .zshrc ..."
mv ~/.zshrc ~/.zshrc-before-nix-dotfiles
echo "Old .zshrc backed up."

echo "Cloning repository ..."
git clone git@github.com:Ninzalo/dotfiles.git ~/dotfiles/
echo "Repository cloned."

cd ~/dotfiles/nix-darwin

echo "Initializing new flake ..."
nix flake init -t nix-darwin --extra-experimental-features "nix-command flakes"
echo "Flake initialized."

echo "Setting username to $USERNAME ..."
sed -i "s/ninzalogg/$USERNAME/" flake.nix
sed -i "s/ninzalogg/$USERNAME/" home.nix
echo "Username set to $USERNAME."

echo "Setting config name to $CONFIG_NAME ..."
sed -i "s/mbp/$CONFIG_NAME/" flake.nix
echo "Config name set to $CONFIG_NAME."

echo "Installing nix-darwin ..."
nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake .#$CONFIG_NAME
which darwin-rebuild
echo "Nix-darwin installed."

echo "Switching to new configuration ..."
darwin-rebuild switch --flake --impure .#$CONFIG_NAME
echo "Configuration switched."

echo "Done."
