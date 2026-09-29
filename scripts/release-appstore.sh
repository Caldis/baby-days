#!/bin/zsh
# 构建 iOS 与 tvOS 版本并上传到 App Store Connect, 上传后出现在 TestFlight, 可直接用于提交审核
# 用法: scripts/release-appstore.sh [ios|tvos|all]
# 签名使用 Xcode 中已登录的开发者账号 (云端管理的 Apple Distribution 证书); 版本号取 project.yml 的 MARKETING_VERSION
set -euo pipefail
ROOT=${0:A:h:h}
cd "$ROOT"

TARGET=${1:-all}
WORK=$HOME/Library/Caches/baby-days/appstore
BUILD_NUMBER=$(date +%Y%m%d%H%M)
VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)

fail() { echo "$1" >&2; exit 1; }

case $TARGET in
  ios) PLATFORMS=(iOS) ;;
  tvos) PLATFORMS=(tvOS) ;;
  all) PLATFORMS=(iOS tvOS) ;;
  *) fail "用法: scripts/release-appstore.sh [ios|tvos|all]" ;;
esac
git diff --quiet && git diff --cached --quiet || fail "工作区有未提交的改动"
if command -v xcodegen >/dev/null; then
  xcodegen generate --quiet
fi

rm -rf "$WORK"
mkdir -p "$WORK"
cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>N7Z52F27XK</string>
</dict>
</plist>
PLIST

for PLATFORM in $PLATFORMS; do
  ARCHIVE=$WORK/$PLATFORM.xcarchive
  echo "归档 $PLATFORM $VERSION ($BUILD_NUMBER)"
  if ! LOG=$(xcodebuild archive -project BabyDays.xcodeproj -scheme "BabyDays-$PLATFORM" -configuration Release \
    -destination "generic/platform=$PLATFORM" -archivePath "$ARCHIVE" -derivedDataPath "$WORK/DerivedData" \
    -allowProvisioningUpdates CURRENT_PROJECT_VERSION=$BUILD_NUMBER 2>&1); then
    print -r -- "$LOG" | grep -E "error" || print -r -- "$LOG" | tail -20
    fail "$PLATFORM 归档失败"
  fi

  echo "上传 $PLATFORM 到 App Store Connect"
  # 云端签名偶尔返回空结果, 重试即可
  for attempt in {1..3}; do
    if LOG=$(xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$WORK/ExportOptions.plist" \
      -exportPath "$WORK/$PLATFORM-export" -allowProvisioningUpdates 2>&1); then
      break
    fi
    if (( attempt == 3 )); then
      print -r -- "$LOG" | grep -E "error" || print -r -- "$LOG" | tail -20
      fail "$PLATFORM 上传失败"
    fi
    sleep 10
  done
done

rm -rf "$WORK"
echo "已上传 $VERSION ($BUILD_NUMBER), App Store Connect 处理完成后在 TestFlight 中可见"
