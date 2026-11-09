################################################################################
#
# NVIDIA open GPU kernel modules and user space (system extension)
#
################################################################################

NVIDIA_OPEN_DRIVER_VERSION = 615.78.08
NVIDIA_OPEN_DRIVER_SITE = https://download.nvidia.com/XFree86/Linux-x86_64/$(NVIDIA_OPEN_DRIVER_VERSION)
NVIDIA_OPEN_DRIVER_SOURCE = NVIDIA-Linux-x86_64-$(NVIDIA_OPEN_DRIVER_VERSION).run
NVIDIA_OPEN_DRIVER_LICENSE = MIT or GPL-2.0 (kernel modules), NVIDIA Software License (user space, firmware)
NVIDIA_OPEN_DRIVER_LICENSE_FILES = LICENSE
NVIDIA_OPEN_DRIVER_REDISTRIBUTE = NO

# Nothing is installed into the root file system. Everything goes into the
# tree of the "nvidia" system extension (see HAOS_SYSEXT_DIR in external.mk),
# which post-image.sh packs into a separate image.
NVIDIA_OPEN_DRIVER_INSTALL_TARGET = NO
NVIDIA_OPEN_DRIVER_INSTALL_IMAGES = YES
NVIDIA_OPEN_DRIVER_SYSEXT_DIR = $(HAOS_SYSEXT_DIR)/nvidia

# The downloaded archive is a self-extracting shell script which refuses to
# extract into an existing directory.
define NVIDIA_OPEN_DRIVER_EXTRACT_CMDS
	$(SHELL) $(NVIDIA_OPEN_DRIVER_DL_DIR)/$(NVIDIA_OPEN_DRIVER_SOURCE) \
		--extract-only --target $(@D)/tmp-extract
	chmod u+w -R $(@D)
	mv $(@D)/tmp-extract/* $(@D)/tmp-extract/.manifest $(@D)
	rmdir $(@D)/tmp-extract
endef

# Apps only need compute, no display/modesetting support.
NVIDIA_OPEN_DRIVER_MODULES = nvidia nvidia-uvm

NVIDIA_OPEN_DRIVER_MODULE_SUBDIRS = kernel-open
NVIDIA_OPEN_DRIVER_MODULE_MAKE_OPTS = \
	IGNORE_CC_MISMATCH=1 \
	NV_KERNEL_SOURCES="$(LINUX_DIR)" \
	NV_KERNEL_OUTPUT="$(LINUX_DIR)" \
	NV_KERNEL_MODULES="$(NVIDIA_OPEN_DRIVER_MODULES)"

# User space needed for CUDA, NVML (nvidia-smi), NVENC/NVDEC and optical
# flow. OpenGL, Vulkan and OpenCL are left out to keep the extension small.
NVIDIA_OPEN_DRIVER_LIBS = \
	libcuda.so.$(NVIDIA_OPEN_DRIVER_VERSION) \
	libnvidia-cfg.so.$(NVIDIA_OPEN_DRIVER_VERSION) \
	libnvidia-encode.so.$(NVIDIA_OPEN_DRIVER_VERSION) \
	libnvidia-gpucomp.so.$(NVIDIA_OPEN_DRIVER_VERSION) \
	libnvidia-ml.so.$(NVIDIA_OPEN_DRIVER_VERSION) \
	libnvidia-nvvm.so.$(NVIDIA_OPEN_DRIVER_VERSION) \
	libnvidia-nvvm70.so.4 \
	libnvidia-opticalflow.so.$(NVIDIA_OPEN_DRIVER_VERSION) \
	libnvidia-ptxjitcompiler.so.$(NVIDIA_OPEN_DRIVER_VERSION) \
	libnvcuvid.so.$(NVIDIA_OPEN_DRIVER_VERSION)

NVIDIA_OPEN_DRIVER_BINS = nvidia-smi nvidia-modprobe

NVIDIA_OPEN_DRIVER_MODDIR = \
	$(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/lib/modules/$(LINUX_VERSION_PROBED)/updates/nvidia

# Install a library and create the SONAME symlink, e.g.
# libcuda.so.1 -> libcuda.so.615.78.08
# $(1): library file name
define NVIDIA_OPEN_DRIVER_INSTALL_LIB
	$(INSTALL) -D -m 0755 $(@D)/$(1) $(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/lib/$(1)
	soname=$$($(TARGET_READELF) -d $(@D)/$(1) | sed -n 's/.*(SONAME).*\[\(.*\)\]/\1/p'); \
	if [ -n "$${soname}" ] && [ "$${soname}" != "$(1)" ]; then \
		ln -sf $(1) $(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/lib/$${soname}; \
	fi
endef

define NVIDIA_OPEN_DRIVER_INSTALL_IMAGES_CMDS
	$(foreach m,$(NVIDIA_OPEN_DRIVER_MODULES), \
		$(INSTALL) -D -m 0644 $(@D)/kernel-open/$(m).ko \
			$(NVIDIA_OPEN_DRIVER_MODDIR)/$(m).ko$(sep) \
		$(TARGET_STRIP) --strip-debug $(NVIDIA_OPEN_DRIVER_MODDIR)/$(m).ko$(sep))
	$(foreach l,$(NVIDIA_OPEN_DRIVER_LIBS), \
		$(call NVIDIA_OPEN_DRIVER_INSTALL_LIB,$(l))$(sep))
	ln -sf libcuda.so.1 $(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/lib/libcuda.so
	ln -sf libnvidia-ml.so.1 $(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/lib/libnvidia-ml.so
	$(foreach b,$(NVIDIA_OPEN_DRIVER_BINS), \
		$(INSTALL) -D -m 0755 $(@D)/$(b) \
			$(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/bin/$(b)$(sep))
	$(INSTALL) -d $(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/lib/firmware/nvidia/$(NVIDIA_OPEN_DRIVER_VERSION)
	$(INSTALL) -m 0644 $(@D)/firmware/*.bin \
		$(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/lib/firmware/nvidia/$(NVIDIA_OPEN_DRIVER_VERSION)/
	$(INSTALL) -D -m 0755 $(NVIDIA_OPEN_DRIVER_PKGDIR)/haos-nvidia-setup \
		$(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/libexec/haos-nvidia-setup
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(NVIDIA_OPEN_DRIVER_SYSEXT_DIR)/usr/share/licenses/nvidia-driver/LICENSE
endef

$(eval $(kernel-module))
$(eval $(generic-package))
