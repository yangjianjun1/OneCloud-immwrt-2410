#!/bin/bash
set -euo pipefail

echo "::group::Build eMMC Burn image"

# 依赖
sudo apt update -y
sudo apt install -y android-sdk-libsparse-utils xz-utils rsync gzip

# 下载工具
ver="v0.3.1"
curl --retry 3 -L -o ./AmlImg "https://github.com/lxiaya/AmlImg/releases/download/$ver/AmlImg_${ver}_linux_amd64"
chmod +x ./AmlImg

curl --retry 3 -L -o ./uboot.img "https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/eMMC.burn.img"
rm -rf burn
./AmlImg unpack ./uboot.img burn/

# 解压，找原始 img
gunzip -f openwrt/bin/targets/*/*/*.gz || true
diskimg=$(find openwrt/bin/targets -name "*.img" | head -n1)
orig_dir=$(dirname "$diskimg")

echo "✅ 源镜像：$diskimg"

# ===== loop 挂载 =====
loop=$(sudo losetup --find --show --partscan "$diskimg")
for i in $(seq 1 10); do
    [ -e "${loop}p1" ] && [ -e "${loop}p2" ] && break
    sudo partprobe "$loop" 2>/dev/null || true
    sleep 1
done

cleanup() {
    set +e
    sudo umount ./temp_rootfs 2>/dev/null
    sudo umount ./temp_boot 2>/dev/null
    sudo losetup -d "$loop" 2>/dev/null
    sudo rm -rf ./temp_rootfs ./temp_boot
    set -e
}
trap cleanup EXIT

mkdir -p temp_rootfs temp_boot
sudo mount "${loop}p2" temp_rootfs

p2_used_bytes=$(sudo du -sb temp_rootfs | awk '{print $1}')
p2_size_mb=$(( p2_used_bytes / 1024 / 1024 + 50 ))

new_rootfs_img="./openwrt_rootfs.ext4"
sudo dd if=/dev/zero of="$new_rootfs_img" bs=1M count="$p2_size_mb" status=none
sudo mkfs.ext4 -q "$new_rootfs_img"
sudo mount "$new_rootfs_img" temp_boot

sudo rsync -a temp_rootfs/ temp_boot/
sudo umount temp_boot
sudo umount temp_rootfs

sudo img2simg "${loop}p1" burn/boot.simg
sudo img2simg "$new_rootfs_img" burn/rootfs.simg

cat > burn/commands.txt <<'EOF'
PARTITION:boot:sparse:boot.simg
PARTITION:rootfs:sparse:rootfs.simg
EOF

# ===== 打包线刷包 → OneCloud-immwrt-2410.burn.img.xz =====
burnimg="${orig_dir}/OneCloud-immwrt-2410.burn.img"
./AmlImg pack "$burnimg" burn/
xz -9 --threads=0 "$burnimg"
echo "✅ 线刷包：${burnimg}.xz"

echo "::endgroup::"

# ===== 原始固件 → OneCloud-immwrt-2410.img.gz =====
echo "::group::Pack original firmware"
cp "$diskimg" "${orig_dir}/OneCloud-immwrt-2410.img"
gzip -9 "${orig_dir}/OneCloud-immwrt-2410.img"
echo "✅ 原始固件：${orig_dir}/OneCloud-immwrt-2410.img.gz"
echo "::endgroup::"

# ===== 严格清理：只留两个产物 =====
sudo rm -f "$new_rootfs_img" ./AmlImg ./uboot.img
rm -rf burn temp_rootfs temp_boot

# 删除原始编译产物（已被重命名版替代）
rm -f "$diskimg"

# 删除目录中可能残留的其他文件
find "$orig_dir" -maxdepth 1 -name "*.img" -delete
find "$orig_dir" -maxdepth 1 -name "*.gz" ! -name "OneCloud-immwrt-2410.img.gz" -delete

echo "🎉 完成！最终产物："
ls -lh "${orig_dir}/OneCloud-immwrt-2410".*
