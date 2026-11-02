#!/bin/bash
#
# File name: op1.sh
# Description: DIY script part 1 (Before Update feeds)
#
set -e

# ========== golang：保持 ImmortalWrt 24.10.6 官方自带版本 ==========
# （不替换，确保完全可复现）

echo "✅ op1.sh 执行完成：golang 保持 ImmortalWrt 24.10.6 原生版本"
cat feeds.conf.default
