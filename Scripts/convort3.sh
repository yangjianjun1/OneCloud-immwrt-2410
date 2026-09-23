#!/bin/bash
set -e

#=================================================
# 玩客云 OpenWrt 固件 -> 标准 Amlogic 线刷包 转换脚本
# 【4分区AB版本：boot@16M size256M，rootfsa=600M，rootfsb=600M，data剩余全部】
# 分区偏移：
# boot: start 16M , size 256M
# rootfsa: start 272M, size 600M
# rootfsb: start 872M, size 600M
# data: start 1472M, size=0(剩余全部)
# 输出：.burn.img（USB Burning Tool 可直接线刷）
#=================================================

echo "===== 开始打包标准 Amlogic 4分区AB线刷包 ====="

# 关键：确保在仓库根目录工作
cd "$GITHUB_WORKSPACE"

# 1. 安装依赖工具（加 -y 自动确认）
echo "[1/7] 安装依赖工具..."
sudo apt update
sudo apt install -y android-sdk-libsparse-utils xz-utils

# 2. 下载 AmlImg 打包工具
echo "[2/7] 下载 AmlImg 工具..."
ver="v0.3.2"
curl -L -o ./AmlImg https://github.com/rmoyulong/AmlImg/releases/download/$ver/AmlImg_${ver}_linux_amd64
chmod +x ./AmlImg

# 3. 下载玩客云专用 uboot（eMMC 线刷底包模板）
echo "[3/7] 下载玩客云 uboot 模板..."
curl -L -o ./uboot.img https://github.com/rmoyulong/u-boot-onecloud/releases/download/Onecloud_Uboot_23.12.24_18.15.09/eMMC.burn.img

# 4. 解压 uboot 模板，得到 burn/ 目录，清理旧simg
echo "[4/7] 解压 uboot 模板..."
rm -rf burn
./AmlImg unpack ./uboot.img burn/
# 清空旧分区镜像，防止残留
rm -f burn/*.simg

# 5. 解压 OpenWrt 固件并提取分区
echo "[5/7] 提取 OpenWrt 固件分区..."
# 解压gz，已存在则跳过，不报错
find openwrt/bin/targets -maxdepth 2 -name "*.gz" -exec gunzip -k {} \;

# 只取1个raw镜像，避免多文件问题
diskimg=$(find openwrt/bin/targets -maxdepth 2 -name "*.img" | head -n1)
echo "OpenWrt 镜像: $diskimg"
if [ -z "$diskimg" ];then
  echo "ERROR: 找不到openwrt raw img!"
  exit 1
fi

loop=$(sudo losetup --find --show --partscan "$diskimg")
echo "循环设备: $loop"

# 异常捕获：脚本退出时自动释放loop
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
# ${loop}p3 → rootfsb
# ${loop}p4 → data
# --------------------------

# 6. 转换4个分区为 sparse 格式
echo "[6/7] 转换 sparse 格式并打包4分区..."
sudo img2simg "${loop}p1" burn/boot.simg
sudo img2simg "${loop}p2" burn/rootfsa.simg
sudo img2simg "${loop}p3" burn/rootfsb.simg
sudo img2simg "${loop}p4" burn/data.simg

# 写入【带偏移+大小】分区烧录配置，覆盖原有文件
cat <<EOF > burn/commands.txt
PARTITION:boot:sparse:boot.simg:16M:256M
PARTITION:rootfsa:sparse:rootfsa.simg:272M:600M
PARTITION:rootfsb:sparse:rootfsb.simg:872M:600M
PARTITION:data:sparse:data.simg:1472M:0
EOF

# 打包成标准线刷包
prefix="${diskimg%.img}"
burnimg="${prefix}.burn.img"
echo "输出线刷包: $burnimg"
./AmlImg pack "$burnimg" burn/

# 7. 压缩并生成校验
echo "[7/7] 压缩并生成校验文件..."
burn_dir=$(dirname "$burnimg")
cd "$burn_dir"
for f in *.burn.img; do
  sha256sum "$f" > "${f}.sha"
  xz -9 --threads=0 --compress "$f"
done

# 删除原始 raw 镜像
sudo rm -f *.img
sudo rm -f *.gz

echo "===== 4分区AB线刷包打包完成 ====="
ls -lh
echo "=========================="
