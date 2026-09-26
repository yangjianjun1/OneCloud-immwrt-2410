#!/bin/bash
set -euo pipefail

#=================================================
# 玩客云(OneCloud / S905X, meson8b) OpenWrt -> Amlogic 线刷包 转换脚本
#
# 【分区事实（来自 target/linux/amlogic/image/gen_aml_emmc_img.sh 的 ptgen）】
#   openwrt.img 是整盘镜像，扇区0 为 MBR(msdos) 分区表，只切 2 个主分区：
#     p1 = boot   类型0c(FAT32)  16M  -> uImage + dtb + boot.scr
#     p2 = rootfs 类型83(ext4)   600M -> 首启自动扩容填满 eMMC
#   没有 rootfsb、没有独立 data 分区。
#
# 【两种产物】
#   openwrt.img.xz      : 整盘镜像，含 MBR+p1+p2，晶晨宝盒网页升级用。空白/已清空 eMMC 刷它。
#   openwrt.burn.img.xz : USB Burning Tool 线刷包。只写 bootloader(模板保留)+boot+rootfsa。
#                         线刷包内【不含 MBR】，假定 eMMC 已有分区表，用于日常更新系统。
#                         全新空盘请先刷一次 openwrt.img.xz 建立MBR分区表。
#=================================================

# ==================== 可配置变量区 ====================
AMLIMG_VERSION="v0.3.2"
UBOOT_TPL_URL="https://github.com/rmoyulong/u-boot-onecloud/releases/download/Onecloud_Uboot_23.12.24_18.15.09/eMMC.burn.img"
WORK_BASE="${GITHUB_WORKSPACE}"
# ======================================================

# 保存初始工作目录
INIT_PWD=$(pwd)
cd "${WORK_BASE}"

# 全局变量
loop=""
diskimg=""
burn_out_dir="${WORK_BASE}"

# 资源清理函数：释放loop回环设备
cleanup() {
    if [[ -n "${loop:-}" && -b "${loop}" ]]; then
        echo "→ 释放回环设备 ${loop}"
        sudo losetup -d "${loop}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "===== 开始打包标准 Amlogic 线刷包 ====="
echo "[1/8] 安装依赖工具..."
sudo apt update -qq
sudo apt install -y android-sdk-libsparse-utils xz-utils

echo "[2/8] 下载 AmlImg 工具 ${AMLIMG_VERSION}..."
AMLIMG_BIN="${WORK_BASE}/AmlImg"
curl -fsSL -o "${AMLIMG_BIN}" "https://github.com/rmoyulong/AmlImg/releases/download/${AMLIMG_VERSION}/AmlImg_${AMLIMG_VERSION}_linux_amd64"
chmod +x "${AMLIMG_BIN}"

echo "[3/8] 下载玩客云 uboot 模板..."
UBOOT_TPL="${WORK_BASE}/uboot.img"
curl -fsSL -o "${UBOOT_TPL}" "${UBOOT_TPL_URL}"

echo "[4/8] 解压 uboot 模板..."
BURN_WORK="${WORK_BASE}/burn"
rm -rf "${BURN_WORK}"
"${AMLIMG_BIN}" unpack "${UBOOT_TPL}" "${BURN_WORK}/"
rm -f "${BURN_WORK}"/*.simg

echo "[5/8] 提取 OpenWrt 固件镜像..."
IMG_GZ=$(find -L openwrt/bin/targets -maxdepth 3 -name "*.img.gz" | head -n1)
if [[ -n "${IMG_GZ}" ]]; then
    echo "✅ 找到gzip压缩固件: ${IMG_GZ}"
    gunzip -k "${IMG_GZ}"
    RAW_IMG="${IMG_GZ%.gz}"
    mv "${RAW_IMG}" "${WORK_BASE}/openwrt.img"
    diskimg="${WORK_BASE}/openwrt.img"
else
    echo "ℹ️ 未找到img.gz，尝试查找裸img镜像"
    RAW_IMG=$(find -L openwrt/bin/targets -maxdepth 3 -name "*.img" | head -n1)
    if [[ -n "${RAW_IMG}" ]]; then
        mv "${RAW_IMG}" "${WORK_BASE}/openwrt.img"
        diskimg="${WORK_BASE}/openwrt.img"
    else
        echo "ERROR: 找不到 openwrt img.gz / img 文件！"
        exit 1
    fi
fi
echo "✅ OpenWrt raw镜像: ${diskimg}"

echo "===== 生成晶晨宝盒 img.xz 整盘升级包 ====="
xz -9 --threads=0 -k "${diskimg}"
sha256sum "${diskimg}.xz" > "${diskimg}.xz.sha"
echo "✅ 晶晨宝盒升级包: ${diskimg}.xz"

# 挂载回环设备，扫描分区
loop=$(sudo losetup --find --show --partscan "${diskimg}")
echo "回环设备: ${loop}"

echo "----- openwrt.img MBR分区自检（预期 p1=boot，p2=rootfs） -----"
sudo fdisk -l "${loop}" || true
echo "----------------------------------------------------------------"

# 校验boot、rootfs分区是否存在
if [[ ! -b "${loop}p1" ]]; then
    echo "ERROR: 找不到 ${loop}p1 (boot分区)，镜像分区结构异常"
    exit 1
fi
if [[ ! -b "${loop}p2" ]]; then
    echo "ERROR: 找不到 ${loop}p2 (rootfs分区)，镜像分区结构异常"
    exit 1
fi

echo "[6/8] 转换 sparse 格式并组装线刷包..."
sudo img2simg "${loop}p1" "${BURN_WORK}/boot.simg"
sudo img2simg "${loop}p2" "${BURN_WORK}/rootfsa.simg"

# AmlImg v0.3.2 commands.txt 格式 TYPE:NAME:IMGTYPE:FILENAME
# 只追加，不能覆盖原有模板条目；避免重复追加，先过滤是否已存在
if ! grep -q '^PARTITION:boot:sparse:boot.simg' "${BURN_WORK}/commands.txt"; then
    printf "PARTITION:boot:sparse:boot.simg\nPARTITION:rootfsa:sparse:rootfsa.simg\n" >> "${BURN_WORK}/commands.txt"
fi

echo "===== commands.txt 预览 ====="
cat "${BURN_WORK}/commands.txt"
echo "============================"

prefix="${diskimg%.img}"
burnimg="${prefix}.burn.img"
echo "输出线刷包文件: ${burnimg}"
ls -la "${BURN_WORK}/"

# AmlImg pack：输出文件在前，源目录在后
"${AMLIMG_BIN}" pack "${burnimg}" "${BURN_WORK}/"

echo "[7/8] 压缩线刷包并生成sha256校验文件..."
cd "${burn_out_dir}"
for f in *.burn.img; do
    sha256sum "${f}" > "${f}.sha"
    xz -9 --threads=0 -k "${f}"
done

echo "[8/8] 全部打包完成，列出产物："
ls -lh .
echo "===== 线刷包打包结束 ====="
echo "【产物说明】"
echo "  openwrt.img.xz            → 晶晨宝盒整盘升级包（含MBR，全新空白eMMC优先刷这个）"
echo "  *.burn.img.xz             → USB Burning Tool线刷包，仅更新boot+rootfsa，用于日常升级"
echo "  *.sha                     → sha256校验和文件"

# 返回初始目录
cd "${INIT_PWD}"
