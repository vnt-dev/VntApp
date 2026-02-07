#!/bin/bash

# VNT App 安装脚本
# 用于移除 macOS 的隔离属性（quarantine attribute）

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "================================================"
echo "  VNT App 安装向导"
echo "================================================"
echo ""

# 检查是否在 macOS 上运行
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}错误：此脚本只能在 macOS 上运行${NC}"
    exit 1
fi

# 获取应用路径
APP_NAME="VNT App.app"
INSTALL_PATH="/Applications/$APP_NAME"

# 检查应用是否存在于 /Applications
if [ ! -d "$INSTALL_PATH" ]; then
    echo -e "${YELLOW}提示：请先将 VNT App 拖动到 Applications 文件夹${NC}"
    echo ""
    echo "步骤："
    echo "1. 将 'VNT App' 拖动到 'Applications' 文件夹"
    echo "2. 然后再次运行此安装脚本"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

echo -e "${GREEN}✓${NC} 找到应用：$INSTALL_PATH"
echo ""

# 检查是否有隔离属性
echo "正在检查隔离属性..."
if xattr "$INSTALL_PATH" | grep -q "com.apple.quarantine"; then
    echo -e "${YELLOW}⚠ 检测到隔离属性，需要移除${NC}"
    echo ""
    echo "macOS 会阻止从互联网下载的应用运行。"
    echo "我们需要移除隔离属性以允许应用正常运行。"
    echo ""
    echo -e "${YELLOW}即将弹出密码输入框，请输入您的管理员密码。${NC}"
    echo ""

    # 使用 osascript 弹出密码框并执行命令
    # 这会显示系统原生的管理员密码对话框
    osascript -e "do shell script \"xattr -cr '$INSTALL_PATH'\" with administrator privileges" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} 隔离属性已成功移除"
        echo ""
        echo -e "${GREEN}安装完成！${NC}"
        echo ""
        echo "您现在可以正常使用 VNT App 了。"
        echo "应用位置：$INSTALL_PATH"
    else
        echo -e "${RED}✗${NC} 移除隔离属性失败"
        echo ""
        echo "您可以手动执行以下命令："
        echo "  sudo xattr -cr '$INSTALL_PATH'"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} 未检测到隔离属性，无需处理"
    echo ""
    echo -e "${GREEN}应用已准备就绪！${NC}"
fi

echo ""
echo "================================================"
echo ""
read -p "按回车键退出..."
