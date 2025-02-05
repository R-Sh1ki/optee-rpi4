################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

UNAME_M 	:= $(shell uname -m)
ARCH		:= arm
ROOT		:= $(shell pwd)/..
BUILD_PATH	:= $(ROOT)/build

TF_A_PATH					?= $(ROOT)/trusted-firmware-a
TF_A_OUT					?= $(TF_A_PATH)/build/rpi4/debug
OPTEE_OS_PATH				?= $(ROOT)/optee_os
OPTEE_OS_BIN		    	?= $(OPTEE_OS_PATH)/out/$(ARCH)/core/tee.bin
OPTEE_OS_HEADER_V2_BIN	    ?= $(OPTEE_OS_PATH)/out/$(ARCH)/core/tee-header_v2.bin
OPTEE_OS_PAGER_V2_BIN	    ?= $(OPTEE_OS_PATH)/out/$(ARCH)/core/tee-pager_v2.bin
OPTEE_OS_PAGEABLE_V2_BIN    ?= $(OPTEE_OS_PATH)/out/$(ARCH)/core/tee-pageable_v2.bin

OUT_PATH	?= $(ROOT)/out

################################################################################
# set the compiler when COMPILE_xxx are defined
################################################################################
ifeq ($(ARCH),arm)
CROSS_COMPILE_NS_USER   ?= "$(CCACHE)$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL ?= "$(CCACHE)$(AARCH$(COMPILE_NS_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_NS_RUST	?= "$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_USER    ?= "$(CCACHE)$(AARCH$(COMPILE_S_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL  ?= "$(CCACHE)$(AARCH$(COMPILE_S_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_S_RUST	?= "$(AARCH$(COMPILE_S_USER)_CROSS_COMPILE)"
else ifeq ($(ARCH),riscv)
CROSS_COMPILE_NS_USER   ?= "$(CCACHE)$(RISCV$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL ?= "$(CCACHE)$(RISCV$(COMPILE_NS_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_S_USER    ?= "$(CCACHE)$(RISCV$(COMPILE_S_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL  ?= "$(CCACHE)$(RISCV$(COMPILE_S_KERNEL)_CROSS_COMPILE)"
endif


patch:
	@echo "Patching ARM Trusted Firmware (TF-A)..."
	@cd $(TF_A_PATH) && \
		patch -p1 < $(BUILD_PATH)/patches/arm-trusted-firmware.patch
	@echo "Patching OP-TEE OS..."
	@cd $(OPTEE_OS_PATH) && \
		patch -p1 < $(BUILD_PATH)/patches/optee-os.patch

################################################################################
# Targets
################################################################################
all: genfirmware 

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
	$(TF_A_EXPORTS) $(MAKE) -C $(TF_A_PATH) $(TF_A_FLAGS)

# ---------------------------------------------------------------------------- #
# OP-TEE OS                                                                    #
# ---------------------------------------------------------------------------- #
OPTEE_OS_COMMON_EXTRA_FLAGS ?= O=out/$(ARCH)

ifeq ($(ARCH), arm)
# CFG_USER_TA_TARGETS.
ifeq ($(COMPILE_S_USER), 32)
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_USER_TA_TARGETS=ta_arm32
endif
ifeq ($(COMPILE_S_USER), 64)
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_USER_TA_TARGETS=ta_arm64
endif

# CFG_ARM32_core.
ifeq ($(COMPILE_S_KERNEL), 64)
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_ARM64_core=y
else
OPTEE_OS_COMMON_EXTRA_FLAGS += CFG_ARM32_core=n
endif

OPTEE_OS_TA_CROSS_COMPILE_FLAGS	+= CROSS_COMPILE_ta_arm64="$(CCACHE)$(AARCH64_CROSS_COMPILE)"
OPTEE_OS_TA_CROSS_COMPILE_FLAGS	+= CROSS_COMPILE_ta_arm32="$(CCACHE)$(AARCH32_CROSS_COMPILE)"

else ifeq ($(ARCH),riscv)

ifeq ($(COMPILE_S_USER),32)
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_USER_TA_TARGETS=ta_rv32
endif
ifeq ($(COMPILE_S_USER),64)
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_USER_TA_TARGETS=ta_rv64
endif

ifeq ($(COMPILE_S_KERNEL),64)
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_RV64_core=y
else
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_RV64_core=n
endif

OPTEE_OS_TA_CROSS_COMPILE_FLAGS	+= CROSS_COMPILE_ta_rv64="$(CCACHE)$(RISCV64_CROSS_COMPILE)"
OPTEE_OS_TA_CROSS_COMPILE_FLAGS	+= CROSS_COMPILE_ta_rv32="$(CCACHE)$(RISCV32_CROSS_COMPILE)"
endif

OPTEE_OS_COMMON_FLAGS ?= \
	$(OPTEE_OS_COMMON_EXTRA_FLAGS) \
	PLATFORM=rpi4 \
	CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	CROSS_COMPILE_core=$(CROSS_COMPILE_S_KERNEL) \
	$(OPTEE_OS_TA_CROSS_COMPILE_FLAGS) \
	DEBUG=1 \
	CFG_DT=y

optee-os:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS)

genfirmware: tf-a optee-os
	@mkdir -p $(OUT_PATH)
	@cp $(TF_A_OUT)/bl31.bin $(OUT_PATH)/bl31-pad.tmp
	@truncate --size=128K $(OUT_PATH)/bl31-pad.tmp
	@cat $(OUT_PATH)/bl31-pad.tmp $(OPTEE_OS_PAGER_V2_BIN) > $(OUT_PATH)/bl31-bl32.bin