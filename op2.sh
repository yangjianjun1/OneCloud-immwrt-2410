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
git clone --depth 1 https://github.com/sbwml/packages_lang_golang.git -b 26.x feeds/packages/lang/golang

mkdir -p package/chajian
# 拉取 luci-app-poweroffdevice（master 分支即 24.10 JS 版）
git clone --depth 1 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice
# 拉取 luci-app-mosdns（含 mosdns 主程序 + v2dat）
git clone --depth 1 https://github.com/sbwml/luci-app-mosdns.git package/chajian/mosdns

## 从仓库本地复制 fullconenat-nft
cp -r $GITHUB_WORKSPACE/local_pkg/fullconenat-nft package/network/utils/

#====调试打印====
echo "===== check fullconenat-nft ====="
ls -la package/network/utils/fullconenat-nft

## 本地补丁添加FullCone NAT界面选项
LUCI_FW_DIR="feeds/luci/applications/luci-app-firewall"
if [ ! -d "${LUCI_FW_DIR}" ];then
    echo "ERROR: ${LUCI_FW_DIR} 目录不存在，请确认feeds已执行 ./scripts/feeds update -a && ./scripts/feeds install -a"
    exit 1
fi
cd "${LUCI_FW_DIR}"
patch -p1 < $GITHUB_WORKSPACE/patches/0001-firewall-zone-add-fullcone-and-fullcone6-options.patch
cd ../../..

#====修正！！是 bin 不是 sbin====
CFG_GEN="package/base-files/files/bin/config_generate"

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

echo "==== patch check fullcone keyword ====="
grep fullcone feeds/luci/applications/luci-app-firewall/htdocs/luci-static/resources/view/firewall/zones.js
echo "==== diy‑op2.sh finish ====="
