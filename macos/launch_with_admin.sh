#!/bin/bash
# VNT macOS 管理员权限启动脚本
# 使用方法：双击此脚本，或在终端运行 ./launch_with_admin.sh

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 查找 VNT.app 的路径
# 优先查找 build/macos/Build/Products/Release/vnt_app.app
APP_PATH="$SCRIPT_DIR/../build/macos/Build/Products/Release/vnt_app.app"

if [ ! -d "$APP_PATH" ]; then
    # 如果 Release 版本不存在，尝试 Debug 版本
    APP_PATH="$SCRIPT_DIR/../build/macos/Build/Products/Debug/vnt_app.app"
fi

if [ ! -d "$APP_PATH" ]; then
    # 如果都不存在，尝试在 /Applications 中查找
    APP_PATH="/Applications/vnt_app.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "错误：找不到 VNT.app"
    echo "请确保应用已经编译或安装到 /Applications 目录"
    exit 1
fi

# 获取可执行文件路径
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/vnt_app"

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "错误：找不到可执行文件 $EXECUTABLE_PATH"
    exit 1
fi

echo "正在以管理员权限启动 VNT..."
echo "应用路径: $APP_PATH"

# 使用 osascript 请求管理员权限并启动
osascript -e "do shell script \"\\\"$EXECUTABLE_PATH\\\" > /dev/null 2>&1 &\" with administrator privileges"

if [ $? -eq 0 ]; then
    echo "✓ VNT 已以管理员权限启动"
else
    echo "✗ 启动失败或用户取消"
    exit 1
fi
