#!/usr/bin/env bash
# ➜ ➜ ➜ === UTILITIES === #
SET_PATHS() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
        ABSOLUTE_PATH="$(cd -P "$(dirname "$SOURCE")" && pwd)"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$ABSOLUTE_PATH/$SOURCE"
    done
    ABSOLUTE_PATH="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    # shellcheck disable=SC2034
    SELF_PATH="$(dirname "$(readlink -f "$0")")"
}
TITLE() {
    printf "\033[1;42m"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' ' '
    printf '%-*s\n' "${COLUMNS:-$(tput cols)}" "  # $1" | tr ' ' ' '
    printf '%*s' "${COLUMNS:-$(tput cols)}" '' | tr ' ' ' '
    printf "\e[0m"
    printf "\n"
}
NOTIFY() {
    printf "\033[1;46m"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' ' '
    printf '%-*s\n' "${COLUMNS:-$(tput cols)}" "  # $1" | tr ' ' ' '
    printf '%*s' "${COLUMNS:-$(tput cols)}" '' | tr ' ' ' '
    printf "\e[0m"
    printf "\n"
}
CONTINUE() {
    read -r -p "$1* [y/N]" response
    case $response in
    [yY][eE][sS] | [yY])
        true
        ;;
    *)
        false
        ;;
    esac
}
MSG_OK() { echo -e "\e[0m[$(tput bold)$(tput setaf 2)✔\e[0m]➜➜➜[$(tput setaf 2)$*\e[0m]"; }
MSG_ERR() { echo -e "\e[0m[$(tput bold)$(tput setaf 1)x\e[0m]➜➜➜[$(tput setaf 1)$*\e[0m]"; }
MSG_INFO() { echo -e "\e[0m[$(tput bold)$(tput setaf 3)➜\e[0m]➜➜➜[$(tput setaf 3)$*\e[0m]"; }
CMD() { command -v "$1" >/dev/null 2>&1; }
EXEC() { type -fP "$1" >/dev/null 2>&1; }
WGET() { wget "$1" --quiet --show-progress; }
CURL() { curl -fSL "$1" -o "$2" --progress-bar; }
ERROR() {
    MSG_ERR "${@}" >&2
    exit 1
}
SUCCESS() { MSG_OK "${@}"; }
FINISHED() {
    MSG_INFO "${@}"
    exit 0
}
CHECK_IF_ROOT() {
    if [ "${EUID}" -ne 0 ]; then
        echo "You need to run this script as super user."
        exit
    fi
}
OS_VERSION() {
    # shellcheck disable=SC2034
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        source '/etc/os-release'
        OS_NAME="$NAME"
        VER_ID="$VERSION_ID"
    elif [ -f /etc/lsb-release ]; then
        # shellcheck disable=SC1091
        source '/etc/lsb-release'
        OS_NAME="$DISTRIB_ID"
        VER_ID="$DISTRIB_RELEASE"
    else
        ERROR "OS not supported"
    fi
}
OS_TYPE() {
    OS="$(uname)"
    case "$OS" in
    Linux)
        OS='linux'
        ;;
    FreeBSD)
        OS='freebsd'
        ;;
    NetBSD)
        OS='netbsd'
        ;;
    OpenBSD)
        OS='openbsd'
        ;;
    Darwin)
        OS='osx'
        ;;
    SunOS)
        OS='solaris'
        ;;
    *)
        ERROR 'OS platform not supported'
        ;;
    esac
}
ARCH_TYPE() {
    ARCH="$(uname -m)"
    case "$ARCH" in
    x86_64 | amd64)
        ARCH='amd64'
        ;;
    i?86 | x86)
        ARCH='386'
        ;;
    aarch64 | arm64)
        ARCH='arm64'
        ;;
    arm*)
        ARCH='arm'
        ;;
    *)
        ERROR 'OS architecture not supported'
        ;;
    esac
}
