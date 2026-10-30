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

# ========== 可选：国内 GH 代理加速 feeds，不需要就注释掉 ==========
# GITHUB_PROXY=https://mirror.ghproxy.com/
# sed -i "s|https://github.com|${GITHUB_PROXY}https://github.com|g" feeds.conf.default

# ========== 替换 golang 为 26.x（sbwml 维护，满足 mosdns 等新版插件编译要求） ==========
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang.git -b 26.x feeds/packages/lang/golang

# ========== 在这里添加第三方插件（feeds update 前 clone 到 package/） ==========
# 示例：
# git clone --depth=1 https://github.com/xxx/xxx package/xxx

echo "✅ op1.sh 执行完成：已替换 golang 26.x，feeds 保持 ImmortalWrt 原生"
cat feeds.conf.default
