#!/bin/bash

set -u

function usage() {
    echo "            _    _ _ _ _ "
    echo "           | |  (_) | | |"
    echo "  _ __  ___| | ___| | | |"
    echo " | '_ \/ __| |/ / | | | |"
    echo " | |_) \__ \   <| | | | |"
    echo " | .__/|___/_|\_\_|_|_|_|"
    echo " | |"
    echo " |_|"
    echo ''
    echo 'Usage: pskill.sh [-q] [-v] [-h] [-sig] <expression-rationnelle>'
    echo ''
    echo "Permet d'envoyer un signal via la commande kill aux processus dont la ligne de commande vérifie <expression-rationnelle>"
    echo '-q : query, demande confirmation pour chaque processus'
    echo '-v : verbeux, affiche ce qui est fait'
    echo "-h : affichage de ce message d'aide"
    echo '-sig : ou sig est un signal, utilisation de ce signal au lieu du signal par défaut (SIGTERM). sig peut être numérique ou symbolique selon ce qu'\''accepte la commande kill'
    echo ''
    echo 'Exemple :'
    echo 'pskill.sh -HUP -q '\''s.*p'\'''
    echo 'enverra le signal SIGHUP aux processus pour lesquels la commande utilisée vérifie l'\''expression rationnelle (exemple : sleep) avec demande de confirmation.'
    echo ''
}

# Log a message if verbose mode is enabled
# Arg 1: Message to display
function info() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "[*] info: $1"
    fi
}

# Log an error message to standard error
# Arg 1: Error message to display
function error() {
    echo -e "[!] erreur: $1" >&2
}

# Prompt the user for a question and returns a value according to the answer
# Arg 1: Message to display before the prompt
# Arg 2: Default answer (returned if nothing is entered by the user)
# Return 0 if 'Yes' is selected, 1 otherwise
function confirm() {
    while true; do
        read -rp "$1 " answer </dev/tty
        case $answer in
        [Oo]*)
            return 0
            ;;
        [Nn]*) return 1 ;;
        "") return "$2" ;; # return default answer
        *)
            echo "($answer) Veuillez sélectionner une option correcte."
            ;;
        esac
    done
}

# exit code
EXIT=0

# parse script arguments
QUERY=0
VERBOSE=0
SIG="SIGTERM"
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
    # if symbolic signal, add SIG before it
    -*[!0-9]*)
        SIG="SIG${1:1}"
        shift
        ;;
    # if numeric signal, keep it as is
    -[0-9]*)
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
    error "une expression rationnelle est requise"
    usage
    exit 1
fi

info "récupération des processus..."

# use ps with "pid" and "comm" field to get (pid, command name) pairs
# then use sed to remove the prepending spaces added by ps
# then filter the result with awk based on the regex
processes="$(ps -ewwo pid,comm | sed 's/^ *//;s/ *$//' | awk -v regex="$REGEX" -F" " '$2 ~ regex { print $0 }')"

# exit if no process found
if [ -z "$processes" ]; then
    info "aucun processus trouvé."
    exit 0
fi

info "processus récupérés."

# iterate through process list to kill them
while IFS='' read -r p; do
    # extract pid and name from pair
    pid="$(echo "$p" | cut -d " " -f 1)"
    name="$(echo "$p" | cut -d " " -f 2)"

    # ask for confirmation if the query switch is enabled
    if [ $QUERY -eq 1 ]; then
        if ! (confirm "  [?] envoyer le signal $SIG au processus #$pid ($name)? [o/N]" 1); then
            echo "  [*] processus #$pid ($name) ignoré"
            continue
        fi
    fi
    info "envoi du signal $SIG au processus #$pid ($name)"

    # send kill with specified signal
    kill -s "$SIG" "$pid" || {
        error "Impossible d'envoyer le signal au processus #$pid ($name)"
        EXIT=1
    }
done <<<"$processes"

info "Terminé"
exit "$EXIT"
