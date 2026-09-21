#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Amlogic A/B EMMC image generator
set -x
[ $# -eq 6 ] || {
    echo "SYNTAX: $0 <file> <bootfs image> <rootA image> <bootfs size> <rootA size> <rootB size>"
    exit 1
}
OUTPUT="$1"
BOOTFS="$2"
ROOTFS_A="$3"
BOOTFSSIZE="$4"
ROOTFSSIZE_A="$5"
ROOTFSSIZE_B="$6"

head=4
sect=2048

# p1 boot @32768扇区 = 16MB偏移，大小BOOTFSSIZE M
# p2 rootA ROOTFSSIZE_A M
# p3 rootB ROOTFSSIZE_B M
# p4 upgrade：使用镜像剩余全部空间 -p 0
set $(ptgen -o $OUTPUT -h $head -s $sect -l 4096 \
-t c -p @32768:${BOOTFSSIZE}M \
-t 83 -p ${ROOTFSSIZE_A}M \
-t 83 -p ${ROOTFSSIZE_B}M \
-t 83 -p 0 )

BOOTOFFSET="$(( $1 / 512 ))"
BOOTSIZE="$(( $2 / 512 ))"
ROOTA_OFFSET="$(( $3 / 512 ))"
ROOTA_SIZE="$(( $4 / 512 ))"
ROOTB_OFFSET="$(( $5 / 512 ))"
ROOTB_SIZE="$(( $6 / 512 ))"
UPG_OFFSET="$(( $7 / 512 ))"
UPG_SIZE="$(( $8 / 512 ))"

# 写入boot分区
dd if="$BOOTFS" of="$OUTPUT" bs=512 seek="$BOOTOFFSET" conv=notrunc
# 写入rootA
dd if="$ROOTFS_A" of="$OUTPUT" bs=512 seek="$ROOTA_OFFSET" conv=notrunc

# 生成并写入upgrade分区
TMP_UPG=$(mktemp)
dd if=/dev/zero of="$TMP_UPG" bs=512 count="$UPG_SIZE"
mkfs.ext4 "$TMP_UPG"
dd if="$TMP_UPG" of="$OUTPUT" bs=512 seek="$UPG_OFFSET" conv=notrunc
rm -f "$TMP_UPG"

# 生成空白rootB分区（ext4）
TMP_ROOTB=$(mktemp)
dd if=/dev/zero of="$TMP_ROOTB" bs=512 count="$ROOTB_SIZE"
mkfs.ext4 "$TMP_ROOTB"
dd if="$TMP_ROOTB" of="$OUTPUT" bs=512 seek="$ROOTB_OFFSET" conv=notrunc
rm -f "$TMP_ROOTB"

sync
echo "==== Image build done ===="
echo "p1: FAT32 ${BOOTFSSIZE}M, start@16MB"
echo "p2: rootA ${ROOTFSSIZE_A}M ext4"
echo "p3: rootB ${ROOTFSSIZE_B}M ext4"
echo "p4: upgrade, all remaining space"
