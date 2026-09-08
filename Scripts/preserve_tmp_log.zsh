#!/bin/zsh
# Preserve a previous MiMiNavigator temporary log before a command overwrites it.

set -eu

LOG_PATH="${1:-}"
if [[ -z "${LOG_PATH}" || "${LOG_PATH}" != /tmp/mimi*.log ]]; then
    echo "Refusing to archive unexpected log path: ${LOG_PATH}" >&2
    exit 2
fi
if [[ ! -s "${LOG_PATH}" ]]; then
    exit 0
fi

LOG_DIR="${LOG_PATH:h}"
LOG_NAME="${LOG_PATH:t:r}"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
ARCHIVE_PATH="${LOG_DIR}/${LOG_NAME}.previous-${TIMESTAMP}.log"
if [[ -e "${ARCHIVE_PATH}" ]]; then
    ARCHIVE_PATH="${LOG_DIR}/${LOG_NAME}.previous-${TIMESTAMP}-${RANDOM}.log"
fi
mv -- "${LOG_PATH}" "${ARCHIVE_PATH}"

typeset -a ARCHIVES
ARCHIVES=("${LOG_DIR}/${LOG_NAME}.previous-"*.log(N.om))
if (( ${#ARCHIVES} > 10 )); then
    for EXPIRED_LOG in "${ARCHIVES[@]:10}"; do
        rm -f -- "${EXPIRED_LOG}"
    done
fi

echo "Preserved previous log: ${ARCHIVE_PATH}"
