#!/usr/bin/env bash

LATEST_URL="https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/latest"
LATEST_VER="$(curl -sL "$LATEST_URL" | grep '"tag_name":' | cut -d'"' -f4)"
LOCAL_VER="$($DCP_EXEC -version)"

RUN_UPDATE() { (cd "$1" && shift && eval "${@}"); }
DCP_RELOAD() {
    $DCP_EXEC -config "$DCP_CONFIG" -check || ERROR "DNSCrypt-Proxy check failed"
    MSG_OK "DNSCrypt-Proxy check successful"
    $DCP_EXEC -config "$DCP_CONFIG" -service restart || ERROR "DNSCrypt-Proxy restart failed, check permissions"
}

DCP_UPDATE_BLOCKLIST() {
    [[ ! -d "$BLOCKLIST_DIR" ]] && mkdir -p "$BLOCKLIST_DIR"
    #TODO: CURL CONFIGS
    MSG_INFO "Generating list"
    RUN_UPDATE "$BLOCKLIST_DIR/" "./generate-domains-blocklist.py -o $DCP_DIR/blocked-names.txt.tmp" || ERROR "Failed to generate list"
    mv -f "$DCP_DIR/blocked-names.txt.tmp" "$DCP_DIR/blocked-names.txt"
    DCP_RELOAD
    MSG_OK "Successfuly updated blocklist"
    exit 0
}

DCP_UPDATE() {
    OS_TYPE
    ARCH_TYPE
    TMP_DIR="$(mktemp -d)"
    TMP_FILE="dnscrypt-proxy-update.tar.gz"
    NEW_FILES="$(date +%F_%H-%M)"

    case ${OS}_${ARCH} in
    linux_amd64)
        DOWNLOAD_URL="$(curl -sL "$LATEST_URL" | grep dnscrypt-proxy-linux_x86_64- | grep browser_download_url | head -1 | cut -d \" -f 4)"
        ;;
    *)
        ERROR "Not not supported"
        ;;
    esac

    TITLE "Starting DNSCrypt Proxy Update"

    CURL "$DOWNLOAD_URL" "$TMP_DIR/$TMP_FILE"
    RESPONSE=$?
    if [ $RESPONSE -ne 0 ]; then
        ERROR "Failed to download"
        rm -rf "$TMP_DIR"
        return 1
    fi

    MSG_OK "Download successful"
    tar xz -C "$TMP_DIR" -f "$TMP_DIR/$TMP_FILE"
    mv -f "${TMP_DIR}/${OS}-*" "$TMP_DIR/dcp"
    mv -f "${TMP_DIR}/dcp/dncrypt-proxy" "$DCP_EXEC"
    mkdir -p "$DCP_DIR/update-${NEW_FILES}"
    mv -f "${TMP_DIR}/dcp/*" "$DCP_DIR/$NEW_FILES"
    DCP_RELOAD
    UPDATE_ANSWER=$?
    rm -Rf "$TMP_DIR"

    if [ $UPDATE_ANSWER -eq 0 ]; then
        MSG_OK "DNSCrypt-proxy has been successfully updated!"
        return 0
    else
        MSG_ERR "DNSCrypt-proxy update failed." >&2
        return 1
    fi
}

DO_DCP_UPDATE() {
    if [ ! -f "${DCP_EXEC}" ]; then
        MSG_ERR "DNSCrypt-proxy is not installed in '${DCP_EXEC}'. Update aborted..." >&2
        exit 1
    fi
    if [ -z "$LOCAL_VER" ] || [ -z "$LATEST_VER" ]; then
        MSG_ERR "Could not retrieve DNSCrypt-proxy version. Update aborted... " >&2
        exit 1
    else
        MSG_INFO "Local: $LOCAL_VER, Latest: $LATEST_VER"
    fi
    if [ "$LOCAL_VER" != "$LATEST_VER" ]; then
        DCP_UPDATE
        exit 0
    else
        MSG_OK "Update not required, version: $LOCAL_VER"
        exit 0
    fi
}
