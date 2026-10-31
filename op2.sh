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

# ========== 拉取第三方插件 ==========
rm -rf package/chajian
mkdir -p package/chajian

# luci-app-poweroffdevice
git clone --depth 1 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice
# luci-app-mosdns
git clone --depth 1 https://github.com/sbwml/luci-app-mosdns.git package/chajian/mosdns

# ========== 核心：解决 libustream-openssl / libustream-mbedtls 冲突 ==========
# 先强制写死禁用 libustream-openssl
echo "CONFIG_PACKAGE_libustream-openssl=n" >> .config

# 更新并安装 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 执行 defconfig
make defconfig

# 兜底：如果defconfig把它改回y，强制改回n
sed -i 's/^CONFIG_PACKAGE_libustream-openssl=y/CONFIG_PACKAGE_libustream-openssl=n/g' .config

# ========== 基础定制：IP、主机名、时区、固件名称 ==========
# 默认IP
sed -i 's/192.168.50.1/192.168.50.23/g' package/base-files/files/bin/config_generate
# 主机名
sed -i "s/hostname='.*'/hostname='OneCloud'/g" package/base-files/files/bin/config_generate
# 时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/timezone='CST-8'/a\ set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# 固件界面显示名称
sed -i 's/NAME="%D"/NAME="OpenWrt"/g' package/base-files/files/usr/lib/os-release
sed -i 's/PRETTY_NAME="%D %V"/PRETTY_NAME="OpenWrt %V"/g' package/base-files/files/usr/lib/os-release
sed -i 's/OPENWRT_RELEASE="%D %V %C"/OPENWRT_RELEASE="OpenWrt %V %C"/g' package/base-files/files/usr/lib/os-release

# ========== 晶晨Amlogic打包脚本权限修复（玩客云必加） ==========
chmod +x target/linux/amlogic/image/gen_aml_emmc_img.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_img.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_sdimg.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_update.sh 2>/dev/null || true

# ========== 调试输出，CI里可直接查看是否关闭成功 ==========
echo "==== libustream-openssl 状态 ===="
grep CONFIG_PACKAGE_libustream-openssl .config
echo "================================="

echo "✅ diy-op2.sh 执行完毕"
