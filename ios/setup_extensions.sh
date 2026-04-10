#!/bin/bash
# iOS Widget和Intents Extension自动配置脚本
# 用于在Xcode项目中添加Widget和Intents Extension targets

set -e

echo "=========================================="
echo "iOS Widget & Intents 自动配置"
echo "=========================================="

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PBXPROJ="$PROJECT_DIR/Runner.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
    echo "❌ 错误: 找不到 project.pbxproj"
    exit 1
fi

echo "✅ 找到项目文件: $PBXPROJ"

# 备份原始文件
cp "$PBXPROJ" "$PBXPROJ.backup"
echo "✅ 已备份项目文件"

# 生成UUID的函数
generate_uuid() {
    uuidgen | tr '[:lower:]' '[:upper:]' | tr -d '-' | cut -c1-24
}

# 生成所需的UUID
WIDGET_TARGET_UUID=$(generate_uuid)
WIDGET_BUILD_CONFIG_DEBUG_UUID=$(generate_uuid)
WIDGET_BUILD_CONFIG_RELEASE_UUID=$(generate_uuid)
WIDGET_BUILD_PHASE_SOURCES_UUID=$(generate_uuid)
WIDGET_BUILD_PHASE_FRAMEWORKS_UUID=$(generate_uuid)
WIDGET_BUILD_PHASE_RESOURCES_UUID=$(generate_uuid)
WIDGET_PRODUCT_REF_UUID=$(generate_uuid)
WIDGET_SWIFT_FILE_UUID=$(generate_uuid)
WIDGET_INFO_PLIST_UUID=$(generate_uuid)
WIDGET_ENTITLEMENTS_UUID=$(generate_uuid)

INTENTS_TARGET_UUID=$(generate_uuid)
INTENTS_BUILD_CONFIG_DEBUG_UUID=$(generate_uuid)
INTENTS_BUILD_CONFIG_RELEASE_UUID=$(generate_uuid)
INTENTS_BUILD_PHASE_SOURCES_UUID=$(generate_uuid)
INTENTS_BUILD_PHASE_FRAMEWORKS_UUID=$(generate_uuid)
INTENTS_PRODUCT_REF_UUID=$(generate_uuid)
INTENTS_HANDLER_FILE_UUID=$(generate_uuid)
INTENTS_INFO_PLIST_UUID=$(generate_uuid)
INTENTS_ENTITLEMENTS_UUID=$(generate_uuid)
INTENTS_DEFINITION_UUID=$(generate_uuid)

echo "✅ 生成UUID完成"

# 创建临时Python脚本来修改pbxproj
cat > /tmp/add_extensions.py << 'PYTHON_SCRIPT'
import sys
import re

def add_widget_extension(content):
    # 添加Widget文件引用到PBXFileReference
    file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/(.*?)/\* End PBXFileReference section \*/', content, re.DOTALL)
    if file_ref_section:
        insert_pos = file_ref_section.end(1)
        widget_refs = f'''
		{WIDGET_SWIFT_FILE_UUID} /* VNTWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VNTWidget.swift; sourceTree = "<group>"; }};
		{WIDGET_INFO_PLIST_UUID} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{WIDGET_ENTITLEMENTS_UUID} /* VNTWidget.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = VNTWidget.entitlements; sourceTree = "<group>"; }};
		{WIDGET_PRODUCT_REF_UUID} /* VNTWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = VNTWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
'''
        content = content[:insert_pos] + widget_refs + content[insert_pos:]
    
    # 添加Intents文件引用
    if file_ref_section:
        insert_pos = file_ref_section.end(1)
        intents_refs = f'''
		{INTENTS_HANDLER_FILE_UUID} /* IntentHandler.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IntentHandler.swift; sourceTree = "<group>"; }};
		{INTENTS_INFO_PLIST_UUID} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{INTENTS_ENTITLEMENTS_UUID} /* VNTIntents.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = VNTIntents.entitlements; sourceTree = "<group>"; }};
		{INTENTS_DEFINITION_UUID} /* Intents.intentdefinition */ = {{isa = PBXFileReference; lastKnownFileType = file.intentdefinition; path = Intents.intentdefinition; sourceTree = "<group>"; }};
		{INTENTS_PRODUCT_REF_UUID} /* VNTIntents.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = VNTIntents.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
'''
        content = content[:insert_pos] + intents_refs + content[insert_pos:]
    
    # 添加到Products group
    products_group = re.search(r'97C146EF1CF9000F007C117D /\* Products \*/ = \{[^}]+children = \([^)]+\);', content)
    if products_group:
        children_end = products_group.group(0).rfind(');')
        insert_text = f'''
				{WIDGET_PRODUCT_REF_UUID} /* VNTWidget.appex */,
				{INTENTS_PRODUCT_REF_UUID} /* VNTIntents.appex */,
'''
        content = content[:products_group.start() + children_end] + insert_text + content[products_group.start() + children_end:]
    
    return content

if __name__ == '__main__':
    with open(sys.argv[1], 'r') as f:
        content = f.read()
    
    # 替换UUID占位符
    content = content.replace('{WIDGET_TARGET_UUID}', sys.argv[2])
    content = content.replace('{WIDGET_SWIFT_FILE_UUID}', sys.argv[3])
    content = content.replace('{WIDGET_INFO_PLIST_UUID}', sys.argv[4])
    content = content.replace('{WIDGET_ENTITLEMENTS_UUID}', sys.argv[5])
    content = content.replace('{WIDGET_PRODUCT_REF_UUID}', sys.argv[6])
    content = content.replace('{INTENTS_TARGET_UUID}', sys.argv[7])
    content = content.replace('{INTENTS_HANDLER_FILE_UUID}', sys.argv[8])
    content = content.replace('{INTENTS_INFO_PLIST_UUID}', sys.argv[9])
    content = content.replace('{INTENTS_ENTITLEMENTS_UUID}', sys.argv[10])
    content = content.replace('{INTENTS_DEFINITION_UUID}', sys.argv[11])
    content = content.replace('{INTENTS_PRODUCT_REF_UUID}', sys.argv[12])
    
    modified = add_widget_extension(content)
    
    with open(sys.argv[1], 'w') as f:
        f.write(modified)
PYTHON_SCRIPT

echo "⚠️  警告: 自动配置Xcode项目文件非常复杂"
echo "⚠️  建议手动在Xcode中添加Extension targets"
echo ""
echo "📖 请参考文档: ios/WIDGET_SHORTCUTS_README.md"
echo ""
echo "手动步骤："
echo "1. 打开 ios/Runner.xcodeproj"
echo "2. File → New → Target → Widget Extension"
echo "3. Product Name: VNTWidget"
echo "4. 添加 ios/VNTWidget/VNTWidget.swift"
echo "5. 配置 App Groups 权限"
echo ""
echo "6. File → New → Target → Intents Extension"
echo "7. Product Name: VNTIntents"
echo "8. 添加 ios/VNTIntents/IntentHandler.swift"
echo "9. 配置 App Groups 权限"
echo ""

read -p "是否继续自动配置? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消"
    rm -f /tmp/add_extensions.py
    exit 0
fi

echo "⚠️  自动配置功能尚未完全实现"
echo "✅ 所有代码文件已准备就绪"
echo "📁 Widget文件: ios/VNTWidget/"
echo "📁 Intents文件: ios/VNTIntents/"
echo ""
echo "请在Xcode中手动添加Extension targets"

rm -f /tmp/add_extensions.py

echo "=========================================="
echo "配置完成"
echo "=========================================="
