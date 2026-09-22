#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

FAT32_BLOCK_SIZE=1024

# ===== boot 分区（MB，给 ptgen / mkfs.fat 用）=====
# .config 里写 CONFIG_TARGET_BOOTFS_PARTSIZE=256（单位 MB）
BOOTFS_PARTSIZE:=$(shell grep '^CONFIG_TARGET_BOOTFS_PARTSIZE=' $(TOPDIR)/.config | cut -d= -f2)
# 防御：grep 不到时兜底 256，避免算术空值崩溃
ifeq ($(BOOTFS_PARTSIZE),)
BOOTFS_PARTSIZE:=256
endif

# ===== rootfs 分区（智能判断：.config 写 MB 或字节都兼容）=====
# 自动识别：值 > 1048576（1MB的字节数）认为是字节，直接用；否则认为是 MB，×1024×1024 换算
# 这样 .config 里写 600 或 629145600 都不会出错，彻底避免 600TB 重复换算问题
ROOTFS_PARTSIZE_RAW:=$(shell grep '^CONFIG_TARGET_ROOTFS_PARTSIZE=' $(TOPDIR)/.config | cut -d= -f2)
# 防御：grep 不到时兜底 600（MB）
ifeq ($(ROOTFS_PARTSIZE_RAW),)
ROOTFS_PARTSIZE_RAW:=600
endif
ROOTFS_PARTSIZE_BYTES:=$(shell if [ $(ROOTFS_PARTSIZE_RAW) -gt 1048576 ]; then echo $(ROOTFS_PARTSIZE_RAW); else echo $$(($(ROOTFS_PARTSIZE_RAW)*1024*1024)); fi)
ROOTFS_PARTSIZE_MB:=$(shell echo $$(($(ROOTFS_PARTSIZE_BYTES)/1024/1024)))
# override 给 make_ext4fs（字节）
override CONFIG_TARGET_ROOTFS_PARTSIZE:=$(ROOTFS_PARTSIZE_BYTES)
override TARGET_ROOTFS_PARTSIZE:=$(ROOTFS_PARTSIZE_BYTES)

# FAT32 块数（立即展开，只算一次）
FAT32_BLOCKS:=$(shell echo $$(($(BOOTFS_PARTSIZE)*1024*1024/$(FAT32_BLOCK_SIZE))))

define Build/boot-script
	# Make an U-boot image and copy it to the boot partition
	mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "boot.scr" -d boot.txt  $(KDIR)/boot.scr
endef

define Build/emmc-common
	$(RM) -f $@.boot
	mkfs.fat -C $@.boot $(FAT32_BLOCKS)
	mkdir -p $(KDIR)/boot.fat
	$(CP) $(KDIR)/boot.scr $(KDIR)/boot.fat/boot.scr
	mcopy -i $@.boot $(KDIR)/boot.scr ::
	$(CP) $(IMAGE_KERNEL) $(KDIR)/boot.fat/uImage
	mcopy -i $@.boot $(KDIR)/boot.fat/uImage ::
	$(foreach dts,$(shell echo $(DEVICE_DTS)),$(CP) $(DTS_DIR)/$(dts).dtb $(KDIR)/boot.fat/dtb;)
	mcopy -i $@.boot $(KDIR)/boot.fat/dtb ::
	$(RM) -rf $(KDIR)/boot.fat
	# 参数顺序：emmc.img boot镜像 rootfs BOOTFS大小 rootA大小 rootB大小
	./gen_aml_emmc_img.sh $@ $@.boot $(IMAGE_ROOTFS) \
		$(BOOTFS_PARTSIZE) $(ROOTFS_PARTSIZE_MB) $(ROOTFS_PARTSIZE_MB)
endef

### Devices ###
define Device/Default
  FILESYSTEMS := ext4
  IMAGES := emmc.img
  KERNEL_DEPENDS = $$(wildcard $(DTS_DIR)/$$(DEVICE_DTS).dts)
  KERNEL_LOADADDR := 0x01080000
  KERNEL_NAME := Image
  KERNEL := kernel-bin | uImage none
  PROFILES = Default $$(DEVICE_NAME)
endef

define Device/thunder-onecloud
  DEVICE_DTS := amlogic/meson8b-onecloud
  DEVICE_TITLE := Thunder OneCloud
  KERNEL_LOADADDR := 0x00208000
  IMAGE/emmc.img := boot-script onecloud | emmc-common $$(DEVICE_NAME)
endef

ifeq ($(SUBTARGET),meson8b)
  TARGET_DEVICES += thunder-onecloud
endif

$(eval $(call BuildImage))
