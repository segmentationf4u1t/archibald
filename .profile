# ~/.profile - login environment shared by every shell and display manager.
# greetd sources it with /bin/sh before starting the session; ~/.zprofile and ~/.bash_profile
# source it too, so keep this POSIX sh.

# rust (~/.cargo/bin)
. "$HOME/.cargo/env"

# bun
export BUN_INSTALL="$HOME/.bun"

# user binaries (XDG: ~/.local/bin) first, then bun; guarded so nested login shells add nothing twice
case ":$PATH:" in *":$BUN_INSTALL/bin:"*) ;; *) PATH="$BUN_INSTALL/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH
