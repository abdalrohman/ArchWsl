#!/usr/bin/env bash

#-------------------------------------------------------------------------
#                          ████                               █████     
#                         ░░███                              ░░███      
#  █████ ███ █████  █████  ░███   ██████   ████████   ██████  ░███████  
# ░░███ ░███░░███  ███░░   ░███  ░░░░░███ ░░███░░███ ███░░███ ░███░░███ 
#  ░███ ░███ ░███ ░░█████  ░███   ███████  ░███ ░░░ ░███ ░░░  ░███ ░███ 
#  ░░███████████   ░░░░███ ░███  ███░░███  ░███     ░███  ███ ░███ ░███ 
#   ░░████░████    ██████  █████░░████████ █████    ░░██████  ████ █████
#    ░░░░ ░░░░    ░░░░░░  ░░░░░  ░░░░░░░░ ░░░░░      ░░░░░░  ░░░░ ░░░░░ 
#                       BUILD ARCH LINUX FOR WSL
#Description	:Build arch linux distro for wsl
#Author       	:Abdalrohman alnassier
#Email         	:abdd199719@gmail.com 
#-------------------------------------------------------------------------

# shellcheck disable=SC2059
# shellcheck disable=SC2154

export LC_MESSAGES=C
export LANG=C

disable_colors(){
    unset ALL_OFF BOLD BLUE GREEN RED YELLOW
}

enable_colors(){
    # prefer terminal safe colored and bold text when tput is supported
    if tput setaf 0 &>/dev/null; then
        ALL_OFF="$(tput sgr0)"
        BOLD="$(tput bold)"
        RED="${BOLD}$(tput setaf 1)"
        GREEN="${BOLD}$(tput setaf 2)"
        YELLOW="${BOLD}$(tput setaf 3)"
        BLUE="${BOLD}$(tput setaf 4)"
        PASSED="${BOLD}$(tput setaf 7)$(tput setab 2)"
    else
        ALL_OFF="\e[0m"
        BOLD="\e[1m"
        RED="${BOLD}\e[31m"
        GREEN="${BOLD}\e[32m"
        YELLOW="${BOLD}\e[33m"
        BLUE="${BOLD}\e[34m"
        PASSED="\e[30;48;5;82m"
    fi
    readonly ALL_OFF BOLD BLUE GREEN RED YELLOW
}

if [[ -t 2 ]]; then
    enable_colors
else
    disable_colors
fi

msg() {
    local mesg=$1; shift
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

passed() {
    local mesg=$1; shift
    printf " ${PASSED} ${mesg} ${ALL_OFF}\n" "$@" >&2
}

msg2() {
    local mesg=$1; shift
    printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

info() {
    local mesg=$1; shift
    printf "${YELLOW} -->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

warning() {
    local mesg=$1; shift
    printf "${YELLOW}==> WARNING:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
    local mesg=$1; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

cleanup() {
    exit "${1:-0}"
}

die() {
    (( $# )) && error "$@"
    cleanup 255
}

check_root() {
    (( EUID == 0 )) && return
    if type -P sudo >/dev/null; then
        exec sudo -- "$@"
    else
        exec su root -c "$(printf ' %q' "$@")"
    fi
}

run_safe() {
    local restoretrap func="$1"
    set -e
    set -E
    restoretrap=$(trap -p ERR)
    trap 'error_function $func' ERR
	
    eval "$restoretrap"
    set +E
    set +e
}

lock() {
    eval "exec $1>"'"$2"'
    if ! flock -n "$1"; then
        stat_busy "$3"
        flock "$1"
        stat_done
    fi
}

copy_overlay(){
    if [[ -e $1 ]]; then
        msg2 "Copying [%s] ..." "${1##*/}"
        if [[ -L $1 ]]; then
            cp -a --no-preserve=ownership "$1"/* "$2"
        else
            cp -LR "$1"/* "$2"
        fi
    fi
}

user_own(){
    local flag=$2
    chown "${flag}" "${OWNER}:$(id --group "${OWNER}")" "$1"
}

make_sig () {
    msg2 "Creating signature file..."
    cd "$1"
    user_own "$1"
    su "${OWNER}" -c "gpg --detach-sign --default-key ${gpgkey} $2"
    chown -R root "$1"
    cd "${OLDPWD}"
}

# $1: file
make_checksum(){
    msg2 "Creating md5sum ..."
    cd "$1"
    md5sum "$2" > "$2".md5
	msg2 "Creating sha512sum ..."
    sha512sum "$2" > "$2".sha512
    cd "${OLDPWD}"
}

# creat dir if not exist
prepare_dir(){
    msg "Prepare folder $1"
    if [[ ! -d $1 ]]; then
        mkdir -p "$1"
        msg2 "Done with prepare $1"
    fi
}
