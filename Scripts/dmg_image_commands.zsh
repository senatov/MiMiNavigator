#!/bin/zsh
# MARK: - Disk image commands for release packaging

dmg_image_select_backend() {
    local create_help
    local attach_help
    if create_help="$(diskutil image create from --help 2>&1)" &&
       attach_help="$(diskutil image attach --help 2>&1)" &&
       [[ "${create_help}" == *UDSB* && "${create_help}" == *UDZO* && "${attach_help}" == *--mountOptions* ]]; then
        DMG_IMAGE_BACKEND=diskutil
    else
        DMG_IMAGE_BACKEND=hdiutil
    fi
}

dmg_image_create_rw() {
    local source_folder="$1"
    local volume_name="$2"
    local image_path="$3"
    if [[ "${DMG_IMAGE_BACKEND}" == diskutil ]]; then
        diskutil image create from --format UDSB --volumeName "${volume_name}" "${source_folder}" "${image_path}"
    else
        hdiutil create -volname "${volume_name}" -srcfolder "${source_folder}" -ov -format UDRW "${image_path}"
    fi
}

dmg_image_attach() {
    local image_path="$1"
    local access="$2"
    if [[ "${DMG_IMAGE_BACKEND}" == diskutil ]]; then
        if [[ "${access}" == readonly ]]; then
            diskutil image attach --readOnly --mountOptions nobrowse "${image_path}"
        else
            diskutil image attach --mountOptions nobrowse "${image_path}"
        fi
    elif [[ "${access}" == readonly ]]; then
        hdiutil attach -readonly -noverify -nobrowse "${image_path}"
    else
        hdiutil attach -readwrite -noverify -nobrowse "${image_path}"
    fi
}

dmg_image_detach() {
    local device="$1"
    if [[ "${DMG_IMAGE_BACKEND}" == diskutil ]]; then
        diskutil eject "${device}"
    else
        hdiutil detach "${device}"
    fi
}

dmg_image_convert() {
    local source_image="$1"
    local compressed_image="$2"
    if [[ "${DMG_IMAGE_BACKEND}" == diskutil ]]; then
        diskutil image create from --format UDZO "${source_image}" "${compressed_image}"
    else
        hdiutil convert "${source_image}" -format UDZO -o "${compressed_image}"
    fi
}

dmg_image_remove_rw() {
    local image_path="$1"
    if [[ "${DMG_IMAGE_BACKEND}" == diskutil ]]; then
        rm -rf -- "${image_path}"
    else
        rm -f -- "${image_path}"
    fi
}
