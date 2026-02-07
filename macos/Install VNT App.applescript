-- VNT App 安装助手
-- 用于移除 macOS 的隔离属性

-- 显示欢迎对话框
set welcomeMessage to "欢迎使用 VNT App 安装助手！

此工具将帮助您：
1. 将 VNT App 安装到应用程序文件夹
2. 移除 macOS 的隔离属性，确保应用正常运行

点击"继续"开始安装。"

set userChoice to button returned of (display dialog welcomeMessage buttons {"取消", "继续"} default button "继续" with icon note with title "VNT App 安装助手")

if userChoice is "取消" then
	return
end if

-- 获取当前脚本所在目录（DMG 挂载点）
tell application "Finder"
	set dmgPath to container of (path to me) as text
end tell

-- 应用名称
set appName to "VNT App.app"
set sourcePath to dmgPath & appName
set destPath to "/Applications/" & appName

-- 检查源应用是否存在
tell application "System Events"
	if not (exists folder sourcePath) then
		display dialog "错误：找不到 VNT App.app

请确保此脚本与 VNT App.app 在同一目录中。" buttons {"确定"} default button "确定" with icon stop with title "安装错误"
		return
	end if
end tell

-- 复制应用到 Applications 文件夹
try
	display dialog "正在将 VNT App 复制到应用程序文件夹..." buttons {"确定"} default button "确定" giving up after 2 with title "安装中"

	-- 如果目标已存在，先删除
	tell application "System Events"
		if exists folder destPath then
			do shell script "rm -rf " & quoted form of destPath with administrator privileges
		end if
	end tell

	-- 复制应用
	do shell script "cp -R " & quoted form of POSIX path of sourcePath & " /Applications/" with administrator privileges

on error errMsg
	display dialog "复制应用失败：" & errMsg buttons {"确定"} default button "确定" with icon stop with title "安装错误"
	return
end try

-- 移除隔离属性
try
	display dialog "正在移除隔离属性...

macOS 会阻止从互联网下载的应用运行。
我们需要移除隔离属性以允许应用正常运行。

即将弹出密码输入框，请输入您的管理员密码。" buttons {"确定"} default button "确定" giving up after 3 with title "安装中"

	-- 使用 with administrator privileges 会弹出系统密码框
	do shell script "xattr -cr '/Applications/" & appName & "'" with administrator privileges

	-- 安装成功
	display dialog "✓ 安装完成！

VNT App 已成功安装到应用程序文件夹。
隔离属性已移除，您现在可以正常使用了。

应用位置：/Applications/" & appName buttons {"打开应用", "完成"} default button "打开应用" with icon note with title "安装成功"

	if button returned of result is "打开应用" then
		tell application "VNT App" to activate
	end if

on error errMsg
	if errMsg contains "User canceled" then
		display dialog "安装已取消。

您可以稍后手动执行以下命令来移除隔离属性：
  sudo xattr -cr '/Applications/" & appName & "'" buttons {"确定"} default button "确定" with icon caution with title "安装取消"
	else
		display dialog "移除隔离属性失败：" & errMsg & "

您可以手动执行以下命令：
  sudo xattr -cr '/Applications/" & appName & "'" buttons {"确定"} default button "确定" with icon stop with title "安装错误"
	end if
end try
