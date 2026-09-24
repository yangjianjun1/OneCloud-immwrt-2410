#!/bin/bash
set -e
#=================================================
# 玩客云 OpenWrt 固件 -> 标准 Amlogic 线刷包 转换脚本
# 【AB分区：线刷仅烧写boot+rootfsa+data，rootfsb为OTA升级分区不烧写】
#=================================================
echo "===== 开始打包标准 Amlogic 线刷包（仅烧写rootfsa，rootfsb保留作升级分区） ====="
cd "$GITHUB_WORKSPACE"
echo "[1/8] 安装依赖工具..."
sudo apt update
sudo apt install -y android-sdk-libsparse-utils xz-utils
echo "[2/8] 下载 AmlImg 工具..."
ver="v0.3.2"
curl -L -o ./AmlImg https://github.com/rmoyulong/AmlImg/releases/download/$ver/AmlImg_${ver}_linux_amd64
chmod +x ./AmlImg
echo "[3/8] 下载玩客云 uboot 模板..."
curl -L -o ./uboot.img https://github.com/rmoyulong/u-boot-onecloud/releases/download/Onecloud_Uboot_23.12.24_18.15.09/eMMC.burn.img
echo "[4/8] 解压 uboot 模板..."
rm -rf burn
./AmlImg unpack ./uboot.img burn/
rm -f burn/*.simg
echo "[5/8] 提取 OpenWrt 固件分区..."
IMG_GZ=$(find -L openwrt/bin/targets -maxdepth 3 -name "*.img.gz" | head -n1)
echo "IMG_GZ: ${IMG_GZ}"
if [ -n "${IMG_GZ}" ]; then
  echo "✅ 找到gzip压缩固件: ${IMG_GZ}"
  gunzip -k "${IMG_GZ}"
  RAW_IMG="${IMG_GZ%.gz}"
  mv "${RAW_IMG}" openwrt.img
  diskimg="openwrt.img"
  echo "✅ 解压并重命名为 openwrt.img"
else
  echo "ℹ️ 未找到img.gz，尝试查找裸img"
  RAW_IMG=$(find -L openwrt/bin/targets -maxdepth 3 -name "*.img" | head -n1)
  if [ -n "${RAW_IMG}" ]; then
    mv "${RAW_IMG}" openwrt.img
    diskimg="openwrt.img"
  else
    echo "ERROR: 找不到openwrt img.gz / img!"
    exit 1
  fi
fi
echo "OpenWrt raw镜像: $diskimg"
echo "===== 生成晶晨宝盒 img.xz 升级包 ====="
xz -9 --threads=0 -k "${diskimg}"
sha256sum "${diskimg}.xz" > "${diskimg}.xz.sha"
echo "晶晨宝盒升级包: ${diskimg}.xz"
loop=$(sudo losetup --find --show --partscan "$diskimg")
echo "循环设备: $loop"
cleanup(){
if [ -n "$loop" ] && [ -b "$loop" ];then
sudo losetup -d "$loop" || true
fi
}
trap cleanup EXIT
echo "[6/8] 转换 sparse 格式并打包线刷包..."
sudo img2simg "${loop}p1" burn/boot.simg
sudo img2simg "${loop}p2" burn/rootfsa.simg
printf "PARTITION:boot:sparse:boot.simg:16M:256M\nPARTITION:rootfsa:sparse:rootfsa.simg:272M:600M\nPARTITION:data:raw::1472M:0\n" > burn/commands.txt
echo "===== commands.txt 内容预览 ====="
cat burn/commands.txt
echo "================================="
prefix="${diskimg%.img}"
burnimg="${prefix}.burn.img"
echo "输出线刷包: $burnimg"
echo "burn目录内容:"
ls -la burn/
echo "执行打包命令: ./AmlImg pack $burnimg burn/"
# ===== 关键：AmlImg pack 输出文件在前，源目录在后 =====
./AmlImg pack "$burnimg" burn/
echo "[7/8] 压缩线刷包并生成校验文件..."
burn_dir=$(dirname "$burnimg")
cd "$burn_dir"
for f in *.burn.img; do
sha256sum "$f" > "${f}.sha"
xz -9 --threads=0 -k "$f"
done
echo "[8/8] 打包完成，列出全部产物："
ls -lh
echo "===== 线刷包打包完成 ====="
echo "产物说明："
echo "  openwrt.img.xz            → 晶晨宝盒网页手动上传升级包"
echo "  *.burn.img.xz             → USB Burning Tool 线刷包"
echo "  *.sha                     → sha256校验文件"
