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
# ===== 自动获取24.10系列最新正式Release标签，替换原来固定切换分支 =====
git fetch --tags
LATEST_TAG=$(git tag -l "v24.10.*" | sort -V | tail -n1)
echo "✅ 自动选中OpenWrt 24.10最新正式版标签: ${LATEST_TAG}"
git checkout "${LATEST_TAG}"
# 改为 ImmortalWrt 的 packages
sed -i 's|^src-git packages https://git.openwrt.org/feed/packages.*|src-git packages https://github.com/immortalwrt/packages.git;openwrt-24.10|' feeds.conf.default
# 改为 ImmortalWrt 的 luci
sed -i 's|^src-git luci https://git.openwrt.org/project/luci.*|src-git luci https://github.com/immortalwrt/luci.git;openwrt-24.10|' feeds.conf.default
# 其余改为稳定的 github 源
sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/telephony.git|https://github.com/openwrt/telephony.git|g' feeds.conf.default
