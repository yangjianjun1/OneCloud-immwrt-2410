#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2017 OpenWrt.org
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
UPGRADE_SIZE="512"
head=4
sect=2048
# -t c = 0x0C LBA FAT32
# p1 boot分区：@32768扇区 = 16MB偏移开始，大小256M
set $(ptgen -o $OUTPUT -h $head -s $sect -l 4096 \
-t c -p @32768:${BOOTFSSIZE}M \
-t 83 -p ${ROOTFSSIZE_A}M \
-t 83 -p ${ROOTFSSIZE_B}M \
-t 83 -p ${UPGRADE_SIZE}M )
# ptgen输出：p1off p1sz p2off p2sz p3off p3sz p4off p4sz
BOOTOFFSET="$(($1 / 512))"
BOOTSIZE="$(($2 / 512))"
ROOTA_OFFSET="$(($3 / 512))"
ROOTA_SIZE="$(($4 / 512))"
ROOTB_OFFSET="$(($5 / 512))"
ROOTB_SIZE="$(($6 / 512))"
UPG_OFFSET="$(($7 / 512))"
UPG_SIZE="$(($8 / 512))"
dd bs=512 if="$BOOTFS" of="$OUTPUT" seek="$BOOTOFFSET" conv=notrunc
dd bs=512 if="$ROOTFS_A" of="$OUTPUT" seek="$ROOTA_OFFSET" conv=notrunc
# 创建空白rootB
TMP_ROOTB=$(mktemp)
dd if=/dev/zero of="$TMP_ROOTB" bs=512 count="${ROOTB_SIZE}"
mkfs.ext4 "$TMP_ROOTB"
dd bs=512 if="$TMP_ROOTB" of="$OUTPUT" seek="$ROOTB_OFFSET" conv=notrunc
rm -f "$TMP_ROOTB"
# 创建空白upgrade分区
TMP_UPG=$(mktemp)
dd if=/dev/zero of="$TMP_UPG" bs=512 count="${UPG_SIZE}"
mkfs.ext4 "$TMP_UPG"
dd bs=512 if="$TMP_UPG" of="$OUTPUT" seek="$UPG_OFFSET" conv=notrunc
rm -f "$TMP_UPG"
sync
echo "Done: p1(FAT32 ${BOOTFSSIZE}M start@16MB), p2(rootA ${ROOTFSSIZE_A}M), p3(rootB ${ROOTFSSIZE_B}M), p4(upgrade ${UPGRADE_SIZE}M)"
