# Description
My dotfiles repository.

# Installation
## Backup old dotfiles-related files
<details>
<summary>Example</summary>
<p></p>

```sh
mv -rf ~/dotfiles ~/dotfiles-before-update
mkdir -p ~/dotfiles
mv -rf ~/.config/ ~/.config-before-update
mkdir -p ~/.config
mv ~/.zshrc ~/.zshrc-before-update
```
</details>

## Clone repository
```sh
git clone --recurse-submodules git@github.com:Ninzalo/dotfiles.git <your_dotfiles_directory>
```
<details>
<summary>Example</summary>
<p></p>

```sh
git clone --recurse-submodules git@github.com:Ninzalo/dotfiles.git ~/dotfiles/
```
</details>

# Fast install
```sh
sh <(curl -L https://raw.githubusercontent.com/Ninzalo/dotfiles/refs/heads/master/fast_install.sh)
```

# Other guides
## Neovim
- Install my [Neovim configuration](https://github.com/Ninzalo/nvimconf)

## Yabai
- Install my [Yabai configuration](https://github.com/Ninzalo/yabaiconf)

## Skhd
- Install my [Skhd configuration](https://github.com/Ninzalo/skhdconf)
