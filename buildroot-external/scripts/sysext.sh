#!/bin/bash
# shellcheck disable=SC2155

# Pack the trees below ${HAOS_SYSEXT_DIR} into systemd system extension
# images (https://uapi-group.org/specifications/specs/extension_image/).
# Packages which are too large for the root file system (e.g. the NVIDIA
# driver) install into ${HAOS_SYSEXT_DIR}/<name> instead of TARGET_DIR.
#
# Every extension becomes an OS variant with the same name: the variant's
# disk image and update bundle carry the extension image, which is placed
# on the data partition in /mnt/data/supervisor/extensions/<version>/.
#
# The extension-release file pins each image to the exact OS version (and
# so to the kernel) it was built with. The root file system holds the
# SHA256 of every extension image of its build, haos-sysext-select only
# merges images which match.

function path_sysext_dir() {
    echo "${BASE_DIR}/sysext"
}

function path_sysext_images() {
    echo "${BINARIES_DIR}/sysext"
}

function sysext_architecture() {
    case "${SUPERVISOR_ARCH}" in
        amd64) echo "x86-64" ;;
        aarch64) echo "arm64" ;;
        *) echo "${SUPERVISOR_ARCH}" ;;
    esac
}

# Fail the build if an extension doesn't fit the kernel and root file system
# it is built for: wrong kernel release, missing firmware or libraries.
function check_sysext_tree() {
    local tree="${1}"
    local kernel_release module vermagic firmware elf lib found dir
    local errors=0

    kernel_release="$(basename "$(find "${TARGET_DIR}/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d | head -n 1)")"

    while IFS= read -r module; do
        vermagic="$(strings -a "${module}" | sed -n 's/^vermagic=\([^ ]*\).*/\1/p' | head -n 1)"
        if [ "${vermagic}" != "${kernel_release}" ]; then
            echo "ERROR: ${module#"${tree}"} is built for kernel '${vermagic}', not '${kernel_release}'"
            errors=$((errors + 1))
        fi
        if ! echo "${module}" | grep -q "/lib/modules/${kernel_release}/"; then
            echo "ERROR: ${module#"${tree}"} is not below /usr/lib/modules/${kernel_release}"
            errors=$((errors + 1))
        fi
        for firmware in $(strings -a "${module}" | sed -n 's/^firmware=//p'); do
            if [ ! -e "${tree}usr/lib/firmware/${firmware}" ] \
                && [ ! -e "${TARGET_DIR}/usr/lib/firmware/${firmware}" ]; then
                echo "ERROR: firmware ${firmware} of ${module##*/} is missing"
                errors=$((errors + 1))
            fi
        done
    done < <(find "${tree}" -name '*.ko' -type f)

    while IFS= read -r elf; do
        file -b "${elf}" | grep -q '^ELF' || continue
        for lib in $(readelf -d "${elf}" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
            found=false
            for dir in "${tree}usr/lib" "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/lib"; do
                if [ -e "${dir}/${lib}" ]; then
                    found=true
                    break
                fi
            done
            if [ "${found}" = false ]; then
                echo "ERROR: ${elf#"${tree}"} needs ${lib}, which is missing"
                errors=$((errors + 1))
            fi
        done
    done < <(find "${tree}usr/bin" "${tree}usr/sbin" "${tree}usr/libexec" "${tree}usr/lib" \
        -maxdepth 1 -type f 2>/dev/null)

    if [ "${errors}" -gt 0 ]; then
        echo "System extension $(basename "${tree}") has ${errors} error(s)"
        return 1
    fi
}

# Runs in post-build: the root file system gets the hashes of the images.
function create_sysext_images() {
    local sysext_dir="$(path_sysext_dir)"
    local images="$(path_sysext_images)"
    local hashes="${TARGET_DIR}/usr/lib/haos/sysext"
    local tree name image

    rm -rf "${images}" "${hashes}"
    [ -d "${sysext_dir}" ] || return 0
    mkdir -p "${images}" "${hashes}"

    for tree in "${sysext_dir}"/*/; do
        [ -d "${tree}usr" ] || continue
        name="$(basename "${tree}")"
        image="${images}/${name}.raw"

        check_sysext_tree "${tree}"

        mkdir -p "${tree}usr/lib/extension-release.d"
        (
            echo "ID=${HAOS_ID}"
            echo "VERSION_ID=$(haos_version)"
            echo "ARCHITECTURE=$(sysext_architecture)"
        ) > "${tree}usr/lib/extension-release.d/extension-release.${name}"

        echo "Creating system extension image ${image}"
        "${HOST_DIR}/bin/mkfs.erofs" -zlz4hc,12 -T 0 --all-root \
            "${image}" "${tree}"
        sha256sum "${image}" | cut -d' ' -f1 > "${hashes}/${name}.sha256"
    done
}

# Names of the OS variants, one per extension image
function sysext_variants() {
    local image

    for image in "$(path_sysext_images)"/*.raw; do
        [ -f "${image}" ] || continue
        basename "${image}" .raw
    done
}

# Copy of the data partition image with the extension of the variant
function create_variant_data_image() {
    local variant="${1}"
    local data_img="${2}"
    local image="$(path_sysext_images)/${variant}.raw"
    local dir="supervisor/extensions/$(haos_version)"
    local block_count block_size

    rm -f "${data_img}"
    cp "$(path_data_img)" "${data_img}"
    truncate --size=+$(($(stat -c %s "${image}") + 64 * 1024 * 1024)) "${data_img}"
    resize2fs -f "${data_img}"

    debugfs -w "${data_img}" <<EOF
mkdir supervisor/extensions
mkdir ${dir}
write ${image} ${dir}/${variant}.raw
sif supervisor/extensions uid 0
sif supervisor/extensions gid 0
sif ${dir} uid 0
sif ${dir} gid 0
sif ${dir}/${variant}.raw uid 0
sif ${dir}/${variant}.raw gid 0
EOF

    e2fsck -f -y "${data_img}"
    resize2fs -M "${data_img}"
    block_count=$(dumpe2fs -h "${data_img}" 2>/dev/null | awk '/^Block count:/{print $3}')
    block_size=$(dumpe2fs -h "${data_img}" 2>/dev/null | awk '/^Block size:/{print $3}')
    truncate --size="$((block_count * block_size))" "${data_img}"
}

# Disk image and update bundle of a variant
function create_variant_disk_image() {
    local variant="${1}"
    local data_img="${BINARIES_DIR}/data-${variant}.ext4"

    create_variant_data_image "${variant}" "${data_img}"

    HAOS_VARIANT="${variant}" \
    HAOS_DATA_IMAGE="${data_img}" \
    RAUC_EXTENSION="${variant}" \
    RAUC_EXTENSION_IMAGE="$(path_sysext_images)/${variant}.raw" \
        create_disk_image

    rm -f "${data_img}"
}
