# zsh startup

setopt NO_NOMATCH
setopt AUTO_RESUME
setopt NOTIFY

setopt appendhistory

#bindkey -v # use vi keymap
bindkey -e # use emacs keymap

setopt auto_cd              # automatically cd to paths
setopt dvorak               # use spelling correction for dv keyboards
setopt hist_ignore_dups     # when I run a command several times, only store one

MAILCHECK=90000 # never
HISTFILE=${HOME}/.zhistory
HISTSIZE=1000
SAVEHIST=1000

autoload colors; colors

# Root is red, users are blue
if [[ 0 == $UID ]]; then
   export PS1="%B%{$fg[red]%}%n%{$reset_color%}%b@%B%{$fg[cyan]%}%m%b%{$reset_color%}:%~%B>%b "
else
   export PS1="%B%{$fg[blue]%}%n%{$reset_color%}%b@%B%{$fg[cyan]%}%m%b%{$reset_color%}:%~%B>%b "
fi

stty echoe

# Command completion for network commands
# hostcmds=(rlogin rcp) # zsh knows about telnet, ftp, etc
# compctl -v setenv

