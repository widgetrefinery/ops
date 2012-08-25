#
# /etc/bash.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

HISTFILE=
HISTFILESIZE=0

export LESSHISTFILE=-

if [ 'xterm' != "$TERM" ]; then
	TMOUT="$((60*10))"
else
	cat /etc/motd
fi

PS1='<RESET>[<CYAN>\t<RESET>]<$((UID?GREEN:RED))>\u<RESET>@<GREEN>\h<RESET>:<CYAN>\w<0>\$ '
PS1=${PS1//RESET/0;\$((\$??7:0))}
PS1=${PS1//RED/31}
PS1=${PS1//GREEN/32}
PS1=${PS1//CYAN/36}
PS1=${PS1//</\\[\\e[}
PS1=${PS1//>/m\\]}
PS2='> '
PS3='> '
PS4='+ '

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion
