################################################################################
#
# NVIDIA Container Toolkit (nvidia-ctk, nvidia-cdi-hook)
#
################################################################################

NVIDIA_CONTAINER_TOOLKIT_VERSION = 1.20.1
NVIDIA_CONTAINER_TOOLKIT_SITE = $(call github,NVIDIA,nvidia-container-toolkit,v$(NVIDIA_CONTAINER_TOOLKIT_VERSION))
NVIDIA_CONTAINER_TOOLKIT_LICENSE = Apache-2.0
NVIDIA_CONTAINER_TOOLKIT_LICENSE_FILES = LICENSE
NVIDIA_CONTAINER_TOOLKIT_GOMOD = github.com/NVIDIA/nvidia-container-toolkit

NVIDIA_CONTAINER_TOOLKIT_BUILD_TARGETS = cmd/nvidia-ctk cmd/nvidia-cdi-hook

# NVML is loaded with dlopen() at runtime, see the upstream Makefile.
NVIDIA_CONTAINER_TOOLKIT_LDFLAGS = \
	-X $(NVIDIA_CONTAINER_TOOLKIT_GOMOD)/internal/info.version=$(NVIDIA_CONTAINER_TOOLKIT_VERSION) \
	-extldflags '-Wl,--export-dynamic -Wl,--unresolved-symbols=ignore-in-object-files -Wl,-z,lazy'

# Only used inside the "nvidia" system extension, see nvidia-open-driver.
NVIDIA_CONTAINER_TOOLKIT_INSTALL_TARGET = NO
NVIDIA_CONTAINER_TOOLKIT_INSTALL_IMAGES = YES

define NVIDIA_CONTAINER_TOOLKIT_INSTALL_IMAGES_CMDS
	$(foreach b,$(notdir $(NVIDIA_CONTAINER_TOOLKIT_BUILD_TARGETS)), \
		$(INSTALL) -D -m 0755 $(@D)/bin/$(b) $(HAOS_SYSEXT_DIR)/nvidia/usr/bin/$(b)$(sep) \
		$(TARGET_STRIP) $(HAOS_SYSEXT_DIR)/nvidia/usr/bin/$(b)$(sep))
endef

$(eval $(golang-package))
