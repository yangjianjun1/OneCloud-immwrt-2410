#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-op2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
set -eo pipefail

# 删除自带的 golang
rm -rf feeds/packages/lang/golang
# 拉取新的 golang
git clone https://github.com/sbwml/packages_lang_golang.git -b 26.x feeds/packages/lang/golang
mkdir -p package/chajian
# 拉取 luci-app-poweroffdevice（master 分支即 24.10 JS 版）
git clone https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice
# 拉取 luci-app-mosdns（含 mosdns 主程序 + v2dat）
git clone https://github.com/sbwml/luci-app-mosdns.git package/chajian/mosdns

## 筛选程序
function merge_package(){
    # 参数1是分支名,参数2是库地址。所有文件下载到指定路径。
    # 同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开。
    trap 'rm -rf "$tmpdir"' EXIT
    branch="$1" curl="$2" target_dir="$3" && shift 3
    rootdir="$PWD"
    localdir="$target_dir"
    [ -d "$localdir" ] || mkdir -p "$localdir"
    tmpdir="$(mktemp -d)" || exit 1
    git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$curl" "$tmpdir"
    cd "$tmpdir"
    git sparse-checkout init --cone
    git sparse-checkout set "$@"
    for folder in "$@"; do
        mv -f "$folder" "$rootdir/$localdir"
    done
    cd "$rootdir"
}

## 提取 fullconenat-nft
merge_package openwrt-24.10 https://github.com/immortalwrt/immortalwrt.git package/network/utils package/network/utils/fullconenat-nft

# 修复luci-app-firewall路径 24.10 在applications下
LUCI_FW_DIR="feeds/luci/applications/luci-app-firewall"
if [ ! -d "${LUCI_FW_DIR}" ];then
    echo "ERROR: ${LUCI_FW_DIR} 目录不存在，请确认feeds已执行 ./scripts/feeds update -a && ./scripts/feeds install -a"
    exit 1
fi
cd "${LUCI_FW_DIR}"
wget -q https://raw.githubusercontent.com/immortalwrt/luci/openwrt-24.10/modules/luci-app-firewall/patches/0001-firewall-zone-add-fullcone-and-fullcone6-options.patch
patch -p1 < 0001-firewall-zone-add-fullcone-and-fullcone6-options.patch
cd ../../..

CFG_GEN="package/base-files/files/sbin/config_generate"

# 修改默认 IP
sed -i 's/192.168.50.1/192.168.50.23/g' "${CFG_GEN}"
#sed -i 's/192.168.1.1/192.168.8.1/g' "${CFG_GEN}"

# 修改默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci-light/Makefile

# 修改主机名
sed -i "s/hostname='.*'/hostname='OneCloud'/g" "${CFG_GEN}"
# 修改默认时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" "${CFG_GEN}"
sed -i "/.*timezone='CST-8'.*/a\ set system.@system[-1].zonename='Asia/Shanghai'" "${CFG_GEN}"

# 修复 gen_aml_emmc_img.sh 权限丢失导致 Error 126，文件不存在跳过不报错
AML_SCRIPT="target/linux/amlogic/image/gen_aml_emmc_img.sh"
if [ -f "${AML_SCRIPT}" ];then
    chmod +x "${AML_SCRIPT}"
fi
