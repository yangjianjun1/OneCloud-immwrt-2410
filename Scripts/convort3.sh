#!/bin/bash
set -e
#=================================================
# 玩客云 OpenWrt 固件 -> 标准 Amlogic 线刷包 + U盘启动镜像
# 输出：
#   1. xxx.img.xz  U盘启动镜像（dd/etcher写入U盘）
#   2. xxx.burn.img.xz  USB Burning Tool eMMC线刷包
#=================================================
echo "===== 开始打包【线刷包 + U盘启动镜像】 ====="
# 关键：确保在仓库根目录工作
cd $GITHUB_WORKSPACE
shopt -s nullglob

# 1. 安装依赖工具（加 -y 自动确认）
echo "[1/8] 安装依赖工具..."
sudo apt update
sudo apt install -y android-sdk-libsparse-utils xz-utils

# 2. 下载 AmlImg 打包工具
echo "[2/8] 下载 AmlImg 工具..."
ver="v0.3.2"
curl -L -o ./AmlImg https://github.com/rmoyulong/AmlImg/releases/download/$ver/AmlImg_${ver}_linux_amd64
chmod +x ./AmlImg

# 3. 下载玩客云专用 uboot（eMMC 线刷底包模板）
echo "[3/8] 下载玩客云 uboot 模板..."
curl -L -o ./uboot.img https://github.com/rmoyulong/u-boot-onecloud/releases/download/Onecloud_Uboot_23.12.24_18.15.09/eMMC.burn.img

# 4. 解压 uboot 模板，得到 burn/ 目录
echo "[4/8] 解压 uboot 模板..."
./AmlImg unpack ./uboot.img burn/

# 5. 解压 OpenWrt 固件并提取分区
echo "[5/8] 提取 OpenWrt 固件分区..."
gunzip openwrt/bin/targets/*/*/*.gz
diskimg=$(ls openwrt/bin/targets/*/*/*.img)
echo "OpenWrt U盘原始镜像: $diskimg"
loop=$(sudo losetup --find --show --partscan $diskimg)
echo "循环设备: $loop"

# 准备 rootfs 镜像
img_ext="openwrt.img"
img_mnt="xd"
rootfs_mnt="img"
sudo rm -rf ${img_ext} ${img_mnt} ${rootfs_mnt}
sudo dd if=/dev/zero of=${img_ext} bs=1M count=2000
# 加 -F 强制格式化，避免交互提示
sudo mkfs.ext4 -F ${img_ext}
sudo mkdir -p ${img_mnt} ${rootfs_mnt}
sudo mount ${img_ext} ${img_mnt}
sudo mount ${loop}p2 ${rootfs_mnt}

# 复制 rootfs 内容（关键：用 cp -a 且用 . 而不是 *，确保隐藏文件也复制）
cd ${rootfs_mnt}
sudo cp -a . ../${img_mnt}/
cd ..
sudo sync
sudo umount ${img_mnt}
sudo umount ${rootfs_mnt}

# 6. 转换为 sparse 格式并打包线刷包
echo "[6/8] 转换 sparse 格式并打包 burn.img 线刷包..."
sudo img2simg ${loop}p1 burn/boot.simg
sudo img2simg openwrt.img burn/rootfs.simg
sudo rm -f openwrt.img
sudo losetup -d $loop

# 添加分区配置
cat <<EOF > burn/commands.txt
PARTITION:boot:sparse:boot.simg
PARTITION:rootfs:sparse:rootfs.simg
EOF

# 打包成标准线刷包
img_base=$(basename "$diskimg" .img)
img_dir=$(dirname "$diskimg")
burnimg="${img_dir}/${img_base}.burn.img"
echo "输出线刷包: $burnimg"
./AmlImg pack "$burnimg" burn/

# ========== 新增：U盘镜像处理 ==========
echo "[7/8] 处理U盘启动镜像，生成 xz + sha256"
# 进入产物目录
cd "${img_dir}"
# U盘原始img压缩，保留原文件(-k)，生成xz和sha
for usb_raw_img in *.img; do
  # 跳过burn.img，只处理原生U盘raw镜像
  [[ "$usb_raw_img" == *.burn.img ]] && continue
  echo "压缩U盘镜像: $usb_raw_img"
  xz -9 --threads=0 -k "$usb_raw_img"
  sha256sum "${usb_raw_img}.xz" > "${usb_raw_img}.xz.sha"
done

# 线刷包压缩+sha
for f in *.burn.img; do
  sha256sum "$f" > "${f}.sha"
  xz -9 --threads=0 --compress "$f"
done

# ========== 清理：只删除gz，保留原始*.img用于U盘启动 ==========
sudo rm -f *.gz
# =========================================

echo "[8/8] 打包全部完成，列出产物："
ls -lh
echo "===== 线刷包 + U盘镜像打包完成 ====="
