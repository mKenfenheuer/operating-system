#!/bin/bash
# shellcheck disable=SC2155

# Pack the trees below ${HAOS_SYSEXT_DIR} into systemd system extension
# images (https://uapi-group.org/specifications/specs/extension_image/).
# Packages which are too large for the root file system (e.g. the NVIDIA
# driver) install into ${HAOS_SYSEXT_DIR}/<name> instead of TARGET_DIR.
#
# The extension-release file pins each image to the exact OS version (and
# so to the kernel) it was built with. systemd-sysext refuses to merge an
# image built for a different version.

function path_sysext_dir() {
    echo "${BASE_DIR}/sysext"
}

function sysext_architecture() {
    case "${SUPERVISOR_ARCH}" in
        amd64) echo "x86-64" ;;
        aarch64) echo "arm64" ;;
        *) echo "${SUPERVISOR_ARCH}" ;;
    esac
}

function create_sysext_images() {
    local sysext_dir="$(path_sysext_dir)"
    local tree name image

    [ -d "${sysext_dir}" ] || return 0

    for tree in "${sysext_dir}"/*/; do
        [ -d "${tree}usr" ] || continue
        name="$(basename "${tree}")"
        image="$(haos_image_name "${name}.raw")"

        mkdir -p "${tree}usr/lib/extension-release.d"
        (
            echo "ID=${HAOS_ID}"
            echo "VERSION_ID=$(haos_version)"
            echo "ARCHITECTURE=$(sysext_architecture)"
        ) > "${tree}usr/lib/extension-release.d/extension-release.${name}"

        echo "Creating system extension image ${image}"
        rm -f "${image}"
        "${HOST_DIR}/bin/mkfs.erofs" -zlz4hc,12 -T 0 --all-root \
            "${image}" "${tree}"
    done
}
