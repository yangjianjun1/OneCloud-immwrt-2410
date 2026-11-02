#!/bin/bash
#
# File name: diy-op2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# ========== 拉取第三方插件 ==========
rm -rf package/chajian
mkdir -p package/chajian

# luci-app-poweroffdevice (锁到 v2.7 tag，兼容 24.10.x)
git clone --depth 1 --branch v2.7 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice

# luci-app-mosdns (如需启用，取消注释)
# git clone --depth 1 --branch v5 https://github.com/sbwml/luci-app-mosdns.git package/chajian/mosdns

# ========== 核心：解决 libustream 冲突 ==========
echo "CONFIG_PACKAGE_libustream-openssl=n" >> .config
echo "CONFIG_PACKAGE_libustream-mbedtls=y" >> .config

# ⚠️ 注意：不再在这里执行 feeds update/install
# 因为 Workflow 里已经在前面执行过了，且锁定版本后不应再拉最新

# ========== 基础定制：IP、主机名、时区 ==========
sed -i "s|set network\.lan\.ipaddr='192.168.1.1'|set network.lan.ipaddr='192.168.50.23'|g" package/base-files/files/bin/config_generate
sed -i "s|set system\.@system\[-1\]\.hostname='OpenWrt'|set system.@system[-1].hostname='OneCloud'|g" package/base-files/files/bin/config_generate
sed -i "s|set system\.@system\[-1\]\.timezone='UTC'|set system.@system[-1].timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "s|set system\.@system\[-1\]\.zonename='UTC'|set system.@system[-1].zonename='Asia/Shanghai'|g" package/base-files/files/bin/config_generate

# ========== 主题：luci-theme-material ==========
echo "CONFIG_PACKAGE_luci-theme-material=y" >> .config
sed -i '/CONFIG_PACKAGE_luci-theme-bootstrap/d' .config
echo "# CONFIG_PACKAGE_luci-theme-bootstrap is not set" >> .config
sed -i 's|option mediaurlbase.*|option mediaurlbase /luci-static/material|g' feeds/luci/modules/luci-base/root/etc/config/luci 2>/dev/null || true

# ========== 固件界面显示名称 ==========
sed -i 's/NAME="%D"/NAME="OpenWrt"/g' package/base-files/files/usr/lib/os-release
sed -i 's/PRETTY_NAME="%D %V"/PRETTY_NAME="OpenWrt %V"/g' package/base-files/files/usr/lib/os-release
sed -i 's/OPENWRT_RELEASE="%D %V %C"/OPENWRT_RELEASE="OpenWrt %V %C"/g' package/base-files/files/usr/lib/os-release

# ========== 晶晨 Amlogic 打包脚本权限修复 ==========
chmod +x target/linux/amlogic/image/gen_aml_emmc_img.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_img.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_sdimg.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_update.sh 2>/dev/null || true

# ========== 调试输出 ==========
echo "==== libustream 状态 ===="
grep -E 'CONFIG_PACKAGE_libustream-(openssl|mbedtls)' .config
echo "========================="
echo "✅ diy-op2.sh 执行完毕"
