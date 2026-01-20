#!/bin/bash

set -u
#set -x

function usage() {
    echo 'Usage: pskill.sh [-q] [-v] [-h] [-sig] <expression-reguliere>'
    echo ''
    echo 'Permet d'\''envoyer un signal via la commande kill aux processus dont la ligne de commande verifie <expression-reguliere>'
    echo '-q : query, demande confirmation pour chaque processus'
    echo '-v : verbeux, affiche ce qui est fait'
    echo '-h : affichage de ce message d'\''aide'
    echo '-sig : ou sig est un signal, utilisation de ce signal au lieu du signal par defaut (SIGTERM). sig peut etre numerique ou symbolique selon ce qu'\''accepte la commande kill'
    echo ''
    echo 'Exemple :'
    echo 'pskill.sh -HUP -q '\''s.*p'\'''
    echo 'enverra le signal SIGHUP aux processus pour lesquels la commande utilisee verifie l'\''expression reguliere (exemple : sleep) avec demande de confirmation.'
}

function info() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "[*] info: $1"
    fi
}

function error() {
    echo -e "[!] error: $1"
}

# Prompt the user for a question and returns a value according to the answer
# Arg 1: Message to display before the prompt
# Arg 2: Default answer (returned if nothing is entered by the user)
# Return 0 if 'Yes' is selected, 1 otherwise
function confirm() {
    while true; do
        read -rp "$1 " answer </dev/tty
        case $answer in
        [Yy]*)
            return 0
            ;;
        [Nn]*) return 1 ;;
        "") return "$2" ;; # return default answer
        *)
            echo "($answer) Please input a valid answer."
            ;;
        esac
    done
}

# parse script arguments
QUERY=0
VERBOSE=0
SIG="TERM"
REGEX=""
while [ $# -gt 0 ]; do
    case "$1" in
    -q)
        QUERY=1
        shift
        ;;
    -v)
        VERBOSE=1
        shift
        ;;
    -h)
        usage
        exit 0
        ;;
    -*)
        SIG="${1:1}"
        shift
        ;;
    *)
        REGEX=$1
        shift
        ;;
    esac
done

if [ -z "$REGEX" ]; then
    error "a regex argument is required"
    exit 1
fi

info "listing processes"
processes="$(ps -ewwo pid,comm | sed 's/^ *//;s/ *$//' | awk -v regex="$REGEX" -F" " '$2 ~ regex { print $0 }')" # " | cut -d " " -f 1 | tr '\n' ' ')"
# processes="$(ps -ewwo pid,command | sed 's/^ *//;s/ *$//' | cut -d " " -f 2 | grep "$REGEX" | head -n -3)"
if [ -z "$processes" ]; then
    info "no process found"
    exit 0
fi
info "processes listed"
while IFS='' read -r p; do
    pid="$(echo "$p" | cut -d " " -f 1)"
    name="$(echo "$p" | cut -d " " -f 2)"
    if [ $QUERY -eq 1 ]; then
        if ! (confirm "  [?] kill process #$pid ($name)? [y/N]" 1); then
            echo "  [*] skipping process #$pid ($name)"
            continue
        fi
    fi
    info "killing process #$pid ($name)"
    kill -s "SIG$SIG" "$pid" || error "Unable to delete process #$pid ($name)"
done <<<"$processes"
info "Done."
