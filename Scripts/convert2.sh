#!/bin/bash
set -e
#=================================================
# 玩客云(OneCloud / S905X3, meson8b) OpenWrt -> Amlogic 线刷包 转换脚本
#
# 【分区事实（来自 target/linux/amlogic/image/gen_aml_emmc_img.sh 的 ptgen）】
#   openwrt.img 是整盘镜像，扇区0 为 MBR(msdos) 分区表，只切 2 个主分区：
#     p1 = boot   类型0c(FAT32)  16M  -> uImage + dtb + boot.scr
#     p2 = rootfs 类型83(ext4)   600M -> 首启自动扩容填满 eMMC
#   没有 rootfsb、没有独立 data 分区（之前注释里的"AB四分区"与实际产物不符，已更正）。
#
# 【两种产物】
#   openwrt.img.xz   : 整盘镜像，含 MBR+p1+p2，晶晨宝盒网页升级用。空白/已清空 eMMC 刷它。
#   openwrt.burn.img.xz: USB Burning Tool 线刷包。只写 bootloader(模板保留)+boot+rootfsa。
#                       线刷包内【不含 MBR】，假定 eMMC 已有分区表，用于日常更新系统。
#                       全新空盘请先刷一次 openwrt.img.xz 把 MBR 建出来。
#=================================================
echo "===== 开始打包标准 Amlogic 线刷包 ====="
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

echo "----- openwrt.img 的 MBR 分区表（自检，应为 p1=boot / p2=rootfs） -----"
sudo fdisk -l "$loop" || true
echo "-------------------------------------------------------------------"
[ -b "${loop}p1" ] || { echo "ERROR: 找不到 ${loop}p1 (boot)，分区表不是预期结构"; exit 1; }
[ -b "${loop}p2" ] || { echo "ERROR: 找不到 ${loop}p2 (rootfs)，分区表不是预期结构"; exit 1; }

cleanup(){
if [ -n "$loop" ] && [ -b "$loop" ];then
sudo losetup -d "$loop" || true
fi
}
trap cleanup EXIT
echo "[6/8] 转换 sparse 格式并打包线刷包..."
sudo img2simg "${loop}p1" burn/boot.simg
sudo img2simg "${loop}p2" burn/rootfsa.simg

# ------------------------------------------------------------------
# AmlImg v0.3.2 的 commands.txt 格式（前端 pack() 用 SplitN(":",4)）：
#   TYPE:NAME:IMGTYPE:FILENAME
#   - 仅 4 段；没有 offset/size 字段（偏移由 u-boot/烧录工具按分区名决定）
#   - IMGTYPE 只接受 normal / sparse，其它（如 raw）报 unknown imgType
#   - 每个条目都要指向真实文件，不支持空占位分区
# 解包模板已生成完整 commands.txt（DDR/UBOOT_COMP/ini/conf/bootloader/resource），
# 这里只【追加】OpenWrt 的 boot + rootfsa，绝不能用 > 覆盖。
# 线刷包不写 MBR；rootfs(=rootfsa) 只刷当前系统分区，不单独建 data。
# ------------------------------------------------------------------
printf "PARTITION:boot:sparse:boot.simg\nPARTITION:rootfsa:sparse:rootfsa.simg\n" >> burn/commands.txt

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
echo "  openwrt.img.xz            → 晶晨宝盒整盘升级包（含 MBR，空白 eMMC 刷它）"
echo "  *.burn.img.xz             → USB Burning Tool 线刷包（仅 boot+rootfsa，日常更新用）"
echo "  *.sha                     → sha256校验文件"
