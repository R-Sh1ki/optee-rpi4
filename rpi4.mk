################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

ROOT		?= $(shell pwd)/..
BUILD_PATH	?= $(ROOT)/build

TF_A_PATH	?= $(ROOT)/trusted-firmware-a
TF_A_OUT	?= $(TF_A_PATH)/build/rpi4/debug

################################################################################
# Targets
################################################################################
all: tf-a 

include toolchain.mk

# ---------------------------------------------------------------------------- #
# ARM Trusted Firmware (TF-A)                                                  #
# ---------------------------------------------------------------------------- #
TF_A_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

TF_A_FLAGS ?= \
	PLAT=rpi4 \
	SPD=opteed \
	DEBUG=1 \
	V=0

tf-a:
	@cd $(TF_A_PATH)
	@patch -p1 < $(BUILD_PATH)/patches/arm-trusted-firmware.patch
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS)