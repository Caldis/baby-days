#!/bin/zsh
# 离线渲染小组件效果图与图标图层
# 用法: scripts/render.sh snapshots [输出目录]  全部场景的检查图, 默认输出到 .build/snapshots
#      scripts/render.sh docs [输出目录]       README 配图, 默认输出到 docs/images
#      scripts/render.sh icon [输出目录]       图标图层, 默认输出到 Resources/AppIcon.icon
#      scripts/render.sh tv [输出目录]         Apple TV 图标, 顶部栏静态图与小蛇图片, 默认输出到 Resources
#      scripts/render.sh appstore [输出目录]   App Store 截图, 默认输出到 .build/app-store
set -euo pipefail
ROOT=${0:A:h:h}
mkdir -p "$ROOT/.build"
swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos14 \
  "$ROOT"/Shared/*.swift "$ROOT"/TVShared/*.swift "$ROOT"/Tools/Render/*.swift \
  -o "$ROOT/.build/render"
MODE=${1:-snapshots}
case $MODE in
  icon) OUT=${2:-$ROOT/Resources/AppIcon.icon} ;;
  docs) OUT=${2:-$ROOT/docs/images} ;;
  tv) OUT=${2:-$ROOT/Resources} ;;
  appstore) OUT=${2:-$ROOT/.build/app-store} ;;
  *) OUT=${2:-$ROOT/.build/snapshots} ;;
esac
"$ROOT/.build/render" "$ROOT" "$MODE" "$OUT"
