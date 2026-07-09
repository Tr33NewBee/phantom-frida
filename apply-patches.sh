#!/bin/bash
# 
# phantom-frida Build Patches Applicator
# 自动应用build/frida源码所需的补丁
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRIDA_BUILD_DIR="${SCRIPT_DIR}/build/frida"
PATCH_FILE="${SCRIPT_DIR}/frida-build.patch"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Phantom-Frida Build Patches Applicator                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 检查patch文件是否存在
if [[ ! -f "$PATCH_FILE" ]]; then
    echo "❌ 错误：找不到patch文件：$PATCH_FILE"
    exit 1
fi

# 检查build/frida目录是否存在
if [[ ! -d "$FRIDA_BUILD_DIR" ]]; then
    echo "❌ 错误：找不到frida源码目录：$FRIDA_BUILD_DIR"
    echo "   请先运行 dev.sh 下载源码"
    exit 1
fi

echo "📦 Patch文件：$PATCH_FILE"
echo "📂 Frida源码目录：$FRIDA_BUILD_DIR"
echo ""

# 进入frida目录
cd "$FRIDA_BUILD_DIR"

# 检查git状态
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ 错误：$FRIDA_BUILD_DIR 不是git仓库"
    exit 1
fi

echo "🔍 检查git状态..."
DIRTY=$(git status --porcelain | wc -l)
if [[ $DIRTY -gt 0 ]]; then
    echo "⚠️  警告：检测到未提交的改动，这些可能会被覆盖"
    echo "   未提交改动数：$DIRTY"
    read -p "是否继续？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 操作已取消"
        exit 1
    fi
fi

echo ""
echo "📝 应用补丁..."

# 应用patch
if git apply "$PATCH_FILE" 2>/dev/null; then
    echo "✅ 补丁应用成功！"
else
    echo "⚠️  自动应用失败，尝试手动应用..."
    if patch -p1 < "$PATCH_FILE"; then
        echo "✅ 补丁应用成功（使用patch命令）！"
    else
        echo "❌ 补丁应用失败"
        echo "   请查看 PATCHES_NOTES.md 了解手动应用步骤"
        exit 1
    fi
fi

echo ""
echo "📊 应用结果："
git status --short | head -20
if [[ $(git status --porcelain | wc -l) -gt 20 ]]; then
    echo "   ... 及更多改动"
fi

echo ""
echo "✨ 补丁应用完成！"
echo ""
echo "📝 下一步："
echo "   1. 运行构建：bash ${SCRIPT_DIR}/dev.sh"
echo "   2. 如遇到问题，查看 ${SCRIPT_DIR}/PATCHES_NOTES.md"
echo ""

