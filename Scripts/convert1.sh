sudo apt install android-sdk-libsparse-utils xz-utils
ver="v0.3.1"
curl -L -o ./AmlImg https://github.com/lxiaya/AmlImg/releases/download/$ver/AmlImg_${ver}_linux_amd64
chmod +x ./AmlImg
curl -L -o ./uboot.img https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/eMMC.burn.img
./AmlImg unpack ./uboot.img burn/
echo "::endgroup::"

gunzip openwrt/bin/targets/*/*/*.gz

diskimg=$(ls openwrt/bin/targets/*/*/*.img)
loop=$(sudo losetup --find --show -P "$diskimg")

img_ext="./emmc_openwrt.img"
sudo rm -rf "$img_ext"
sudo dd if="${loop}p2" of="$img_ext" bs=4M
sudo losetup -d "$loop"

img_ext="./emmc_openwrt.img"
img_mnt="./mnt_emmc"
sudo rm -rf "$img_mnt"
mkdir -p "$img_mnt"

loop2=$(sudo losetup --find --show "$img_ext")
sudo mount "${loop2}p1" "$img_mnt"
sudo sync
sudo umount "$img_mnt"
sudo losetup -d "$loop2"
sudo rm -rf "$img_mnt"

boot_img="./emmc_openwrt.img"
sudo img2simg "$boot_img" burn/rootfs.simg

cat > burn/commands.txt <<'EOF'
PARTITION:boot 0x4000000
WRITE:boot rootfs.simg
EOF

prefix=$(ls openwrt/bin/targets/*/*/*.img | sed 's/\.img$//')
burnimg="${prefix}.burn.img"
./AmlImg pack "$burnimg" burn/

# eMMC镜像 xz压缩 + sha256校验
xz -9 --threads=0 "$burnimg"
sha256sum "${burnimg}.xz" >"${burnimg}.xz.sha256"

# ====================== 脚本内部组装USB.burn.img ======================
echo "::group::Build USB‑Boot burn image (build inside script)"

USB_ASSETS="./usb_assets"
USB_BURN_DIR="./usb_burn"
mkdir -p "$USB_ASSETS"
rm -rf "$USB_BURN_DIR"
mkdir -p "$USB_BURN_DIR"

#下载固件组件，增加重试
curl --retry 3 -L -o "$USB_ASSETS/ddr_init.bin"     https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/ddr_init.bin
curl --retry 3 -L -o "$USB_ASSETS/firmware.bin"     https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/firmware.bin
curl --retry 3 -L -o "$USB_ASSETS/resource.img"     https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/resource.img
curl --retry 3 -L -o "$USB_ASSETS/u-boot-comp.bin"  https://github.com/lxiaya/u-boot-onecloud/releases/download/build-20230901-0443/u-boot-comp.bin

cp "$USB_ASSETS/ddr_init.bin"     "$USB_BURN_DIR/"
cp "$USB_ASSETS/firmware.bin"     "$USB_BURN_DIR/"
cp "$USB_ASSETS/resource.img"     "$USB_BURN_DIR/"
cp "$USB_ASSETS/u-boot-comp.bin"  "$USB_BURN_DIR/u-boot.bin"

cat > "$USB_BURN_DIR/burn.conf" <<'EOF'
DDR:ddr_init.bin
FIRMWARE:firmware.bin
RESOURCE:resource.img
UBOOT:u-boot.bin
EOF

diskimg_usb=$(ls openwrt/bin/targets/*/*/*.img)
loop_usb=$(sudo losetup --find --show -P "$diskimg_usb")
img_ext_usb="./usb_openwrt.img"
sudo rm -rf "$img_ext_usb"
sudo dd if="${loop_usb}p2" of="$img_ext_usb" bs=4M
sudo losetup -d "$loop_usb"

sudo img2simg "$img_ext_usb" "$USB_BURN_DIR/rootfs.simg"

cat > "$USB_BURN_DIR/commands.txt" <<'EOF'
PARTITION:boot 0x4000000
WRITE:boot rootfs.simg
EOF

prefix_usb=$(ls openwrt/bin/targets/*/*/*.img | sed 's/\.img$//')
usb_burnimg="${prefix_usb}-USB.burn.img"
./AmlImg pack "$usb_burnimg" "$USB_BURN_DIR"

# USB镜像 xz压缩 + sha256校验
xz -9 --threads=0 "$usb_burnimg"
sha256sum "${usb_burnimg}.xz" >"${usb_burnimg}.xz.sha256"

#清理临时文件
sudo rm -rf "$USB_ASSETS" "$USB_BURN_DIR" "$img_ext_usb"
echo "::endgroup::"

# =========全部打包完成后，可选删除原始openwrt img/gz=========
# sudo rm -rf openwrt/bin/targets/*/*/*.img
# sudo rm -rf openwrt/bin/targets/*/*/*.gz
