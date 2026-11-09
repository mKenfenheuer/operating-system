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

NVIDIA_OPEN_DRIVER_EXTRACT_CMDS = $(call NVIDIA_DRIVER_EXTRACT,NVIDIA_OPEN_DRIVER)

NVIDIA_OPEN_DRIVER_MODULE_SUBDIRS = kernel-open
NVIDIA_OPEN_DRIVER_MODULE_MAKE_OPTS = \
	IGNORE_CC_MISMATCH=1 \
	NV_KERNEL_SOURCES="$(LINUX_DIR)" \
	NV_KERNEL_OUTPUT="$(LINUX_DIR)" \
	NV_KERNEL_MODULES="$(NVIDIA_DRIVER_MODULES)"

NVIDIA_OPEN_DRIVER_INSTALL_IMAGES_CMDS = \
	$(call NVIDIA_DRIVER_INSTALL_SYSEXT,NVIDIA_OPEN_DRIVER,nvidia,kernel-open)

################################################################################
# Shared with nvidia-legacy-driver
################################################################################

# Apps only need compute, no display/modesetting support.
NVIDIA_DRIVER_MODULES = nvidia nvidia-uvm

# User space needed for CUDA, NVML (nvidia-smi), NVENC/NVDEC and optical
# flow. OpenGL, Vulkan and OpenCL are left out to keep the extension small.
# $(1): driver version
NVIDIA_DRIVER_LIBS = \
	libcuda.so.$(1) \
	libnvidia-cfg.so.$(1) \
	libnvidia-encode.so.$(1) \
	libnvidia-gpucomp.so.$(1) \
	libnvidia-ml.so.$(1) \
	libnvidia-nvvm.so.$(1) \
	libnvidia-nvvm70.so.4 \
	libnvidia-opticalflow.so.$(1) \
	libnvidia-ptxjitcompiler.so.$(1) \
	libnvcuvid.so.$(1)

NVIDIA_DRIVER_BINS = nvidia-smi nvidia-modprobe

# The downloaded archive is a self-extracting shell script which refuses to
# extract into an existing directory.
# $(1): package variable prefix
define NVIDIA_DRIVER_EXTRACT
	$(SHELL) $($(1)_DL_DIR)/$($(1)_SOURCE) --extract-only --target $(@D)/tmp-extract
	chmod u+w -R $(@D)
	mv $(@D)/tmp-extract/* $(@D)/tmp-extract/.manifest $(@D)
	rmdir $(@D)/tmp-extract
endef

# Install a library and create the SONAME symlink, e.g.
# libcuda.so.1 -> libcuda.so.615.78.08
# $(1): library file name, $(2): extension tree
define NVIDIA_DRIVER_INSTALL_LIB
	$(INSTALL) -D -m 0755 $(@D)/$(1) $(2)/usr/lib/$(1)
	soname=$$($(TARGET_READELF) -d $(@D)/$(1) | sed -n 's/.*(SONAME).*\[\(.*\)\]/\1/p'); \
	if [ -n "$${soname}" ] && [ "$${soname}" != "$(1)" ]; then \
		ln -sf $(1) $(2)/usr/lib/$${soname}; \
	fi
endef

# $(1): package variable prefix, $(2): extension name,
# $(3): directory of the kernel modules
define NVIDIA_DRIVER_INSTALL_SYSEXT
	$(foreach m,$(NVIDIA_DRIVER_MODULES), \
		$(INSTALL) -D -m 0644 $(@D)/$(3)/$(m).ko \
			$(HAOS_SYSEXT_DIR)/$(2)/usr/lib/modules/$(LINUX_VERSION_PROBED)/updates/nvidia/$(m).ko$(sep) \
		$(TARGET_STRIP) --strip-debug \
			$(HAOS_SYSEXT_DIR)/$(2)/usr/lib/modules/$(LINUX_VERSION_PROBED)/updates/nvidia/$(m).ko$(sep))
	$(foreach l,$(call NVIDIA_DRIVER_LIBS,$($(1)_VERSION)), \
		$(call NVIDIA_DRIVER_INSTALL_LIB,$(l),$(HAOS_SYSEXT_DIR)/$(2))$(sep))
	ln -sf libcuda.so.1 $(HAOS_SYSEXT_DIR)/$(2)/usr/lib/libcuda.so
	ln -sf libnvidia-ml.so.1 $(HAOS_SYSEXT_DIR)/$(2)/usr/lib/libnvidia-ml.so
	$(foreach b,$(NVIDIA_DRIVER_BINS), \
		$(INSTALL) -D -m 0755 $(@D)/$(b) $(HAOS_SYSEXT_DIR)/$(2)/usr/bin/$(b)$(sep))
	$(INSTALL) -d $(HAOS_SYSEXT_DIR)/$(2)/usr/lib/firmware/nvidia/$($(1)_VERSION)
	$(INSTALL) -m 0644 $(@D)/firmware/*.bin \
		$(HAOS_SYSEXT_DIR)/$(2)/usr/lib/firmware/nvidia/$($(1)_VERSION)/
	# nvidia-cdi-hook runs the ldconfig of the host in the container to make
	# the injected driver libraries known. The root file system has none.
	$(INSTALL) -D -m 0755 $(GLIBC_DIR)/build/elf/ldconfig \
		$(HAOS_SYSEXT_DIR)/$(2)/usr/sbin/ldconfig
	$(TARGET_STRIP) $(HAOS_SYSEXT_DIR)/$(2)/usr/sbin/ldconfig
	$(INSTALL) -D -m 0755 $(NVIDIA_OPEN_DRIVER_PKGDIR)/haos-nvidia-setup \
		$(HAOS_SYSEXT_DIR)/$(2)/usr/libexec/haos-nvidia-setup
	$(INSTALL) -D -m 0644 $(@D)/LICENSE \
		$(HAOS_SYSEXT_DIR)/$(2)/usr/share/licenses/nvidia-driver/LICENSE
endef

$(eval $(kernel-module))
$(eval $(generic-package))
