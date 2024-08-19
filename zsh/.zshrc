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

nvimconf() {
    export CURR_LOC=$PWD
    cd ~/.config/nvim
    nvim .
    cd $CURR_LOC
    unset CURR_LOC
}

export HOMEBREW_NO_ENV_HINTS=TRUE
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

# Zoxide (better cd)
source <(zoxide init zsh)

alias cd="z"

# Fzf
# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
