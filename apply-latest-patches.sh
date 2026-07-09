#!/bin/bash
# 
# phantom-frida Latest Patches Applicator
# 自动应用最近生成的所有patch文件
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRIDA_BUILD_DIR="${SCRIPT_DIR}/build/frida"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Phantom-Frida Latest Patches Applicator                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查frida目录是否存在
if [[ ! -d "$FRIDA_BUILD_DIR" ]]; then
    echo -e "${RED}❌ 错误：找不到frida源码目录：$FRIDA_BUILD_DIR${NC}"
    echo "   请先运行 dev.sh 下载源码"
    exit 1
fi

# 定义patch文件数组
declare -a PATCHES=(
    "frida-main-latest.patch:$FRIDA_BUILD_DIR"
    "frida-core-latest.patch:$FRIDA_BUILD_DIR/subprojects/frida-core"
    "frida-gum-latest.patch:$FRIDA_BUILD_DIR/subprojects/frida-gum"
    "frida-tools-latest.patch:$FRIDA_BUILD_DIR/subprojects/frida-tools"
)

echo -e "${YELLOW}⚠️  应用模式：按顺序应用各个patch文件${NC}"
echo ""

# 计数器
TOTAL=${#PATCHES[@]}
SUCCESS=0
FAILED=0

# 应用各个patch
for i in "${!PATCHES[@]}"; do
    IFS=':' read -r PATCH_FILE PATCH_DIR <<< "${PATCHES[$i]}"
    PATCH_PATH="${SCRIPT_DIR}/${PATCH_FILE}"
    
    idx=$((i+1))
    echo -e "${BLUE}[${idx}/${TOTAL}]${NC} 应用 ${YELLOW}${PATCH_FILE}${NC}"
    
    # 检查patch文件是否存在
    if [[ ! -f "$PATCH_PATH" ]]; then
        echo -e "  ${RED}⚠️  Patch文件不存在：${PATCH_PATH}${NC}"
        FAILED=$((FAILED+1))
        continue
    fi
    
    # 检查文件大小
    SIZE=$(stat -f%z "$PATCH_PATH" 2>/dev/null || stat -c%s "$PATCH_PATH" 2>/dev/null || echo "0")
    echo "  📦 Patch大小：$(numfmt --to=iec $SIZE 2>/dev/null || echo "$SIZE bytes")"
    
    # 进入目录
    cd "$PATCH_DIR" || { echo -e "  ${RED}❌ 无法进入目录${NC}"; FAILED=$((FAILED+1)); continue; }
    
    # 尝试应用patch
    if git apply "$PATCH_PATH" 2>/dev/null; then
        echo -e "  ${GREEN}✅ 应用成功${NC}"
        SUCCESS=$((SUCCESS+1))
    elif patch -p1 < "$PATCH_PATH" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ 应用成功（使用patch命令）${NC}"
        SUCCESS=$((SUCCESS+1))
    else
        echo -e "  ${RED}❌ 应用失败${NC}"
        FAILED=$((FAILED+1))
        # 不中断，继续下一个patch
    fi
    
    echo ""
done

# 总结
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}应用结果：${NC}"
echo -e "  ${GREEN}✅ 成功：${SUCCESS}/${TOTAL}${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "  ${RED}❌ 失败：${FAILED}/${TOTAL}${NC}"
fi
echo ""

# 显示修改统计
cd "$FRIDA_BUILD_DIR"
echo -e "${BLUE}📊 修改统计：${NC}"
echo ""

echo "主仓库改动："
git status --short | head -5
MAIN_COUNT=$(git status --porcelain | wc -l)
if [[ $MAIN_COUNT -gt 5 ]]; then
    echo "  ... 及 $((MAIN_COUNT - 5)) 个文件"
fi
echo ""

echo "frida-core子模块改动："
cd subprojects/frida-core && git status --short | head -5
CORE_COUNT=$(git status --porcelain | wc -l)
if [[ $CORE_COUNT -gt 5 ]]; then
    echo "  ... 及 $((CORE_COUNT - 5)) 个文件"
fi
cd ../..
echo ""

echo "frida-gum子模块改动："
cd subprojects/frida-gum && git status --short | head -5
GUM_COUNT=$(git status --porcelain | wc -l)
if [[ $GUM_COUNT -gt 5 ]]; then
    echo "  ... 及 $((GUM_COUNT - 5)) 个文件"
fi
cd ../..
echo ""

echo "frida-tools子模块改动："
cd subprojects/frida-tools && git status --short | head -5
TOOLS_COUNT=$(git status --porcelain | wc -l)
if [[ $TOOLS_COUNT -gt 5 ]]; then
    echo "  ... 及 $((TOOLS_COUNT - 5)) 个文件"
fi
echo ""

echo -e "${GREEN}✨ Patch应用完成！${NC}"
echo ""
echo -e "${BLUE}📝 下一步：${NC}"
echo "   1. 查看详细改动：git status"
echo "   2. 运行构建：bash ${SCRIPT_DIR}/dev.sh"
echo ""

if [[ $FAILED -eq 0 ]]; then
    exit 0
else
    exit 1
fi

