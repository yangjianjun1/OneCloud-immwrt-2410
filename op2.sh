#!/bin/bash
#
# Description: OpenWrt DIY script part 2 (After Update feeds)
# Target: ImmortalWrt 24.10 / 玩客云 S805 meson8b
#

# ========== 拉取第三方插件 ==========
rm -rf package/chajian
mkdir -p package/chajian

# luci-app-poweroffdevice
git clone --depth 1 https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice

# luci-app-mosdns（sbwml版本）
git clone --depth 1 https://github.com/sbwml/luci-app-mosdns.git package/chajian/mosdns

# ========== 核心防御：强制剔除已知会炸的包 ==========
# 防止 defconfig 把它们当推荐依赖拉回来
for pkg in f2fs-tools f2fsck mkf2fs libf2fs arptables fw-utils gunzip; do
    sed -i "/CONFIG_PACKAGE_${pkg}=/d" .config
    echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
done

# 删除 defconfig 自动生成的 libustream-openssl，强制使用 mbedtls（luci-ssl 依赖）
sed -i '/CONFIG_PACKAGE_libustream-openssl/d' .config

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

# ========== 修复 amlogic 打包脚本权限（OneCloud 玩客云必备）==========
chmod +x target/linux/amlogic/image/gen_aml_emmc_img.sh

echo "✅ op2.sh 执行完成"
