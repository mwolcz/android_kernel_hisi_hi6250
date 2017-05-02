#Android makefile to build kernel as a part of Android Build
PERL		= perl

ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/arm64/boot/zImage
KERNEL_IMG=$(KERNEL_OUT)/arch/arm64/boot/Image

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed kernel)
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/piggy
else
TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)
endif

COMMON_HEAD := $(shell pwd)/kernel/drivers/
COMMON_HEAD += $(shell pwd)/kernel/mm/
COMMON_HEAD += $(shell pwd)/kernel/include/hisi/
COMMON_HEAD += $(shell pwd)/external/efipartition	
COMMON_HEAD += $(shell pwd)/drivers/vendor/hisi/ap/platform/hi6250/

ifneq ($(COMMON_HEAD),)
BALONG_INC := $(patsubst %,-I%,$(COMMON_HEAD))
else
BALONG_INC :=
endif

ifeq ($(CFG_CONFIG_HISI_FAMA),true)
BALONG_INC  += -DCONFIG_HISI_FAMA
endif

export BALONG_INC

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

ifeq ($(strip $(llt_gcov)),y)
HISI_MDRV_GCOV_DEFCONFIG := ${KERNEL_ARCH_ARM_CONFIGS}/gcov_defconfig
APPEND_MODEM_GCOV_DEFCONFIG := cat $(HISI_MDRV_GCOV_DEFCONFIG) >> $(KERNEL_GEN_CONFIG_PATH)
endif

idl_tool_script_path := $(shell pwd)/kernel/scripts/kernel_modem_idl_tool.py
driver_hisi_modem_out_dir := $(shell pwd)/$(KERNEL_OUT)/drivers/hisi/modem
kernel_driver_hisi_dir := $(shell pwd)/kernel/drivers/hisi

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- $(KERNEL_DEFCONFIG)

$(KERNEL_OUT)/piggy : $(TARGET_PREBUILT_INT_KERNEL)
	$(hide) gunzip -c $(KERNEL_OUT)/arch/arm/boot/compressed/piggy.gzip > $(KERNEL_OUT)/piggy

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_CONFIG) $(KERNEL_HEADERS_INSTALL)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm64 CROSS_COMPILE=aarch64-linux-android-

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- headers_install

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- savedefconfig
	cp $(KERNEL_OUT)/defconfig kernel/arch/arm64/configs/$(KERNEL_DEFCONFIG)

endif
