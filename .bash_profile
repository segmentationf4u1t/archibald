#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# user binaries (XDG: ~/.local/bin)
export PATH="$HOME/.local/bin:$PATH"
