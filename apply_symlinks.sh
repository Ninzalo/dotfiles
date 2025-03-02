#!/bin/sh

DOTFILES_DIR=$(pwd)

CONFIG_PKGS="
alacritty
ghostty
nvim
tmux
gitmux
"

ROOT_PKGS="
p10k
zsh
"

mkdir -p "$HOME/.config"

for pkg in $CONFIG_PKGS; do
	echo "Linking $pkg into ~/.config..."
	ln -sf "$DOTFILES_DIR/$pkg" "$HOME/.config/$pkg"
done

for pkg in $ROOT_PKGS; do
    echo "Processing $pkg files:"

    find "$DOTFILES_DIR/$pkg" -mindepth 1 -maxdepth 1 ! -name ".git" ! -name ".gitignore" | while read -r file; do
        filename=$(basename "$file")
        target="$HOME/$filename"

        echo "Linking $filename to home directory..."
        ln -sf "$file" "$target"
    done
done
