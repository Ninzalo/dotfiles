# Description
My dotfiles repository.

# Installation
## Install Nix
```sh
sh <(curl -L https://nixos.org/nix/install)
```

### Check if Nix is installed
```sh
which nix
```

## Backup old dotfiles-related files
<details>
<summary>Example</summary>
<p></p>

```sh
mv -rf ~/dotfiles ~/dotfiles-before-nix-dotfiles
mkdir -p ~/dotfiles
mv -rf ~/.config/ ~/.config-before-nix-dotfiles
mkdir -p ~/.config
mv ~/.zshrc ~/.zshrc-before-nix-dotfiles
```
</details>

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

## Set username
```sh
sed -i "s/ninzalogg/<your_username>/" flake.nix
sed -i "s/ninzalogg/<your_username>/" home.nix
```
<details>
<summary>Example</summary>
<p></p>

```sh
sed -i "s/ninzalogg/$(id -un)/" flake.nix
sed -i "s/ninzalogg/$(id -un)/" home.nix
```
</details>

## Set configuration name
```sh
sed -i "s/mbp/<configuration_name>/" flake.nix
```
Note: Do not forget to change <code><configuration_name></code> to your preferred configuration name
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
Note: Do not forget to change <code><configuration_name></code> to your preferred configuration name
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
Note: Do not forget to change <code><configuration_name></code> to your preferred configuration name
<details>
<summary>Example</summary>
<p></p>

```sh
darwin-rebuild switch --flake --impure .#mbp
```
</details>

# Fast install
```sh
sh <(curl -L https://raw.githubusercontent.com/Ninzalo/dotfiles/refs/heads/master/fast_install.sh) '<configuration_name>'
```
Note: Do not forget to change <code><configuration_name></code> to your preferred configuration name
<details>
<summary>Example</summary>
<p></p>

```sh
sh <(curl -L https://raw.githubusercontent.com/Ninzalo/dotfiles/refs/heads/master/fast_install.sh) 'mbp'
```
</details>

# Other guides
## Neovim
- Install my [Neovim configuration](https://github.com/Ninzalo/nvimconf)

## Yabai
- Install my [Yabai configuration](https://github.com/Ninzalo/yabaiconf)

## Skhd
- Install my [Skhd configuration](https://github.com/Ninzalo/skhdconf)
