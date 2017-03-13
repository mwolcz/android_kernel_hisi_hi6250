#Android makefile to build kernel as a part of Android Build

KERNEL_OUT := vendor/hisi/build/delivery/$(OBB_PRODUCT_NAME)/obj/android
KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config

COMMON_HEAD := $(shell pwd)/kernel/drivers/
COMMON_HEAD += $(shell pwd)/kernel/mm/
COMMON_HEAD += $(shell pwd)/kernel/include/hisi/
COMMON_HEAD += $(shell pwd)/external/efipartition	
COMMON_HEAD += $(shell pwd)/vendor/hisi/ap/platform/hi6250/

ifneq ($(COMMON_HEAD),)
BALONG_INC := $(patsubst %,-I%,$(COMMON_HEAD))
else
BALONG_INC :=
endif

ifeq ($(CFG_CONFIG_HISI_FAMA),true)
BALONG_INC  += -DCONFIG_HISI_FAMA
endif

export BALONG_INC

KERNEL_N_TARGET ?= vmlinux
UT_EXTRA_CONFIG ?=

KERNEL_GEN_CONFIG_FILE := hw_hi6250_defconfig
KERNEL_GEN_CONFIG_PATH := $(KERNEL_ARCH_ARM_CONFIGS)/$(KERNEL_GEN_CONFIG_FILE)

KERNEL_COMMON_DEFCONFIG := $(KERNEL_ARCH_ARM_CONFIGS)/$(KERNEL_DEFCONFIG)
KERNEL_DEBUG_CONFIGS := $(KERNEL_ARCH_ARM_CONFIGS)/eng_defconfig/$(TARGET_BOARD_PLATFORM)

ifneq ($(filter hi3650 hi3650emulator, $(TARGET_BOARD_PLATFORM)),)
ifeq ($(strip $(CFG_HISI_MINI_AP)), false)
	APPEND_MODEM_DEFCONFIG := cat $(HISI_3650_MODEM_DEFCONFIG) >> $(KERNEL_GEN_CONFIG_PATH)
endif
endif

ifneq ($(filter hi6250, $(TARGET_BOARD_PLATFORM)),)
ifeq ($(strip $(CFG_HISI_MINI_AP)), false)
	APPEND_MODEM_DEFCONFIG := cat $(HISI_6250_MODEM_DEFCONFIG) >> $(KERNEL_GEN_CONFIG_PATH)
endif
endif

ifneq ($(filter hi3660, $(TARGET_BOARD_PLATFORM)),)
ifeq ($(strip $(CFG_HISI_MINI_AP)), false)
	APPEND_MODEM_DEFCONFIG := cat $(HISI_3660_MODEM_DEFCONFIG) >> $(KERNEL_GEN_CONFIG_PATH)
endif
endif

KERNEL_DEBUG_CONFIGFILE := $(KERNEL_COMMON_DEFCONFIG)
KERNEL_TOBECLEAN_CONFIGFILE :=

ifeq ($(strip $(llt_gcov)),y)
HISI_MDRV_GCOV_DEFCONFIG := ${KERNEL_ARCH_ARM_CONFIGS}/gcov_defconfig
APPEND_MODEM_GCOV_DEFCONFIG := cat $(HISI_MDRV_GCOV_DEFCONFIG) >> $(KERNEL_GEN_CONFIG_PATH)
endif

idl_tool_script_path := $(shell pwd)/kernel/scripts/kernel_modem_idl_tool.py
driver_hisi_modem_out_dir := $(shell pwd)/$(KERNEL_OUT)/drivers/hisi/modem
kernel_driver_hisi_dir := $(shell pwd)/kernel/drivers/hisi

$(TARGET_PREBUILT_KERNEL): FORCE $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE)
