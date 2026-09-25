#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-op2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# 删除自带的 golang
rm -rf feeds/packages/lang/golang
# 拉取新的 golang
git clone https://github.com/sbwml/packages_lang_golang.git -b 26.x feeds/packages/lang/golang
mkdir -p package/chajian
# 拉取 luci-app-poweroffdevice（master 分支即 24.10 JS 版）
git clone https://github.com/sirpdboy/luci-app-poweroffdevice.git package/chajian/poweroffdevice
# 拉取 luci-app-mosdns（含 mosdns 主程序 + v2dat）
git clone https://github.com/sbwml/luci-app-mosdns.git package/chajian/mosdns
## 筛选程序
function merge_package(){
    # 参数1是分支名,参数2是库地址。所有文件下载到指定路径。
    # 同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开。
    trap 'rm -rf "$tmpdir"' EXIT
    branch="$1" curl="$2" target_dir="$3" && shift 3
    rootdir="$PWD"
    localdir="$target_dir"
    [ -d "$localdir" ] || mkdir -p "$localdir"
    tmpdir="$(mktemp -d)" || exit 1
    git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$curl" "$tmpdir"
    cd "$tmpdir"
    git sparse-checkout init --cone
    git sparse-checkout set "$@"
    for folder in "$@"; do
        mv -f "$folder" "$rootdir/$localdir"
    done
    cd "$rootdir"
}
# 修改默认 IP
sed -i 's/192.168.50.1/192.168.50.23/g' package/base-files/files/bin/config_generate
#sed -i 's/192.168.1.1/192.168.8.1/g' package/base-files/files/bin/config_generate
# 修改默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-material/g' feeds/luci/collections/luci-light/Makefile
# 修改主机名
sed -i "s/hostname='.*'/hostname='OneCloud'/g" package/base-files/files/bin/config_generate
# 修改默认时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/.*timezone='CST-8'.*/a\ set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
# 修复 gen_aml_emmc_img.sh 权限丢失导致 Error 126
chmod +x target/linux/amlogic/image/gen_aml_emmc_img.sh

# 生成fullcone nft规则文件
mkdir -p files/etc/nftables.d
cat > files/etc/nftables.d/90-fullcone.nft <<'EOF'
table inet fw4 {
  chain srcnat {
    ip saddr 192.168.50.0/24 oifname "wan" masquerade fullcone
  }
}
EOF

# ====================== FullCone NAT LuCI勾选框（方案1） ======================
mkdir -p files/etc/config
cat >> files/etc/config/firewall <<EOF

config include fullcone
        option type 'nft'
        option path '/etc/nftables.d/90-fullcone.nft'
        option enabled '1'
EOF

# 在LuCI防火墙概览页面添加FullCone NAT勾选框
sed -i '/"Firewall - General"/a\
o = s:option(Flag, "fullcone_enabled", translate("FullCone NAT"), translate("启用FullCone全锥NAT，需要内核nft-fullcone模块"));\
o.rmempty = false;' feeds/luci/modules/luci-mod-network/view/firewall/overview.htm
