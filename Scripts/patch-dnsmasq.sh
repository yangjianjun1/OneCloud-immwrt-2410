#!/bin/bash
# =============================================
# Patch 脚本：彻底解决 dnsmasq-full 安装阶段 Error 255
# 适配：ImmortalWrt v24.10.x
# 执行时机：锁定 feeds 之后、feeds install 之前
# 执行位置：OpenWrt / ImmortalWrt 源码根目录
# =============================================

set -e

echo "============================================="
echo ">>> 开始执行 dnsmasq 冲突修复补丁"
echo "============================================="

# 1. 删除中文语言包附带的 default-settings-chn（uci-defaults 脚本重灾区）
CHN_SETTINGS="feeds/luci/collections/luci-i18n-zh-cn/default-settings-chn"
if [ -d "$CHN_SETTINGS" ]; then
    rm -rf "$CHN_SETTINGS"
    echo "✅ 已删除 default-settings-chn"
else
    echo "ℹ️  未找到 default-settings-chn，跳过"
fi

# 2. 清空 ImmortalWrt 原生默认设置的 uci-defaults（核心出厂脚本来源）
EMORTAL_SETTINGS="package/emortal/default-settings/files/etc/uci-defaults"
if [ -d "$EMORTAL_SETTINGS" ]; then
    # 只删除 dhcp/dnsmasq 相关脚本，保留系统基础初始化
    grep -rl "dhcp\|dnsmasq" "$EMORTAL_SETTINGS" 2>/dev/null | xargs rm -f 2>/dev/null || true
    echo "✅ 已清理原生 default-settings 中 dhcp/dnsmasq 相关脚本"
else
    echo "ℹ️  未找到 emortal default-settings 目录，跳过"
fi

# 3. 备份并清空 base-files 自带 uci-defaults（兜底）
BASE_UCI="package/base-files/files/etc/uci-defaults"
if [ -d "$BASE_UCI" ]; then
    # 备份原目录
    mv "$BASE_UCI" "${BASE_UCI}.bak"
    mkdir -p "$BASE_UCI"
    echo "✅ base-files uci-defaults 已备份并清空"
else
    mkdir -p "$BASE_UCI"
    echo "✅ 已创建 base-files uci-defaults 空目录"
fi

# 4. 强制锁定 .config：禁用所有 dnsmasq 变体，只保留 full 版本
if [ -f ".config" ]; then
    # 删除所有 dnsmasq 相关旧行
    sed -i '/^CONFIG_PACKAGE_dnsmasq[=_]/d' .config
    # 写入禁用项
    echo "# CONFIG_PACKAGE_dnsmasq is not set" >> .config
    echo "# CONFIG_PACKAGE_dnsmasq-dhcpv6 is not set" >> .config
    echo "# CONFIG_PACKAGE_dnsmasq-base is not set" >> .config
    echo "✅ .config 已锁定：禁用原版 dnsmasq 变体"
else
    echo "ℹ️  当前目录无 .config，跳过配置锁定"
fi

# 5. 扫描校验：输出所有写死依赖 dnsmasq 的包
echo ""
echo ">>> 扫描写死依赖 dnsmasq 的包："
grep -r "DEPENDS:=+dnsmasq " feeds/ --include Makefile > feeds_dep_dnsmasq.log 2>/dev/null || true
if [ -s feeds_dep_dnsmasq.log ]; then
    cat feeds_dep_dnsmasq.log
else
    echo "✅ 未发现写死依赖 dnsmasq 的包"
fi

echo ""
echo "============================================="
echo ">>> dnsmasq 冲突补丁执行完成"
echo "============================================="
exit 0
