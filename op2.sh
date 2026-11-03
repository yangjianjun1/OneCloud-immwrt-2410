#!/bin/bash
# File name: diy-op2.sh

rm -rf package/chajian
mkdir -p package/chajian

# ====================== 第三方插件源码 ======================
# 关机插件
git clone --depth 1 --branch v2.7 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice

# luci-app-podman 网页管理（Zerogiven 维护，官方源没有）
rm -rf package/chajian/luci-app-podman
git clone --depth 1 https://github.com/Zerogiven-OpenWRT-Packages/luci-app-podman.git package/chajian/luci-app-podman

# luci-app-diskman 磁盘管理
rm -rf package/chajian/luci-app-diskman
git clone --depth 1 https://github.com/lisaac/luci-app-diskman.git package/chajian/luci-app-diskman
mkdir -p package/chajian/parted
wget -O package/chajian/parted/Makefile https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile

# ====================== libustream 冲突处理 ======================
echo "CONFIG_PACKAGE_libustream-openssl=n" >> .config
echo "CONFIG_PACKAGE_libustream-mbedtls=y" >> .config

# ====================== IP / 主机名 / 时区 ======================
sed -i "s|set network\.lan\.ipaddr='192.168.1.1'|set network.lan.ipaddr='192.168.50.23'|g" package/base-files/files/bin/config_generate
sed -i "s|set system\.@system\[-1\]\.hostname='OpenWrt'|set system.@system[-1].hostname='OneCloud'|g" package/base-files/files/bin/config_generate
sed -i "s|set system\.@system\[-1\]\.timezone='UTC'|set system.@system[-1].timezone='CST-8'|g" package/base-files/files/bin/config_generate
sed -i "s|set system\.@system\[-1\]\.zonename='UTC'|set system.@system[-1].zonename='Asia/Shanghai'|g" package/base-files/files/bin/config_generate

# ====================== 主题 ======================
echo "CONFIG_PACKAGE_luci-theme-material=y" >> .config
sed -i '/CONFIG_PACKAGE_luci-theme-bootstrap/d' .config
echo "# CONFIG_PACKAGE_luci-theme-bootstrap is not set" >> .config
sed -i 's|option mediaurlbase.*|option mediaurlbase /luci-static/material|g' feeds/luci/modules/luci-base/root/etc/config/luci 2>/dev/null || true

# ====================== 固件名称 ======================
sed -i 's/NAME="%D"/NAME="OpenWrt"/g' package/base-files/files/usr/lib/os-release
sed -i 's/PRETTY_NAME="%D %V"/PRETTY_NAME="OpenWrt %V"/g' package/base-files/files/usr/lib/os-release
sed -i 's/OPENWRT_RELEASE="%D %V %C"/OPENWRT_RELEASE="OpenWrt %V %C"/g' package/base-files/files/usr/lib/os-release

# ====================== 晶晨打包脚本权限 ======================
chmod +x target/linux/amlogic/image/gen_aml_emmc_img.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_img.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_sdimg.sh 2>/dev/null || true
chmod +x target/linux/amlogic/image/gen_aml_update.sh 2>/dev/null || true

# ====================== luci-app-podman 网页依赖兜底 ======================
# 防止 .config 里漏写导致 defconfig 阶段被静默剔除
echo "CONFIG_PACKAGE_luci-app-podman=y" >> .config
echo "CONFIG_PACKAGE_luci-i18n-podman-zh-cn=y" >> .config
echo "CONFIG_PACKAGE_rpcd-mod-ucode=y" >> .config
echo "CONFIG_PACKAGE_ucode-mod-socket=y" >> .config
echo "CONFIG_PACKAGE_ucode-mod-struct=y" >> .config
echo "CONFIG_PACKAGE_ucode-mod-uloop=y" >> .config
echo "CONFIG_PACKAGE_ucode-mod-fs=y" >> .config
echo "CONFIG_PACKAGE_ucode-mod-uci=y" >> .config
echo "CONFIG_PACKAGE_coreutils-timeout=y" >> .config

# ====================== 验证输出 ======================
echo "==== libustream 状态 ===="
grep -E 'CONFIG_PACKAGE_libustream-(openssl|mbedtls)' .config
echo "========================="

echo "==== luci-app-podman 状态 ===="
grep -E 'CONFIG_PACKAGE_luci-app-podman' .config
echo "=============================="

echo "✅ diy-op2.sh 执行完毕"
