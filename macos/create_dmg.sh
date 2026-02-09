#!/bin/bash
set -e

# DMG 创建脚本 - 带背景图和优化布局
APP_PATH="$1"
DMG_PATH="$2"
APP_NAME="vnt_app"
VOLUME_NAME="VNT App"

# 临时目录
TMP_DMG="tmp.dmg"
MOUNT_DIR="/Volumes/$VOLUME_NAME"

echo "创建 DMG 安装包..."
echo "应用路径: $APP_PATH"
echo "输出路径: $DMG_PATH"

# 创建临时可读写 DMG (600MB)
hdiutil create -size 600m -fs HFS+ -volname "$VOLUME_NAME" "$TMP_DMG"

# 挂载 DMG
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_DIR"

# 复制应用
echo "复制应用..."
cp -R "$APP_PATH" "$MOUNT_DIR/"

# 复制安装说明
if [ -f "macos/安装说明.html" ]; then
    echo "复制安装说明..."
    cp "macos/安装说明.html" "$MOUNT_DIR/"
fi

# 创建 Applications 快捷方式
echo "创建 Applications 快捷方式..."
ln -s /Applications "$MOUNT_DIR/Applications"

# 创建隐藏的 .background 目录
mkdir -p "$MOUNT_DIR/.background"

# 创建背景图
echo "创建背景图..."
cp "macos/dmg_background.png" "$MOUNT_DIR/.background/background.png"

# 设置窗口属性和图标位置
echo "设置窗口属性..."
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set background picture of viewOptions to file ".background:background.png"

        -- 获取窗口宽高
        set winBounds to the bounds of container window
        set winWidth to item 3 of winBounds - item 1 of winBounds
        set winHeight to item 4 of winBounds - item 2 of winBounds

        -- 上方两个图标纵向位置（窗口高度约35%，较小的y值靠上）
        set yTop to winHeight * 0.35
        -- 下方图标纵向位置（窗口高度约65%，较大的y值靠下）
        set yBottom to winHeight * 0.65

        -- 上方两个图标横向对称
        set xLeft to winWidth * 0.25
        set xRight to winWidth * 0.75

        -- 下方中间图标横向居中
        set xCenter to winWidth * 0.5

        -- 设置位置（上面左右两个，下面中间一个）
        set position of item "$APP_NAME.app" of container window to {xLeft, yTop}
        set position of item "Applications" of container window to {xRight, yTop}
        set position of item "安装说明.html" of container window to {xCenter, yBottom}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# 同步并卸载
echo "同步文件系统..."
sync
sleep 2

echo "卸载 DMG..."
hdiutil detach "$MOUNT_DIR"

# 转换为压缩的只读 DMG
echo "压缩 DMG..."
hdiutil convert "$TMP_DMG" -format UDBZ -o "$DMG_PATH"

# 清理临时文件
rm -f "$TMP_DMG"

echo "DMG 创建完成: $DMG_PATH"
ls -lh "$DMG_PATH"
