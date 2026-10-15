#!/bin/bash
# 一键构建 TodoMenu.app（无需 Xcode）
# 用法：./scripts/bundle.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="TodoMenu"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

echo "==> 编译 release 版本（Universal：arm64 + x86_64）..."
swift build -c release --arch arm64 --scratch-path .build-arm64 --disable-sandbox
swift build -c release --arch x86_64 --scratch-path .build-x86_64 --disable-sandbox

ARM64_BIN="$(swift build -c release --arch arm64 --scratch-path .build-arm64 --show-bin-path --disable-sandbox)/${APP_NAME}"
X86_64_BIN="$(swift build -c release --arch x86_64 --scratch-path .build-x86_64 --show-bin-path --disable-sandbox)/${APP_NAME}"

echo "==> 打包 ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
echo "==> 合并为 Universal 二进制..."
lipo -create -output "${APP_DIR}/Contents/MacOS/${APP_NAME}" "${ARM64_BIN}" "${X86_64_BIN}"

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
	<string>2</string>
	<key>CFBundleShortVersionString</key>
	<string>0.2.0</string>
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
echo "✅ 完成：${APP_DIR}（Universal：Apple Silicon + Intel，macOS 14+）"
echo "   启动：open ${APP_DIR}"
echo "   数据：~/Library/Application Support/TodoMenu/todos.json"
