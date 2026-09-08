#!/bin/zsh
# Release-process watchdog and generated-stamp cleanup helpers.

terminate_process_tree() {
    local process_pid="$1"
    local child_pid
    for child_pid in $(pgrep -P "${process_pid}" 2>/dev/null); do
        terminate_process_tree "${child_pid}"
    done
    kill -TERM "${process_pid}" 2>/dev/null || true
}

terminate_active_child() {
    if [[ -z "${ACTIVE_CHILD_PID}" ]] || ! kill -0 "${ACTIVE_CHILD_PID}" 2>/dev/null; then
        ACTIVE_CHILD_PID=""
        return
    fi
    echo "   Stopping child process ${ACTIVE_CHILD_PID}..."
    terminate_process_tree "${ACTIVE_CHILD_PID}"
    local waited=0
    while kill -0 "${ACTIVE_CHILD_PID}" 2>/dev/null && (( waited < 10 )); do
        sleep 1
        (( waited += 1 ))
    done
    if kill -0 "${ACTIVE_CHILD_PID}" 2>/dev/null; then
        kill -KILL "${ACTIVE_CHILD_PID}" 2>/dev/null || true
    fi
    wait "${ACTIVE_CHILD_PID}" 2>/dev/null || true
    ACTIVE_CHILD_PID=""
}

restore_version_stamp() {
    if [[ -z "${STAMP_BACKUP_DIR}" ]] || [[ ! -d "${STAMP_BACKUP_DIR}" ]]; then
        return
    fi
    cp "${STAMP_BACKUP_DIR}/curr_version.asc" "${PROJECT_DIR}/GUI/Resources/curr_version.asc"
    cp "${STAMP_BACKUP_DIR}/project.pbxproj" "${PROJECT_FILE}/project.pbxproj"
    rm -rf "${STAMP_BACKUP_DIR}"
    STAMP_BACKUP_DIR=""
}

release_cleanup() {
    local exit_code=$?
    terminate_active_child
    cleanup_dmg_mount
    restore_version_stamp
    if [[ "${RELEASE_SUCCEEDED}" != "true" ]] && (( exit_code != 0 )); then
        echo "   Release stopped; generated version-stamp changes were restored."
    fi
}

TRAPINT() {
    echo ""
    echo "⚠️  Release interrupted."
    exit 130
}

TRAPTERM() {
    echo ""
    echo "⚠️  Release terminated."
    exit 143
}

resolve_release_packages() {
    local attempt
    local current_size
    local idle_seconds
    local last_size
    local resolution_timed_out
    for (( attempt = 1; attempt <= PACKAGE_MAX_ATTEMPTS; attempt++ )); do
        zsh "${PROJECT_DIR}/Scripts/preserve_tmp_log.zsh" "${PACKAGE_LOG}"
        xcodebuild -resolvePackageDependencies \
            -skipPackageUpdates \
            -project "${PROJECT_FILE}" \
            -scheme "${SCHEME}" \
            -destination "platform=macOS" \
            -clonedSourcePackagesDirPath "${PROJECT_DIR}/.spm-checkouts" \
            >"${PACKAGE_LOG}" 2>&1 &
        ACTIVE_CHILD_PID=$!
        last_size=0
        idle_seconds=0
        resolution_timed_out=false
        while kill -0 "${ACTIVE_CHILD_PID}" 2>/dev/null; do
            sleep 5
            current_size="$(stat -f %z "${PACKAGE_LOG}" 2>/dev/null || echo 0)"
            if [[ "${current_size}" == "${last_size}" ]]; then
                (( idle_seconds += 5 ))
            else
                last_size="${current_size}"
                idle_seconds=0
            fi
            if (( idle_seconds >= PACKAGE_IDLE_TIMEOUT )); then
                echo "   ⚠️  No package resolver output for ${PACKAGE_IDLE_TIMEOUT}s."
                resolution_timed_out=true
                terminate_active_child
                break
            fi
        done
        if [[ "${resolution_timed_out}" == "false" ]]; then
            if wait "${ACTIVE_CHILD_PID}"; then
                ACTIVE_CHILD_PID=""
                tail -5 "${PACKAGE_LOG}"
                return
            fi
            ACTIVE_CHILD_PID=""
        fi
        echo "   Package resolution attempt ${attempt}/${PACKAGE_MAX_ATTEMPTS} failed."
        tail -20 "${PACKAGE_LOG}"
        if (( attempt < PACKAGE_MAX_ATTEMPTS )); then
            echo "   Retrying package resolution once..."
        fi
    done
    echo "❌ Package resolution failed. Log: ${PACKAGE_LOG}"
    return 1
}

trap release_cleanup EXIT
