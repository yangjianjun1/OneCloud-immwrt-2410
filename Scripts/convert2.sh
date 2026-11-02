#!/bin/bash
set -euo pipefail

echo "::group::Build eMMC Burn image"

# 安装依赖
sudo apt update -y
sudo apt install -y android-sdk-libsparse-utils xz-utils

# AmlImg版本
ver="v0.3.1"
curl --retry 3 -L -o ./AmlImg "https://github.com/lxiaya/AmlImg/releases/download/$ver/AmlImg_${ver}_linux_amd64"
chmod +x ./AmlImg

# 下载玩客云u-boot eMMC固件
curl --retry 3 -L -o ./uboot.img "https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/eMMC.burn.img"
rm -rf burn
./AmlImg unpack ./uboot.img burn/

echo "::endgroup::"

# 解压原固件gz
gunzip -f openwrt/bin/targets/*/*/*.gz || true

# 只取第一个img（防止多文件）
diskimg=$(find openwrt/bin/targets -maxdepth 3 -name "*.img" | head -n1)
if [ -z "$diskimg" ]; then
    echo "❌ 找不到原始img固件！"
    exit 1
fi
prefix="${diskimg%.img}"
echo "✅ 源镜像：$diskimg"

# ========== 统一清理函数 ==========
cleanup() {
    set +e
    sudo losetup -d "$loop" 2>/dev/null
    sudo losetup -d "$loop_usb" 2>/dev/null
    set -e
}
trap cleanup EXIT

# ========== loop 挂载（等待分区设备就绪）==========
loop=$(sudo losetup --find --show -P "$diskimg")
for i in $(seq 1 10); do
    [ -e "${loop}p1" ] && [ -e "${loop}p2" ] && break
    sudo partprobe "$loop" 2>/dev/null || true
    sleep 1
done

if [ ! -e "${loop}p1" ] || [ ! -e "${loop}p2" ]; then
    echo "❌ loop 设备分区未就绪！"
    exit 1
fi

# ========== 生成 eMMC burn.img ==========
echo "📤 导出 boot 分区 p1 -> boot_ext.img"
sudo dd if="${loop}p1" of="./boot_ext.img" bs=4M status=none
sudo img2simg "./boot_ext.img" burn/boot.simg

echo "📤 导出 rootfs 分区 p2 -> emmc_rootfs_ext.img"
sudo dd if="${loop}p2" of="./emmc_rootfs_ext.img" bs=4M status=none
sudo img2simg "./emmc_rootfs_ext.img" burn/rootfs.simg

sudo losetup -d "$loop"

# 双分区烧录指令（关键修复！）
cat > burn/commands.txt <<'EOF'
PARTITION:boot:sparse:boot.simg
PARTITION:rootfs:sparse:rootfs.simg
EOF

burnimg="${prefix}.burn.img"
./AmlImg pack "$burnimg" burn/
echo "✅ 打包eMMC burn镜像：$burnimg"

# eMMC镜像 xz压缩 + sha256
xz -9 --threads=0 "$burnimg"
sha256sum "${burnimg}.xz" > "${burnimg}.xz.sha256"

# ====================== 组装 USB‑Boot burn image ======================
echo "::group::Build USB‑Boot burn image"

USB_ASSETS="./usb_assets"
USB_BURN_DIR="./usb_burn"
mkdir -p "$USB_ASSETS"
rm -rf "$USB_BURN_DIR"
mkdir -p "$USB_BURN_DIR"

# 下载固件组件
curl --retry 3 -L -o "$USB_ASSETS/ddr_init.bin"    "https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/ddr_init.bin"
curl --retry 3 -L -o "$USB_ASSETS/firmware.bin"    "https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/firmware.bin"
curl --retry 3 -L -o "$USB_ASSETS/resource.img"    "https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/resource.img"
curl --retry 3 -L -o "$USB_ASSETS/u-boot-comp.bin" "https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/u-boot-comp.bin"

cp "$USB_ASSETS/ddr_init.bin"    "$USB_BURN_DIR/"
cp "$USB_ASSETS/firmware.bin"    "$USB_BURN_DIR/"
cp "$USB_ASSETS/resource.img"    "$USB_BURN_DIR/"
cp "$USB_ASSETS/u-boot-comp.bin" "$USB_BURN_DIR/u-boot.bin"

cat > "$USB_BURN_DIR/burn.conf" <<'EOF'
DDR:ddr_init.bin
FIRMWARE:firmware.bin
RESOURCE:resource.img
UBOOT:u-boot.bin
EOF

# 重新挂载，导出 boot + rootfs
loop_usb=$(sudo losetup --find --show -P "$diskimg")
for i in $(seq 1 10); do
    [ -e "${loop_usb}p1" ] && [ -e "${loop_usb}p2" ] && break
    sudo partprobe "$loop_usb" 2>/dev/null || true
    sleep 1
done

echo "📤 USB打包：导出 boot 分区 p1"
sudo dd if="${loop_usb}p1" of="./usb_boot_ext.img" bs=4M status=none
sudo img2simg "./usb_boot_ext.img" "$USB_BURN_DIR/boot.simg"

echo "📤 USB打包：导出 rootfs 分区 p2"
sudo dd if="${loop_usb}p2" of="./usb_rootfs_ext.img" bs=4M status=none
sudo img2simg "./usb_rootfs_ext.img" "$USB_BURN_DIR/rootfs.simg"

sudo losetup -d "$loop_usb"

# USB 烧录也需要双分区
cat > "$USB_BURN_DIR/commands.txt" <<'EOF'
PARTITION:boot:sparse:boot.simg
PARTITION:rootfs:sparse:rootfs.simg
EOF

usb_burnimg="${prefix}-USB.burn.img"
./AmlImg pack "$usb_burnimg" "$USB_BURN_DIR"
echo "✅ 打包USB burn镜像：$usb_burnimg"

xz -9 --threads=0 "$usb_burnimg"
sha256sum "${usb_burnimg}.xz" > "${usb_burnimg}.xz.sha256"

echo "::endgroup::"

# ====================== USB RAW 镜像（dd 写 U盘）======================
echo "::group::Build USB RAW image"
usb_raw_img="${prefix}-usb.raw.img"
cp "$diskimg" "$usb_raw_img"
xz -9 --threads=0 "$usb_raw_img"
sha256sum "${usb_raw_img}.xz" > "${usb_raw_img}.xz.sha256"
echo "✅ RAW U盘启动镜像：${usb_raw_img}.xz"
echo "👉 写入命令：xzcat ${usb_raw_img}.xz | dd of=/dev/sdX bs=4M status=progress conv=fsync"
echo "::endgroup::"

# ====================== 清理 ======================
sudo rm -rf "$USB_ASSETS" "$USB_BURN_DIR" \
    ./boot_ext.img ./emmc_rootfs_ext.img \
    ./usb_boot_ext.img ./usb_rootfs_ext.img \
    burn ./AmlImg ./uboot.img

echo ""
echo "🎉 全部镜像构建完成！产物如下："
echo "  📦 eMMC 线刷：${burnimg}.xz"
echo "  📦 USB 烧录：${usb_burnimg}.xz"
echo "  📦 U盘直写：${usb_raw_img}.xz"

# ========= 可选：删除原始编译产物 =========
# rm -f "$diskimg"
