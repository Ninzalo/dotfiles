#!/bin/bash

echo "Backup old dotfiles ..."
mv ~/dotfiles ~/dotfiles-before-update
mkdir -p ~/dotfiles
echo "Old dotfiles backed up."

echo "Backup old .config ..."
mv ~/.config/ ~/.config-before-update
mkdir -p ~/.config
echo "Old .config backed up."

echo "Backup old .zshrc ..."
mv ~/.zshrc ~/.zshrc-before-update
echo "Old .zshrc backed up."

echo "Cloning repository ..."
git clone --recurse-submodules git@github.com:Ninzalo/dotfiles.git ~/dotfiles/
cd ~/dotfiles
echo "Repository cloned."

echo "Installing brew packages ..."
sh ./install_brew_packages.sh
echo "Brew packages installed."

echo "Creating symlinks ..."
sh ./apply_symlinks.sh
echo "Symlinks created."

echo "Done."
