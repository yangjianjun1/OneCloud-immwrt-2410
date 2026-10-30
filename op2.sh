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
set -e

# ========== 替换 golang 为 26.x ==========
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang.git -b 26.x feeds/packages/lang/golang

# ========== 拉取第三方插件，先清理避免重复clone报错 ==========
rm -rf package/chajian
mkdir -p package/chajian

# luci-app-poweroffdevice
git clone --depth 1 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice

# luci-app-mosdns（sbwml版本）
git clone --depth 1 https://github.com/sbwml/luci-app-mosdns.git package/chajian/mosdns

# ========== 基础配置修改 ==========
# 修改默认IP
sed -i 's/192.168.50.1/192.168.50.23/g' package/base-files/files/bin/config_generate

# 修改主机名
sed -i "s/hostname='.*'/hostname='OneCloud'/g" package/base-files/files/bin/config_generate

# 修改时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/.*timezone='CST-8'.*/a\ set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# 修改固件显示名称
sed -i 's/NAME="%D"/NAME="OpenWrt"/g' package/base-files/files/usr/lib/os-release
sed -i 's/PRETTY_NAME="%D %V"/PRETTY_NAME="OpenWrt %V"/g' package/base-files/files/usr/lib/os-release
sed -i 's/OPENWRT_RELEASE="%D %V %C"/OPENWRT_RELEASE="OpenWrt %V %C"/g' package/base-files/files/usr/lib/os-release

# ========== 默认主题（推荐改用下面uci方式，比改luci-light更稳） ==========
# 方案：设置uci默认主题为 material，前提：.config 选中 luci-theme-material
sed -i 's|set luci.main.mediaurlbase=.*|set luci.main.mediaurlbase=/luci-static/material|g' package/base-files/files/bin/config_generate

# 修复 amlogic 打包脚本权限（OneCloud 玩客云必备）
chmod +x target/linux/amlogic/image/gen_aml_emmc_img.sh

echo "✅ op2.sh 执行完成"
