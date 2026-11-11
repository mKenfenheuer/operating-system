#!/bin/sh
# Build a GPU test variant of a Home Assistant OS raw disk image.
# Runs in a privileged docker:<version>-dind container (Docker version as in HAOS).
#
# usage: make-variant.sh <raw image> <machine>
#   raw image:  modified in place; for the NVIDIA variants the disk image of
#               the OS variant, which has the driver extension already
#   machine:    generic-x86-64 | qemux86-64 (Home Assistant Core image flavour)
#
# Expects in /inputs: supervisor-gpu.tar, core-<machine>.tar (unless CORE_REGISTRY
# and CORE_VERSION are set, then Core is pulled from that registry on first boot)
set -eu
IMG="$1"
MACHINE="$2"
CORE_IMAGE="ghcr.io/home-assistant/${MACHINE}-homeassistant"
SUPERVISOR_IMAGE="ghcr.io/home-assistant/amd64-hassio-supervisor"

apk add -q e2fsprogs e2fsprogs-extra sgdisk parted util-linux jq >/dev/null

# Room for the extra images, HAOS grows the partition to the disk on first boot
truncate -s $(( $(stat -c %s "${IMG}") + 6 * 1024 * 1024 * 1024 )) "${IMG}"
sgdisk -e "${IMG}" >/dev/null
LOOP=$(losetup -fP --show "${IMG}")
cleanup() {
    umount /mnt/data 2>/dev/null || true
    losetup -d "${LOOP}" 2>/dev/null || true
}
trap cleanup EXIT
sleep 1
parted -s "${LOOP}" resizepart 8 100%
partx -u "${LOOP}" 2>/dev/null || true
DATA="${LOOP}p8"
e2fsck -fy "${DATA}" >/dev/null || true
resize2fs "${DATA}" >/dev/null

mkdir -p /mnt/data
mount "${DATA}" /mnt/data
test -f /mnt/data/.docker-use-containerd-snapshotter

# Docker of the image: same data root and snapshotter as the OS uses
dockerd --data-root /mnt/data/docker --feature containerd-snapshotter \
    --host unix:///run/variant-docker.sock --pidfile /run/variant-docker.pid \
    >/tmp/dockerd.log 2>&1 &
export DOCKER_HOST=unix:///run/variant-docker.sock
for _ in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 1; done

docker load -q -i /inputs/supervisor-gpu.tar
docker tag local/supervisor-gpu:test "${SUPERVISOR_IMAGE}:latest"

if [ -n "${CORE_REGISTRY:-}" ]; then
    # Release: Core is pulled from the registry on first boot
    CORE_IMAGE="${CORE_REGISTRY}/${MACHINE}-homeassistant"
else
    docker load -q -i "/inputs/core-${MACHINE}.tar"
    CORE_VERSION=$(docker run --rm --entrypoint python3 "local/homeassistant-gpu:test-${MACHINE}" \
        -c "import homeassistant.const as c; print(c.__version__)")
    docker tag "local/homeassistant-gpu:test-${MACHINE}" "${CORE_IMAGE}:${CORE_VERSION}"
fi
docker images --format '{{.Repository}}:{{.Tag}}' | sort

kill "$(cat /run/variant-docker.pid)"
for _ in $(seq 1 30); do [ -e /run/variant-docker.pid ] || break; sleep 1; done

# Core is installed already, so the Supervisor skips the landing page.
# override_image keeps the Supervisor on the GHCR image of the fork.
jq -n --arg version "${CORE_VERSION}" --arg image "${CORE_IMAGE}" \
    '{version: $version, image: $image, override_image: true}' > /mnt/data/supervisor/homeassistant.json

ls -laR /mnt/data/supervisor/extensions 2>/dev/null || echo "no extensions"
cat /mnt/data/supervisor/homeassistant.json
df -h /mnt/data | tail -1
umount /mnt/data
losetup -d "${LOOP}"
trap - EXIT
echo "VARIANT_DONE ${IMG}"
