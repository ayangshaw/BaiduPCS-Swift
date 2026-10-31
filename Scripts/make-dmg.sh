#!/bin/bash
# 打包 Ferry 的 DMG。用法：Scripts/make-dmg.sh [版本号]
# 版本号缺省时从编译产物读取。产物输出到 build/Ferry-<版本>.dmg。
#
# 流程：编译 Release → 打包 → 清除开发副本（build/DerivedData/Build/Products），
# 避免 Spotlight 索引到第二份 Ferry.app（搜索里出现两个同样的应用）。
set -euo pipefail
cd "$(dirname "$0")/.."

DEVELOPER_DIR=/Applications/Xcode.app xcrun xcodebuild \
    -project BaiduPCS-Swift.xcodeproj -scheme BaiduPCS-Swift \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build

APP="build/DerivedData/Build/Products/Release/Ferry.app"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
DMG="build/Ferry-$VERSION.dmg"

rm -f "$DMG" build/dmg-rw.dmg
hdiutil create -size 100m -fs HFS+ -volname "Ferry" -ov build/dmg-rw.dmg > /dev/null
hdiutil attach build/dmg-rw.dmg -nobrowse -noautoopen > /dev/null
cp -R "$APP" /Volumes/Ferry/Ferry.app
ln -s /Applications /Volumes/Ferry/Applications

# 卷根目录放 .metadata_never_index：镜像挂载期间其中的应用不会被 Spotlight 索引，
# 避免“搜索到两个 Ferry”。构建输出目录（build/）也有同样的标记文件。
touch /Volumes/Ferry/.metadata_never_index

osascript <<'EOF'
tell application "Finder"
	tell disk "Ferry"
		open
		set current view of container window to icon view
		set the bounds of container window to {300, 150, 820, 460}
		set viewOptions to icon view options of container window
		set arrangement of viewOptions to not arranged
		set icon size of viewOptions to 96
		set position of item "Ferry.app" of container window to {140, 165}
		set position of item "Applications" of container window to {380, 165}
		close
		delay 1
		open
		update without registering applications
		delay 1
	end tell
end tell
EOF

sync
sleep 2
hdiutil detach /Volumes/Ferry > /dev/null
hdiutil convert build/dmg-rw.dmg -format UDZO -o "$DMG" | tail -1
rm -f build/dmg-rw.dmg
hdiutil verify "$DMG" | tail -1

# 清除开发副本：镜像已打好，磁盘上不再需要这份 Ferry.app。
rm -rf build/DerivedData/Build/Products
echo "已清除开发副本（build/DerivedData/Build/Products）。"
echo "完成：$DMG"
