#
# ~/.zshrc - interactive zsh
#

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt extended_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks share_history

setopt interactive_comments

# Same prompt as the old bash PS1: [user@host dir]$
PROMPT='[%n@%m %1~]%(!.#.$) '

# ---- Keys ----
bindkey -e   # emacs keys like bash (zsh picks vi mode when $EDITOR contains "vi")

# Home/End/Delete/... from terminfo (plain zsh does not bind them; bash got them from readline)
typeset -g -A key
key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Delete]="${terminfo[kdch1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Control-Left]="${terminfo[kLFT5]}"
key[Control-Right]="${terminfo[kRIT5]}"
[[ -n "${key[Home]}"          ]] && bindkey -- "${key[Home]}"          beginning-of-line
[[ -n "${key[End]}"           ]] && bindkey -- "${key[End]}"           end-of-line
[[ -n "${key[Insert]}"        ]] && bindkey -- "${key[Insert]}"        overwrite-mode
[[ -n "${key[Delete]}"        ]] && bindkey -- "${key[Delete]}"        delete-char
[[ -n "${key[PageUp]}"        ]] && bindkey -- "${key[PageUp]}"        beginning-of-buffer-or-history
[[ -n "${key[PageDown]}"      ]] && bindkey -- "${key[PageDown]}"      end-of-buffer-or-history
[[ -n "${key[Control-Left]}"  ]] && bindkey -- "${key[Control-Left]}"  backward-word
[[ -n "${key[Control-Right]}" ]] && bindkey -- "${key[Control-Right]}" forward-word
# The terminfo key codes above are application-mode codes: switch the terminal into it while editing
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
    autoload -Uz add-zle-hook-widget
    function zle_application_mode_start { echoti smkx }
    function zle_application_mode_stop { echoti rmkx }
    add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
    add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi

# ---- ls -> eza, cat -> bat ----
alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -l --group-directories-first --icons=auto --git'
alias la='eza -la --group-directories-first --icons=auto --git'
alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
alias cat='bat --paging=never --style=plain'   # plain cat output when piped; `bat file` for the full view
alias grep='grep --color=auto'

# ---- Completion ----
eval "$(dircolors -b)"   # LS_COLORS, used to color completion candidates
autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no                      # fzf-tab replaces the completion menu
zstyle ':completion:*:descriptions' format '[%d]'   # group headers (fzf-tab: switch groups with < >)
zstyle ':completion:*:git-checkout:*' sort false

# ---- fzf, file lists from fd ----
# Preview: directories as an eza tree, files through fzf's bundled previewer
# (bat for text, kitty graphics for images, `file` for other binaries).
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
# Colors: dark-volcanic (bg -1 keeps kitty's translucent background)
export FZF_DEFAULT_OPTS='--height=50% --layout=reverse --border
  --color=fg:#ebdfd8,bg:-1,hl:#FF7A3D,fg+:#ebdfd8,bg+:#261513,hl+:#F3C24F,gutter:-1
  --color=query:#ebdfd8,prompt:#FF7A3D,pointer:#FF7A3D,marker:#4FC48A,spinner:#F3C24F
  --color=info:#8F7D74,header:#8F7D74,border:#3A201C,separator:#3A201C,scrollbar:#3A201C,label:#F3C24F'
export FZF_CTRL_T_COMMAND='fd --hidden --follow --exclude .git'
export FZF_CTRL_T_OPTS="--preview '[[ -d {} ]] && eza --tree --level=2 --no-quotes --color=always --icons=always {} || /usr/share/fzf/fzf-preview.sh {}'"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --no-quotes --color=always --icons=always {}'"
# Ctrl-T insert path, Ctrl-R history, Alt-C cd. Tab stays with fzf-tab (no fzf completion.zsh).
source /usr/share/fzf/key-bindings.zsh

# ---- fzf-tab: Tab completion through fzf (after compinit, before widget-wrapping plugins) ----
# Installed from git (not in the dotfiles): git clone --depth 1 https://github.com/Aloxaf/fzf-tab ~/.local/share/zsh/plugins/fzf-tab
# update: git -C ~/.local/share/zsh/plugins/fzf-tab pull
source ~/.local/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:*:*' fzf-preview \
    '[[ -d $realpath ]] && eza -1 --no-quotes --color=always --icons=always $realpath || { [[ -f $realpath ]] && /usr/share/fzf/fzf-preview.sh $realpath }'

# ---- zoxide as cd: `cd foo` jumps by frecency, `cd foo<Space><Tab>` / `cdi` pick with fzf ----
eval "$(zoxide init zsh --cmd cd)"

# ---- Suggestions and highlighting (syntax-highlighting must stay last) ----
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_STYLES[comment]='fg=8'   # default fg=black,bold is near-invisible on the volcanic background
