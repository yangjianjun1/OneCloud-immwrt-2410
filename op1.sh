#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: op1.sh
# Description: DIY script part 1 (Before Update feeds)
#
set -e

# 可选：国内GH代理加速 feeds，不需要就注释掉
# GITHUB_PROXY=https://mirror.ghproxy.com/
# sed -i "s|https://github.com|${GITHUB_PROXY}https://github.com|g" feeds.conf.default

# ==========在这里添加第三方插件 git clone==========
# git clone --depth=1 https://github.com/xxx/xxx package/xxx

echo "✅ ImmortalWrt openwrt-24.10 原生feeds，不做替换"
cat feeds.conf.default
