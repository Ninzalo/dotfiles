export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(
  git
  poetry
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

alias cls='clear'
alias ll='ls -al'
alias act='source ./venv/bin/activate'
alias dea='deactivate'
alias nvimconf='nvim ~/.config/nvim'

export HOMEBREW_NO_ENV_HINTS=TRUE
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

function upd() {
  current_dir=$(pwd)
  cd ~/dotfiles/nix-darwin/
  echo "[INFO] Nix update started"
  nix flake update
  echo "[INFO] Nix rebuild started"
  darwin-rebuild switch --flake .#mbp --impure
  echo "[INFO] Brew update started"
  brew update
  echo "[INFO] Brew upgrade started"
  brew upgrade
  echo "[INFO] Brew cleanup started"
  brew cleanup --prune=all
  echo "[INFO] Update finished"
  source ~/.zshrc
  cd $current_dir
}

# Zoxide (better cd)
source <(zoxide init zsh)

alias cd="z"

# Fzf
# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
