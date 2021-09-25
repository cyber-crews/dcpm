#!/bin/bash

readonly BOLD="\033[1m"
readonly NORM="\033[0m"
readonly INFO="${BOLD}[INFO]: $NORM"
readonly ERROR="${BOLD}[ERROR]: $NORM"
readonly WARNING="${BOLD}[WARNING]: $NORM"

readonly BASE_DIR="/opt"
readonly TARG_DIR="${BASE_DIR}/dnscrypt-proxy"
readonly LATEST_URL="https://api.github.com/repos/jedisct1/dnscrypt-proxy/releases/latest"
readonly RESOLVERS_URL_PREFIX="https://download.dnscrypt.info/resolvers-list/v3/"
readonly DNSCRYPT_PUBLIC_KEY="RWTk1xXqcTODeYttYMCMLo0YJHaFEHn7a3akqHlb/7QvIQXHVPxKbjB5"
readonly LOCAL_VERSION=$("${TARG_DIR}/dnscrypt-proxy" -version)
readonly REMOTE_VERSION=$(curl -sL "$LATEST_URL" | grep "tag_name" | head -1 | cut -d \" -f 4)

case $(uname -m) in
  armv7l)
    DNSCRYPT_ARCH=linux_arm
    DNSCRYPT_ARCH_TAR=linux-arm
    echo -e "$INFO Detected ARMv7 architecture."
    ;;
  aarch64)
    DNSCRYPT_ARCH=linux_arm64
    DNSCRYPT_ARCH_TAR=linux-arm64
    echo -e "$INFO Detected ARMv8 architecture."
    ;;
  *) 
    echo "$ERROR This is unsupported platform, sorry."
    exit 1
    ;;
esac

download() {
  local TARG="$1"; shift
  local PERM=$1; shift
  local URL
  local FILENAME
  local MD5SUM_OLD
  local MD5SUM_CURR
  for URL in "$@"; do
    FILENAME="$(basename "$URL")"
    MD5SUM_OLD="$([ -f "$TARG"/"$FILENAME" ] && md5sum "$TARG"/"$FILENAME" | cut -d' ' -f1)"
    MD5SUM_CURR="$(curl -fsL "$URL" | md5sum | awk '{print $1}')"
    if [ $(echo -n "$MD5SUM_CURR" | wc -c) -eq 32 ] && [ "$MD5SUM_CURR" == "$MD5SUM_OLD" ]; then
      echo -e "$INFO $FILENAME is up to date. Skipping..."
    else
      local COUNT=0
      while [ $COUNT -lt 3 ]; do
        echo -e "$INFO Downloading $FILENAME"
        curl -L -k -s "$URL" -o "$TARG"/"$FILENAME"
        if [ $? -eq 0 ]; then
          chmod "$PERM" "$TARG"/"$FILENAME"
          break
        fi
        COUNT=$((COUNT+1))
      done
      if [ $COUNT -eq 3 ]; then
        echo -e "$ERROR Unable to download ${BOLD}${URL}${NORM}"
      fi
    fi
  done
}

