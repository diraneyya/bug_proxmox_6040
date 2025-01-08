#!/usr/bin/env bash

SESSION="proxmox-bug-6040"

if [[ $1 == clean* ]]; then
    printf "\e[33m- Killing Docker container...\e[0m\n"
    docker kill $SESSION &>/dev/null
    docker rm $SESSION &>/dev/null
    printf "\e[33m- Killing Tmux session...\e[0m\n"
    tmux kill-session -t $SESSION &>/dev/null
    printf "\e[32;1mDone\e[0m\n"
    exit 0
fi

# relay the stderr messages of 'test.sh'
if ! ./test.sh "$SESSION"; then exit 1; fi

# relay the stderr messages of 'tree.sh'
if ! ./tree.sh content >/dev/null; then exit 1; fi

# check if 'tmux' is installed
source './utils.sh'
if ! command_check 'tmux' 'https://github.com/tmux/tmux'; then exit $?; fi

WATCH_COMMAND='watch -n 0.2 -c -t '

tmux list-sessions | grep -q $SESSION
if [[ $? -eq  0 ]]; then
    tmux kill-session -t $SESSION
fi

tmux new-session -d -s $SESSION

tmux rename-window -t 0 'tar-extraction-demo'
tmux split-window -v
tmux split-window -v
tmux split-window -v
tmux select-layout main-horizontal

tmux select-pane -t 1 -T 'watch-contents'
tmux select-pane -t 1
tmux send-keys "$WATCH_COMMAND ./tree.sh content" Enter

tmux select-pane -t 2 -T 'watch-extracted-dot-slash'
tmux select-pane -t 2
tmux send-keys "$WATCH_COMMAND ./tree.sh extracted1" Enter

tmux select-pane -t 3 -T 'watch-extracted-no-dot-slash'
tmux select-pane -t 3
tmux send-keys "$WATCH_COMMAND ./tree.sh extracted2" Enter

tmux select-pane -t 0 -T 'test-command'
tmux select-pane -t 0
tmux resize-pane -U 100
tmux resize-pane -D 8
tmux send-keys "docker exec -it $SESSION bash --login" Enter

tmux attach-session -t $SESSION