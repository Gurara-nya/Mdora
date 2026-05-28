#!/bin/bash
# =============================================================
#  Mdora — 一键打包并启动脚本
#  用法: ./build.sh [--no-launch] [--debug]
# =============================================================

set -euo pipefail

# ---------- 颜色 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------- 默认参数 ----------
LAUNCH=true
CONFIGURATION="release"

for arg in "$@"; do
  case $arg in
    --no-launch) LAUNCH=false ;;
    --debug)     CONFIGURATION="debug" ;;
  esac
done

# ---------- 路径 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/arm64-apple-macosx/$CONFIGURATION"
DIST_DIR="$SCRIPT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Mdora.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     Mdora 一键打包脚本           ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════╝${NC}"
echo ""

# ---------- 1. 编译 ----------
echo -e "${YELLOW}▶ 步骤 1/3  Swift 编译 (${CONFIGURATION})...${NC}"
cd "$SCRIPT_DIR"
swift build -c "$CONFIGURATION" 2>&1 | sed 's/^/  /'
echo -e "${GREEN}  ✓ 编译完成${NC}"
echo ""

# ---------- 2. 组装 .app bundle ----------
echo -e "${YELLOW}▶ 步骤 2/3  组装 Mdora.app ...${NC}"

# 清理旧 bundle
rm -rf "$APP_BUNDLE"

# 创建目录结构
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 复制可执行文件
cp "$BUILD_DIR/Mdora" "$MACOS_DIR/Mdora"
chmod +x "$MACOS_DIR/Mdora"

# 写入 Info.plist（如果项目根目录有就直接复制，否则内联生成）
PLIST_SRC="$SCRIPT_DIR/Info.plist"
if [ -f "$PLIST_SRC" ]; then
  cp "$PLIST_SRC" "$INFO_PLIST"
else
  cat > "$INFO_PLIST" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
                <string>mdown</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.plain-text</string>
            </array>
        </dict>
    </array>
    <key>CFBundleExecutable</key>
    <string>Mdora</string>
    <key>CFBundleIdentifier</key>
    <string>dev.gurara.mdora</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Mdora</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST
fi

# 写入 PkgInfo
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# 移除隔离属性（防止 macOS Gatekeeper 弹出未知开发者警告）
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

echo -e "${GREEN}  ✓ App bundle 已生成: ${APP_BUNDLE}${NC}"

# 显示打包结果信息
BINARY_SIZE=$(du -sh "$MACOS_DIR/Mdora" | cut -f1)
echo -e "  📦 可执行文件大小: ${BOLD}${BINARY_SIZE}${NC}"
echo ""

# ---------- 3. 启动 ----------
if [ "$LAUNCH" = true ]; then
  echo -e "${YELLOW}▶ 步骤 3/3  启动 Mdora.app ...${NC}"
  open "$APP_BUNDLE"
  echo -e "${GREEN}  ✓ 已启动！${NC}"
else
  echo -e "${YELLOW}  ℹ️  跳过启动 (--no-launch)${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}✅ 全部完成！${NC}"
echo -e "   App 路径: ${CYAN}${APP_BUNDLE}${NC}"
echo ""
