#!/bin/zsh
# 构建 Release 版 macOS App 并安装到 /Applications, 首次打开后桌面小组件库即可搜到「宝宝多大」
set -euo pipefail
ROOT=${0:A:h:h}
cd "$ROOT"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
DERIVED=$HOME/Library/Caches/baby-days/DerivedData
if command -v xcodegen >/dev/null; then
  xcodegen generate --quiet
fi
# 每次安装使用新的构建号, 系统据此丢弃旧版本缓存的小组件画面
BUILD_NUMBER=$(date +%Y%m%d%H%M)
if ! LOG=$(xcodebuild -project BabyDays.xcodeproj -scheme BabyDays-macOS -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION=$BUILD_NUMBER build 2>&1); then
  print -r -- "$LOG" | grep -E "error" || print -r -- "$LOG" | tail -20
  echo "构建失败"
  exit 1
fi
APP=$DERIVED/Build/Products/Release/BabyDays.app
osascript -e 'quit app "BabyDays"' 2>/dev/null || true
while pgrep -x BabyDays >/dev/null; do sleep 0.5; done
rm -rf /Applications/BabyDays.app
cp -R "$APP" /Applications/
# 构建目录中的同 ID 副本会被系统选作小组件扩展并在启动时崩溃, 安装后注销并删除该副本
pluginkit -r "$APP/Contents/PlugIns/BabyDaysWidget.appex" 2>/dev/null || true
"$LSREGISTER" -u "$APP" 2>/dev/null || true
rm -rf "$APP"
"$LSREGISTER" -f /Applications/BabyDays.app
open /Applications/BabyDays.app
echo "已安装到 /Applications/BabyDays.app (构建号 $BUILD_NUMBER)"
