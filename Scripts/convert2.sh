#!/bin/bash
set -euo pipefail
#=================================================
# 玩客云 OneCloud S905X meson8b OpenWrt 转换脚本
# 输出：
#   openwrt.img.xz        晶晨宝盒整盘升级包(含MBR)
#   openwrt.burn.img.xz   USB Burning Tool 线刷包
#   *.sha                 sha256校验文件
#=================================================

AMLIMG_VERSION="v0.3.2"
UBOOT_TPL_URL="https://github.com/rmoyulong/u-boot-onecloud/releases/download/Onecloud_Uboot_23.12.24_18.15.09/eMMC.burn.img"
WORK_BASE="${GITHUB_WORKSPACE:-$(pwd)}"

INIT_PWD=$(pwd)
cd "${WORK_BASE}"

loop=""
cleanup() {
    if [[ -n "${loop:-}" && -b "${loop}" ]]; then
        echo "→ 释放回环设备 ${loop}"
        sudo losetup -d "${loop}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# --------------------------
# 步骤1：定位原始OpenWrt镜像
# --------------------------
echo "===== [1] 定位OpenWrt原始镜像 ====="
IMG_GZ=$(find -L openwrt/bin/targets -maxdepth 3 -name "*.img.gz" | head -n1)
diskimg="${WORK_BASE}/openwrt.img"

if [[ -n "${IMG_GZ}" ]]; then
    echo "✅ 找到img.gz: ${IMG_GZ}"
    gunzip -k "${IMG_GZ}"
    RAW_IMG="${IMG_GZ%.gz}"
    mv "${RAW_IMG}" "${diskimg}"
else
    echo "ℹ️ 未找到img.gz，查找裸img"
    RAW_IMG=$(find -L openwrt/bin/targets -maxdepth 3 -name "*.img" | head -n1)
    if [[ -z "${RAW_IMG}" ]]; then
        echo "ERROR: 找不到 *.img.gz / *.img"
        exit 1
    fi
    mv "${RAW_IMG}" "${diskimg}"
fi
echo "✅ raw镜像: ${diskimg}"

# --------------------------
# 步骤2：晶晨宝盒整盘包 openwrt.img.xz
# --------------------------
echo -e "\n===== [2] 生成晶晨宝盒整盘升级包 ====="
xz -9 --threads=0 -k "${diskimg}"
sha256sum "${diskimg}.xz" > "${diskimg}.xz.sha"
echo "✅ ${diskimg}.xz"

# --------------------------
# 步骤3：USB Burning Tool 线刷包
# --------------------------
echo -e "\n===== [3] 生成USB‑Burning线刷包 ====="
sudo apt update -qq
sudo apt install -y android-sdk-libsparse-utils xz-utils

AMLIMG_BIN="${WORK_BASE}/AmlImg"
curl -fsSL -o "${AMLIMG_BIN}" "https://github.com/rmoyulong/AmlImg/releases/download/${AMLIMG_VERSION}/AmlImg_${AMLIMG_VERSION}_linux_amd64"
chmod +x "${AMLIMG_BIN}"

UBOOT_TPL="${WORK_BASE}/uboot.img"
curl -fsSL -o "${UBOOT_TPL}" "${UBOOT_TPL_URL}"

BURN_WORK="${WORK_BASE}/burn"
rm -rf "${BURN_WORK}"
"${AMLIMG_BIN}" unpack "${UBOOT_TPL}" "${BURN_WORK}/"
rm -f "${BURN_WORK}"/*.simg

loop=$(sudo losetup --find --show --partscan "${diskimg}")
echo "loop设备: ${loop}"

if [[ ! -b "${loop}p1" || ! -b "${loop}p2" ]];then
    echo "ERROR: boot(p1)/rootfs(p2)分区缺失，镜像分区表异常"
    exit 1
fi

sudo img2simg "${loop}p1" "${BURN_WORK}/boot.simg"
sudo img2simg "${loop}p2" "${BURN_WORK}/rootfsa.simg"

if ! grep -q '^PARTITION:boot:sparse:boot.simg' "${BURN_WORK}/commands.txt"; then
    printf "PARTITION:boot:sparse:boot.simg\nPARTITION:rootfsa:sparse:rootfsa.simg\n" >> "${BURN_WORK}/commands.txt"
fi

prefix="${diskimg%.img}"
burnimg="${prefix}.burn.img"
"${AMLIMG_BIN}" pack "${burnimg}" "${BURN_WORK}/"

for f in "${burnimg}"; do
    sha256sum "${f}" > "${f}.sha"
    xz -9 --threads=0 -k "${f}"
done

echo -e "\n===== convert2.sh 全部输出产物 ====="
ls -lh "${WORK_BASE}"/openwrt*.xz "${WORK_BASE}"/openwrt*.sha 2>/dev/null || true

cd "${INIT_PWD}"
