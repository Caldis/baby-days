#!/bin/zsh
# 构建 iOS, tvOS 与 Mac App Store 版本并上传到 App Store Connect, 上传后出现在 TestFlight, 可直接用于提交审核
# 用法: scripts/release-appstore.sh [ios|tvos|macos|all]
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
  macos) PLATFORMS=(macOS) ;;
  all) PLATFORMS=(iOS tvOS macOS) ;;
  *) fail "用法: scripts/release-appstore.sh [ios|tvos|macos|all]" ;;
esac
[[ -z $(git status --porcelain) ]] || fail "工作区有未提交的改动"
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
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST

# tvOS 归档用的临时权限文件: 团队中没有登记 Apple TV 设备, 无法生成 tvOS 开发描述文件,
# 因此 tvOS 以不签名方式归档, 再用本文件做临时签名写入 App Group 权限, 导出时由云端证书重新签名并保留权限
cat > "$WORK/tvos.entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.ubiquity-kvstore-identifier</key>
	<string>N7Z52F27XK.com.caldis.babydays</string>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.caldis.babydays</string>
	</array>
</dict>
</plist>
PLIST

# 导出前检查 App 与扩展, 避免云端重签名时因归档缺少权限而丢失 App Group 或跨平台 KVS
verify_entitlements() {
  local bundle=$1 platform=$2 expected_group=group.com.caldis.babydays
  [[ $platform == macOS ]] && expected_group=N7Z52F27XK.com.caldis.babydays
  codesign -d --entitlements :- "$bundle" > "$WORK/check-entitlements.plist" 2>/dev/null
  python3 - "$WORK/check-entitlements.plist" "$expected_group" "$bundle" "$platform" <<'PY'
import pathlib, plistlib, sys
with open(sys.argv[1], "rb") as source:
    entitlements = plistlib.load(source)
assert entitlements.get("com.apple.developer.ubiquity-kvstore-identifier") == "N7Z52F27XK.com.caldis.babydays", "归档缺少共享 iCloud KVS 权限"
assert sys.argv[2] in entitlements.get("com.apple.security.application-groups", []), "归档缺少 App Group 权限"
bundle = pathlib.Path(sys.argv[3])
info_path = bundle / ("Contents/Info.plist" if sys.argv[4] == "macOS" else "Info.plist")
with info_path.open("rb") as source:
    info = plistlib.load(source)
assert info.get("BabyDaysAppGroup") == sys.argv[2], "App Group 读取配置与签名权限不一致"
if sys.argv[4] == "iOS":
    assert set(info.get("UIDeviceFamily", [])) == {1, 2}, "iOS App 与扩展均须支持 iPhone 和 iPad"
PY
}

# 注销本次 Mac 副本, 避免系统在 /Applications 之外选中其小组件扩展
unregister_mac_copies() {
  local copy register=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  for copy in "$WORK/macOS.xcarchive/Products/Applications/BabyDays.app" "$WORK/DerivedData/Build/Products/Release/BabyDays.app"; do
    [[ -d $copy ]] || continue
    pluginkit -r "$copy/Contents/PlugIns/BabyDaysWidget.appex" 2>/dev/null || true
    "$register" -u "$copy" 2>/dev/null || true
  done
}
trap unregister_mac_copies EXIT

for PLATFORM in $PLATFORMS; do
  ARCHIVE=$WORK/$PLATFORM.xcarchive
  # Mac App Store 使用不含 Sparkle 的独立 target
  SCHEME=BabyDays-$PLATFORM
  [[ $PLATFORM == macOS ]] && SCHEME=BabyDays-macOS-AppStore
  SIGNING=(-allowProvisioningUpdates)
  [[ $PLATFORM == tvOS ]] && SIGNING=(CODE_SIGNING_ALLOWED=NO)
  echo "归档 $PLATFORM $VERSION ($BUILD_NUMBER)"
  if ! LOG=$(xcodebuild archive -project BabyDays.xcodeproj -scheme "$SCHEME" -configuration Release \
    -destination "generic/platform=$PLATFORM" -archivePath "$ARCHIVE" -derivedDataPath "$WORK/DerivedData" \
    $SIGNING CURRENT_PROJECT_VERSION=$BUILD_NUMBER 2>&1); then
    print -r -- "$LOG" | grep -E "error" || print -r -- "$LOG" | tail -20
    fail "$PLATFORM 归档失败"
  fi
  if [[ $PLATFORM == tvOS ]]; then
    APP=$ARCHIVE/Products/Applications/BabyDays.app
    codesign -f -s - --entitlements "$WORK/tvos.entitlements" "$APP/PlugIns/BabyDaysTopShelf.appex"
    codesign -f -s - --entitlements "$WORK/tvos.entitlements" "$APP"
  fi
  APP=$ARCHIVE/Products/Applications/BabyDays.app
  EXTENSIONS=$APP/PlugIns
  [[ $PLATFORM == macOS ]] && EXTENSIONS=$APP/Contents/PlugIns
  verify_entitlements "$APP" "$PLATFORM"
  for EXTENSION in "$EXTENSIONS"/*.appex; do
    verify_entitlements "$EXTENSION" "$PLATFORM"
  done
done

for PLATFORM in $PLATFORMS; do
  ARCHIVE=$WORK/$PLATFORM.xcarchive
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

unregister_mac_copies
rm -rf "$WORK"
echo "已上传 $VERSION ($BUILD_NUMBER), App Store Connect 处理完成后在 TestFlight 中可见"
