#
# ~/.zprofile - zsh login shell
#
# The login environment (PATH etc.) lives in ~/.profile, shared with bash and greetd.

emulate sh -c '. "$HOME/.profile"'
typeset -U path PATH   # drop duplicate PATH entries
