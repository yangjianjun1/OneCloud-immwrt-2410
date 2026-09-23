#!/bin/bash
set -e
#=================================================
# 玩客云 OpenWrt 固件 -> 标准 Amlogic 线刷包 转换脚本
# 【AB分区：线刷仅烧写boot+rootfsa+data，rootfsb为OTA升级分区不烧写】
# 分区偏移：
# boot: start 16M , size 256M
# rootfsa: start 272M, size 600M
# rootfsb: start 872M, size 600M（线刷不写入，升级专用）
# data: start 1472M, size=0(剩余全部)
# 输出：.burn.img（USB Burning Tool 可直接线刷）
#=================================================
echo "===== 开始打包标准 Amlogic 线刷包（仅烧写rootfsa，rootfsb保留作升级分区） ====="
cd "$GITHUB_WORKSPACE"
echo "[1/7] 安装依赖工具..."
sudo apt update
sudo apt install -y android-sdk-libsparse-utils xz-utils
echo "[2/7] 下载 AmlImg 工具..."
ver="v0.3.2"
curl -L -o ./AmlImg https://github.com/rmoyulong/AmlImg/releases/download/$ver/AmlImg_${ver}_linux_amd64
chmod +x ./AmlImg
echo "[3/7] 下载玩客云 uboot 模板..."
curl -L -o ./uboot.img https://github.com/rmoyulong/u-boot-onecloud/releases/download/Onecloud_Uboot_23.12.24_18.15.09/eMMC.burn.img
echo "[4/7] 解压 uboot 模板..."
rm -rf burn
./AmlImg unpack ./uboot.img burn/
rm -f burn/*.simg
echo "[5/7] 提取 OpenWrt 固件分区..."
# 只在targets下3层深度搜索，筛选ext4-emmc镜像
diskimg=$(find openwrt/bin/targets -maxdepth 3 -name "*ext4-emmc.img" | head -n1)
echo "OpenWrt 镜像: $diskimg"
if [ -z "$diskimg" ];then
echo "ERROR: 找不到openwrt ext4-emmc img!"
exit 1
fi
loop=$(sudo losetup --find --show --partscan "$diskimg")
echo "循环设备: $loop"
cleanup(){
if [ -n "$loop" ] && [ -b "$loop" ];then
sudo losetup -d "$loop" || true
fi
}
trap cleanup EXIT
# --------------------------
# 分区映射
# ${loop}p1 → boot
# ${loop}p2 → rootfsa
# ${loop}p4 → data
# p3 rootfsb 不导出、不烧录，留作OTA升级分区
# --------------------------
echo "[6/7] 转换 sparse 格式并打包..."
sudo img2simg "${loop}p1" burn/boot.simg
sudo img2simg "${loop}p2" burn/rootfsa.simg
sudo img2simg "${loop}p4" burn/data.simg

# 稳定printf写入commands.txt
printf "PARTITION:boot:sparse:boot.simg:16M:256M\nPARTITION:rootfsa:sparse:rootfsa.simg:272M:600M\nPARTITION:data:sparse:data.simg:1472M:0\n" > burn/commands.txt

# ===== 新增排错打印，查看commands.txt内容 =====
echo "===== commands.txt 内容预览 ====="
cat burn/commands.txt
echo "================================="

prefix="${diskimg%.img}"
burnimg="${prefix}.burn.img"
echo "输出线刷包: $burnimg"
./AmlImg pack "$burnimg" burn/
echo "[7/7] 压缩并生成校验文件..."
burn_dir=$(dirname "$burnimg")
cd "$burn_dir"
for f in *.burn.img; do
sha256sum "$f" > "${f}.sha"
xz -9 --threads=0 --compress "$f"
done
# 可选：注释下面这行，保留原始openwrt img
#sudo rm -f *.img
#sudo rm -f *.gz
echo "===== 线刷包打包完成（rootfsb不烧写，用于升级） ====="
ls -lh
echo "=========================="
