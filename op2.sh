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

# ========== 拉取第三方插件，先清理避免重复clone报错 ==========
rm -rf package/chajian
mkdir -p package/chajian

# luci-app-poweroffdevice
git clone --depth 1 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice

# luci-app-mosdns（sbwml版本）
git clone --depth 1 https://github.com/sbwml/luci-app-mosdns.git package/chajian/mosdns

# --------------------------【核心防御：删除defconfig自动生成的libustream‑openssl，强制使用mbedtls】--------------------------
sed -i '/CONFIG_PACKAGE_libustream-openssl/d' .config

# 重新刷新feed与defconfig，清理无效依赖
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig
# ---------------------------------------------------------------------------------------------------------------------------

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

# ========== 默认主题 material ==========
# ⚠️ seed.config未开启 luci-theme‑material=y，保持注释，否则网页白屏
# sed -i 's|set luci.main.mediaurlbase=.*|set luci.main.mediaurlbase=/luci-static/material|g' package/base-files/files/bin/config_generate

# 修复 amlogic 打包脚本权限（OneCloud 玩客云必备）
chmod +x target/linux/amlogic/image/gen_aml_emmc_img.sh

echo "✅ op2.sh 执行完成"
