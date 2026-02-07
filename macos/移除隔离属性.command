#!/bin/bash

# VNT App - 移除隔离属性脚本
# 此脚本用于移除从互联网下载的应用的隔离属性，避免"无法验证开发者"错误

APP_PATH="/Applications/VNT App.app"

echo "=========================================="
echo "  VNT App - 移除隔离属性"
echo "=========================================="
echo ""

# 检查应用是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 错误：未找到应用"
    echo ""
    echo "请先将 VNT App 拖动到 Applications 文件夹"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

echo "📍 应用位置: $APP_PATH"
echo ""

# 检查是否有隔离属性
if xattr "$APP_PATH" 2>/dev/null | grep -q "com.apple.quarantine"; then
    echo "⚠️  检测到隔离属性，正在移除..."
    echo ""
    echo "💡 此操作需要管理员权限，请输入密码"
    echo ""

    # 移除隔离属性
    if sudo xattr -cr "$APP_PATH"; then
        echo ""
        echo "✅ 隔离属性已成功移除！"
        echo ""
        echo "🎉 现在可以正常启动 VNT App 了"
        echo ""
        echo "首次启动时会要求输入管理员密码（用于创建 TUN 设备）"
        echo "授权后，后续使用将完全无感"
    else
        echo ""
        echo "❌ 移除失败"
        echo ""
        echo "请手动执行以下命令："
        echo "sudo xattr -cr \"$APP_PATH\""
    fi
else
    echo "✅ 应用没有隔离属性，无需处理"
    echo ""
    echo "🎉 可以直接启�� VNT App"
fi

echo ""
echo "=========================================="
echo ""
read -p "按回车键退出..."
