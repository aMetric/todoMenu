#!/bin/bash
# 一键构建 TodoMenu.app（无需 Xcode）
# 用法：./scripts/bundle.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="TodoMenu"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

echo "==> 编译 release 版本..."
swift build -c release --disable-sandbox

BIN_DIR="$(swift build -c release --show-bin-path --disable-sandbox)"
echo "==> 打包 ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>TodoMenu</string>
	<key>CFBundleDisplayName</key>
	<string>TodoMenu</string>
	<key>CFBundleIdentifier</key>
	<string>com.todomenu.app</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleExecutable</key>
	<string>TodoMenu</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>MIT License</string>
</dict>
</plist>
PLIST

echo "==> 签名（ad-hoc，本机可用）..."
codesign --force --sign - "${APP_DIR}"

echo ""
echo "✅ 完成：${APP_DIR}"
echo "   启动：open ${APP_DIR}"
echo "   数据：~/Library/Application Support/TodoMenu/todos.json"
