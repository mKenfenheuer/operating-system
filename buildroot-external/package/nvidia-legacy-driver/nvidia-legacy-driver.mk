################################################################################
#
# NVIDIA proprietary kernel modules and user space for Maxwell, Pascal and
# Volta GPUs (system extension)
#
################################################################################

# 580 is the last driver branch which supports these GPUs (long term support)
NVIDIA_LEGACY_DRIVER_VERSION = 580.196.07
NVIDIA_LEGACY_DRIVER_SITE = https://download.nvidia.com/XFree86/Linux-x86_64/$(NVIDIA_LEGACY_DRIVER_VERSION)
NVIDIA_LEGACY_DRIVER_SOURCE = NVIDIA-Linux-x86_64-$(NVIDIA_LEGACY_DRIVER_VERSION).run
NVIDIA_LEGACY_DRIVER_LICENSE = NVIDIA Software License
NVIDIA_LEGACY_DRIVER_LICENSE_FILES = LICENSE
NVIDIA_LEGACY_DRIVER_REDISTRIBUTE = NO

NVIDIA_LEGACY_DRIVER_INSTALL_TARGET = NO
NVIDIA_LEGACY_DRIVER_INSTALL_IMAGES = YES

NVIDIA_LEGACY_DRIVER_EXTRACT_CMDS = $(call NVIDIA_DRIVER_EXTRACT,NVIDIA_LEGACY_DRIVER)

NVIDIA_LEGACY_DRIVER_MODULE_SUBDIRS = kernel
NVIDIA_LEGACY_DRIVER_MODULE_MAKE_OPTS = \
	IGNORE_CC_MISMATCH=1 \
	NV_KERNEL_SOURCES="$(LINUX_DIR)" \
	NV_KERNEL_OUTPUT="$(LINUX_DIR)" \
	NV_KERNEL_MODULES="$(NVIDIA_DRIVER_MODULES)"

NVIDIA_LEGACY_DRIVER_INSTALL_IMAGES_CMDS = \
	$(call NVIDIA_DRIVER_INSTALL_SYSEXT,NVIDIA_LEGACY_DRIVER,nvidia-legacy,kernel)

$(eval $(kernel-module))
$(eval $(generic-package))
