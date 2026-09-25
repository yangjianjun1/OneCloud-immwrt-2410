#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-op1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
set -e

# 切换到标签 v24.10.8
git checkout v24.10.8

# 改为 ImmortalWrt 的 packages
sed -i 's|^src-git packages https://git.openwrt.org/feed/packages.*|src-git packages https://github.com/immortalwrt/packages.git;openwrt-24.10|' feeds.conf.default
# 改为 ImmortalWrt 的 luci
sed -i 's|^src-git luci https://git.openwrt.org/project/luci.*|src-git luci https://github.com/immortalwrt/luci.git;openwrt-24.10|' feeds.conf.default
# 其余改为稳定的 github 源
sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/telephony.git|https://github.com/openwrt/telephony.git|g' feeds.conf.default

# ========== nft-fullcone 6.6 适配代码（放在op1，feeds update前打补丁） ==========
# 拉取适配Linux6.6的nft‑fullcone(friendlyarm分支)
rm -rf package/nft-fullcone
git clone https://github.com/friendlyarm/nft-fullcone.git package/nft-fullcone

# libnftnl补丁：fullcone表达式，wget增加重试防止github raw超时
mkdir -p package/libs/libnftnl/patches
wget --retry-connrefused --tries=3 -O package/libs/libnftnl/patches/999-libnftnl-fullcone.patch https://raw.githubusercontent.com/fullcone-nat-nftables/openwrt-firewall4-with-fullcone/main/package/libs/libnftnl/patches/999-01-libnftnl-add-fullcone-expression-support.patch

# nftables 用户态补丁，24.10必须，否则nft不识别fullcone
mkdir -p package/network/utils/nftables/patches
wget --retry-connrefused --tries=3 -O package/network/utils/nftables/patches/999-nftables-fullcone.patch https://raw.githubusercontent.com/fullcone-nat-nftables/openwrt-firewall4-with-fullcone/main/package/network/utils/nftables/patches/999-01-nftables-add-fullcone-expression-support.patch

echo "==== nft‑fullcone + libnftnl + nftables patches done ===="
