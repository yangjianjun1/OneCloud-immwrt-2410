#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

# boot分区256M FAT16
FAT_BLOCK_SIZE=1024
FAT_BLOCKS=$(shell echo $$((256*1024*1024/$(FAT_BLOCK_SIZE))))

define Build/boot-script
	mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "boot.scr" -d boot.txt  $(KDIR)/boot.scr
endef

define Build/emmc-common
	$(RM) -f $@.boot
	mkfs.fat -F16 -C $@.boot $(FAT_BLOCKS)
	mkdir -p $(KDIR)/boot.fat
	$(CP) $(KDIR)/boot.scr $(KDIR)/boot.fat/boot.scr
	mcopy -i $@.boot $(KDIR)/boot.scr ::
	$(CP) $(IMAGE_KERNEL) $(KDIR)/boot.fat/uImage
	mcopy -i $@.boot $(KDIR)/boot.fat/uImage ::
	$(foreach dts,$(shell echo $(DEVICE_DTS)),$(CP) $(DTS_DIR)/$(dts).dtb $(KDIR)/boot.fat/dtb;)
	mcopy -i $@.boot $(KDIR)/boot.fat/dtb ::
	$(RM) -rf $(KDIR)/boot.fat
	# 参数：img bootfs rootA bootSz rootA-sz rootB-sz
	./gen_aml_emmc_img.sh $@ $@.boot $(IMAGE_ROOTFS) 256 960 960
endef

define Device/Default
  FILESYSTEMS := ext4
  IMAGES := emmc.img
  KERNEL_DEPENDS = $$(wildcard $(DTS_DIR)/$$(DEVICE_DTS).dts)
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

# 自动赋予脚本可执行权限
$(shell chmod +x target/linux/meson8b/image/gen_aml_emmc_img.sh)

$(eval $(call BuildImage))
