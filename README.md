# Description
My dotfiles repository.

# Installation
## Install Nix
```sh
sh <(curl -L https://nixos.org/nix/install)
nix-shell -p neofetch --run neofetch
```

### Check if Nix is installed
```sh
which nix
```

## Backup old dotfiles-related files
```sh
mv -rf ~/dotfiles ~/dotfiles-before-nix-dotfiles
mkdir -p ~/dotfiles
mv -rf ~/.config/ ~/.config-before-nix-dotfiles
mkdir -p ~/.config
mv ~/.zshrc ~/.zshrc-before-nix-dotfiles
```

## Clone repository
```sh
git clone git@github.com:Ninzalo/dotfiles.git <your_dotfiles_directory>
cd <your_dotfiles_directory>/nix-darwin
```
<details>
<summary>Example</summary>
<p></p>

```sh
git clone git@github.com:Ninzalo/dotfiles.git ~/dotfiles/
cd ~/dotfiles/nix-darwin
```
</details>

## Initialize new flake
```sh
nix flake init -t nix-darwin --extra-experimental-features "nix-command flakes"
```

## Set configuration name
```sh
sed -i "s/mbp/<configuration_name>/" flake.nix
```
<details>
<summary>Example</summary>
<p></p>

```sh
sed -i "s/mbp/$(scutil --get LocalHostName)/" flake.nix
# Or
sed -i "s/mbp/mbp/" ./flake.nix
```
</details>

## Install nix-darwin
```sh
nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake .#<configuration_name>
```
<details>
<summary>Example</summary>
<p></p>

```sh
nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake .#mbp
```
</details>

### Check if nix-darwin is installed
```sh
which darwin-rebuild
```

## Switch to new configuration
```sh
darwin-rebuild switch --flake --impure .#<configuration_name>
```
<details>
<summary>Example</summary>
<p></p>

```sh
darwin-rebuild switch --flake --impure .#mbp
```
</details>

# Fast install
```sh
sh fast_install.sh '<configuration_name>'
```
<details>
<summary>Example</summary>
<p></p>

```sh
sh fast_install.sh 'mbp'
```
</details>

## Neovim
- Install my [Neovim configuration](https://github.com/Ninzalo/nvimconf)

## Yabai
- Install my [Yabai configuration](https://github.com/Ninzalo/yabaiconf)

## Skhd
- Install my [Skhd configuration](https://github.com/Ninzalo/skhdconf)
