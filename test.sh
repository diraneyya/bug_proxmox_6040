#!/usr/bin/env bash

DOCKER_CONTAINER_NAME=$1

function test_tar_extraction {
    # UNIFIED_EXCLUSION='--exclude='{,./}'sample123/*'
    set +o noglob
    cd /app
    rm -rf ./extracted?/*
    set -o noglob
    TMP=$(mktemp)
    exec 4> $TMP
    SUCCESS_COMMAND_TEMPLATE="\e[32;4msuceeded:\e[24m %s\e[0m\n"
    FAILING_COMMAND_TEMPLATE="\e[31;4;2mfailed:\e[24m %s\e[0m\n"
    COMMAND="tar xf file?.tar -C extracted? --anchored $*"
    FAILED=
    if ! tar xf file1.tar -C extracted1 --anchored $* 1>/dev/null 2>&4; then FAILED=1; fi
    if [ -z "$FAILED" ]; then 
        printf "$SUCCESS_COMMAND_TEMPLATE" "$COMMAND"
    else 
        printf >&2 "$FAILING_COMMAND_TEMPLATE" "$COMMAND"
        printf >&2 "\e[31m%s\e[0m\n" "$(cat $TMP)"
    fi
    exec 4>&-
    rm $TMP
    tar xf file2.tar -C extracted2 --anchored $* &>/dev/null
}

if ! command -v docker &>/dev/null; then 
    printf >&2 "Docker needs to be installed.\n"
    printf >&2 "\e[2m(%s)\e[0m\n" "we use Docker to mimic the Proxmox environment"
    exit 1
fi

docker pull debian:12 &>/dev/null

if [[ $? -ne 0 ]]; then
    printf >&2 "Pulling the 'debian:12' Docker image failed.\n"
    printf >&2 "\e[2m(%s)\e[0m\n" "is Docker Desktop/daemon running? are you connected to the internet?"
    exit 2
fi

RCFILE=$(mktemp)
HISTFILE=$(mktemp)

echo 'exit' >> $HISTFILE
echo 'test_tar_extraction --exclude' >> $HISTFILE
cat <<EOF > $RCFILE
# Transfer execution context to container
$(declare -f test_tar_extraction)
# Exit the container if the files were not correctly mounted
if [[ ! -f /app/file1.tar || ! -f /app/file2.tar  ]]; then exit 1; fi
if ! cat <<LOF | diff - <(ls /app) &>/dev/null
$(ls)
LOF
then exit 99; fi
set -o noglob
clear
printf "\e[34;1m%s\e[0m\n" \
    "Press the UP arrow to access the history for testing 'tar' exclusion patterns"
printf "\e[34;4m%s\e[0m\n" \
    "(to exit use Ctrl + B followed by the letter D)"
EOF

if docker container inspect "$DOCKER_CONTAINER_NAME" &>/dev/null; then
    docker kill "$DOCKER_CONTAINER_NAME" &>/dev/null
fi

docker run --rm -id \
    --name "$DOCKER_CONTAINER_NAME" \
    -v .:/app \
    -v $RCFILE:/root/.bash_profile \
    -v $HISTFILE:/root/.bash_history \
    debian:12 bash --norc

docker exec $DOCKER_CONTAINER_NAME bash \
    -c "rm -rf /app/content/*; tar xf /app/file1.tar -C /app/content"

ERR_CODE=$?

if [[ $ERR_CODE -ne 0 ]]; then
    if [[ -n "$DOCKER_CONTEXT" || -n "$DOCKER_HOST" ]]; then
        printf >&2 "Remote Docker context/endpoint detected.\n"
        printf >&2 "\e[2m(%s)\e[0m\n" "unset DOCKER_CONTEXT, DOCKER_HOST, or both"
        rm $RCFILE $HISTFILE
        exit 3
    elif [[ $ERR_CODE -eq 99 ]]; then
        printf >&2 "Unable to find the demo inside of the Docker container.\n"
        printf >&2 "\e[2m(%s)\e[0m\n" "are you using Docker remotely? if not, try restarting the local daemon"
        exit 4
    fi
fi