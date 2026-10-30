#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-op3.sh
# Description: OpenWrt DIY script part3 (Remove feeds)
#
set -e

# 删除不用的 feed，减少编译耗时
sed -i '/src-git freifunk/d' feeds.conf.default
sed -i '/src-git video/d' feeds.conf.default
sed -i '/src-git oldpackages/d' feeds.conf.default
sed -i '/src-git targets/d' feeds.conf.default

echo "✅ op3.sh 执行完成，已清理不需要的 feeds"
cat feeds.conf.default