Update() {
  DNSCRYPT_TAR=dnscrypt-proxy-${DNSCRYPT_ARCH}-${REMOTE_VERSION}.tar.gz
  DOWNLOAD_URL="https://github.com/jedisct1/dnscrypt-proxy/releases/download/"${REMOTE_VERSION}"/"${DNSCRYPT_TAR}""
  echo -e "$INFO Downloading update from '$DOWNLOAD_URL'..."
  download $BASE_DIR 644 "$DOWNLOAD_URL"
  response=$?

  if [ $response -ne 0 ]; then
    echo -e "$ERROR Could not download file from '$DOWNLOAD_URL'" >&2
    [ -f "${BASE_DIR}/${DNSCRYPT_TAR}" ] && rm -Rf "${BASE_DIR}/${DNSCRYPT_TAR}" 
    return 1
  fi

  if [ -x "$(command -v minisign)" ]; then
    download $BASE_DIR 644 "${DOWNLOAD_URL}.minisig"
    minisign -Vm "${BASE_DIR}/${DNSCRYPT_TAR}" -P "$DNSCRYPT_PUBLIC_KEY"
    valid_file=$?

    if [ $valid_file -ne 0 ]; then
      echo -e "$ERROR Downloaded file has failed signature verification. Update aborted." >&2
      [ -f "${BASE_DIR}/${DNSCRYPT_TAR}" ] && rm -Rf "${BASE_DIR}/${DNSCRYPT_TAR}" 
      [ -f "${BASE_DIR}/${DNSCRYPT_TAR}.minisig" ] && rm -Rf "${BASE_DIR}/${DNSCRYPT_TAR}.minisig"
      return 1
    fi
  else
    echo -e "$WARNING minisign is not installed, downloaded file signature could not be verified."
  fi

  echo -e "$INFO Initiating update of DNSCrypt-proxy"
  tar xzv -C "${BASE_DIR}" -f "${BASE_DIR}/${DNSCRYPT_TAR}" &&
    mv -f "${TARG_DIR}/dnscrypt-proxy" "${TARG_DIR}/dnscrypt-proxy.old" &&
    mv -f ${BASE_DIR}/${DNSCRYPT_ARCH_TAR}/* ${TARG_DIR}/ &&
    chmod u+x "${TARG_DIR}/dnscrypt-proxy" &&
  Update-Resolv 0
  [ -f "${BASE_DIR}/${DNSCRYPT_TAR}" ] && rm -Rf "${BASE_DIR}/${DNSCRYPT_TAR}" 
  [ -d "${BASE_DIR}/${DNSCRYPT_ARCH_TAR}" ] && rm -Rf "${BASE_DIR}/${DNSCRYPT_ARCH_TAR}"
  [ -f "${BASE_DIR}/${DNSCRYPT_TAR}.minisig" ] && rm -Rf "${BASE_DIR}/${DNSCRYPT_TAR}.minisig"
}

Update-Resolv() {
    cd "$TARG_DIR" && 
    download $TARG_DIR 644 $RESOLVERS_URL_PREFIX/public-resolvers.md \
        $RESOLVERS_URL_PREFIX/public-resolvers.md.minisig \
        $RESOLVERS_URL_PREFIX/relays.md \
        $RESOLVERS_URL_PREFIX/relays.md.minisig ||
    chown root:root ${TARG_DIR}/public-resolvers.md ${TARG_DIR}/public-resolvers.md.minisig ${TARG_DIR}/relays.md ${TARG_DIR}/relays.md.minisig ||
    ./dnscrypt-proxy -check && ./dnscrypt-proxy -service install 2>/dev/null || : &&
    ./dnscrypt-proxy -service restart || ./dnscrypt-proxy -service start
  updated_successfully=$?
  if [ $updated_successfully -eq 0 ] && [ "$1" == "0" ]; then
    echo -e "$INFO DNSCrypt-proxy has been successfully updated! Resolver files have been checked!"
    return 0
  elif [ $updated_successfully -eq 1 ] && [ "$1" == "0" ]; then
    echo -e "$ERROR Unable to complete DNSCrypt-proxy update & check Resolver files. Update & check has been aborted." >&2
    return 1
  fi
  if [ $updated_successfully -eq 0 ] && [ "$1" == "1" ]; then
    echo -e "$INFO DNSCrypt-proxy Resolver files have been checked!"
    return 0
  elif [ $updated_successfully -eq 1 ] && [ "$1" == "1" ]; then
    echo -e "$ERROR Unable to check DNSCrypt-proxy Resolver files. Check has been aborted." >&2
    return 1
  fi
}

if [ ! -f "${TARG_DIR}/dnscrypt-proxy" ]; then
  echo -e "$ERROR DNSCrypt-proxy is not installed in '${TARG_DIR}/dnscrypt-proxy'. Update aborted..." >&2
  exit 1
fi

if [ -z "$LOCAL_VERSION" ] || [ -z "$REMOTE_VERSION" ]; then
  echo -e "$ERROR Could not retrieve DNSCrypt-proxy version. Update aborted... " >&2
  exit 1
else
  echo -e "$INFO LOCAL_VERSION=$LOCAL_VERSION, REMOTE_VERSION=$REMOTE_VERSION"
fi

if [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
  echo -e "$INFO LOCAL_VERSION is not synced with REMOTE_VERSION, initiating update..."
  Update
  exit $?
else
  Update-Resolv 1
  echo -e "$INFO No new version available for DNSCrypt-proxy."
  exit $?
fi
