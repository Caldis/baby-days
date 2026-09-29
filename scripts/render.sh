#!/bin/zsh
# 离线渲染小组件效果图与图标图层
# 用法: scripts/render.sh snapshots [输出目录]  全部场景的检查图, 默认输出到 .build/snapshots
#      scripts/render.sh docs [输出目录]       README 配图, 默认输出到 docs/images
#      scripts/render.sh icon [输出目录]       图标图层, 默认输出到 Resources/AppIcon.icon
set -euo pipefail
ROOT=${0:A:h:h}
mkdir -p "$ROOT/.build"
swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos14 \
  "$ROOT"/Shared/*.swift "$ROOT"/Tools/Render/*.swift \
  -o "$ROOT/.build/render"
MODE=${1:-snapshots}
case $MODE in
  icon) OUT=${2:-$ROOT/Resources/AppIcon.icon} ;;
  docs) OUT=${2:-$ROOT/docs/images} ;;
  *) OUT=${2:-$ROOT/.build/snapshots} ;;
esac
"$ROOT/.build/render" "$ROOT" "$MODE" "$OUT"
