#!/bin/bash
set -euo pipefail

HELPER_NAME="com.caffeine.Caffeine.PowerHelper"
HELPER_SRC="${SRCROOT}/PowerHelper/main.swift"
PROTO_SRC="${SRCROOT}/caffeine/PowerHelperProtocol.swift"
HELPER_DST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/MacOS/${HELPER_NAME}"
PLIST_SRC="${SRCROOT}/PowerHelper/com.caffeine.Caffeine.PowerHelper.plist"
PLIST_DST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Library/LaunchDaemons/com.caffeine.Caffeine.PowerHelper.plist"

SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
TARGET=$(clang -print-target-triple 2>/dev/null || echo "arm64-apple-macosx14.0")

# Debug 构建时给 helper 也定义 DEBUG,使其 #if !DEBUG 失效，跳过 XPC 连接的
# 代码签名校验——与主 app(Debug 同样跳过)保持一致。本地 ad-hoc 签名下，
# app 与 helper 的签名标识/团队不一致，开启校验会导致 XPC 握手被拒。
# Release 构建保持启用校验，依赖正式 Developer ID 签名。
DEBUG_FLAGS=()
if [ "${CONFIGURATION:-}" = "Debug" ]; then
  DEBUG_FLAGS+=(-D DEBUG)
fi

echo "🔨 Building PowerHelper (${CONFIGURATION:-unknown})..."
mkdir -p "$(dirname "${HELPER_DST}")"
swiftc -o "${HELPER_DST}" "${HELPER_SRC}" "${PROTO_SRC}" \
  -sdk "${SDK_PATH}" \
  -target "${TARGET}" \
  -O \
  -parse-as-library \
  -suppress-warnings \
  ${DEBUG_FLAGS[@]+"${DEBUG_FLAGS[@]}"}
echo "   -> ${HELPER_DST}"

# Ad-hoc sign the helper (required for SMAppService)
codesign --force --sign - "${HELPER_DST}"

echo "📋 Copying LaunchDaemon plist..."
mkdir -p "$(dirname "${PLIST_DST}")"
cp "${PLIST_SRC}" "${PLIST_DST}"
echo "   -> ${PLIST_DST}"

echo "✅ PowerHelper embedded"
