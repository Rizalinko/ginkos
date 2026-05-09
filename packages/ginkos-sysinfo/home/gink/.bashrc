# GinkOS default .bashrc

# Run sysinfo on interactive login
if [[ $- == *i* ]]; then
    gink-info
fi

# Aliases
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias audit='gink-audit'
alias freeze='sudo gink-freeze'

# Prompt — ginkgo gold
PS1='\[\e[38;2;200;169;81m\]\u@\h\[\e[0m\]:\[\e[38;2;100;100;100m\]\w\[\e[0m\]\$ '
