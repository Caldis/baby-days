#!/bin/zsh
# 发布 macOS 新版本: Developer ID 签名, Apple 公证, 生成 Sparkle 更新清单, 通过 gh 发布到 GitHub Releases
# 用法: scripts/release-mac.sh <版本号> [更新说明]
# 签名与公证使用 Xcode 中已登录的开发者账号; 更新包签名使用 ~/.config/baby-days/sparkle_private_key
set -euo pipefail
ROOT=${0:A:h:h}
cd "$ROOT"

VERSION=${1:?用法: scripts/release-mac.sh <版本号> [更新说明]}
NOTES=${2:-}
TAG=v$VERSION
REPO=Caldis/baby-days
KEY_FILE=$HOME/.config/baby-days/sparkle_private_key
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
WORK=$HOME/Library/Caches/baby-days/release
BUILD_NUMBER=$(date +%Y%m%d%H%M)
ARCHIVE=$WORK/BabyDays.xcarchive
ZIP=$WORK/BabyDays-$VERSION.zip
DMG=$WORK/BabyDays-$VERSION.dmg

fail() { echo "$1" >&2; exit 1; }

run() {
  local log
  if ! log=$("$@" 2>&1); then
    print -r -- "$log" | grep -E "error" || print -r -- "$log" | tail -20
    exit 1
  fi
}

[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "版本号格式应为 x.y.z"
[[ -f $KEY_FILE ]] || fail "缺少 Sparkle 私钥 $KEY_FILE"
git diff --quiet && git diff --cached --quiet || fail "工作区有未提交的改动"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  fail "$TAG 已发布"
fi

if [[ -z $NOTES ]]; then
  PREVIOUS=$(git describe --tags --abbrev=0 2>/dev/null || true)
  if [[ -n $PREVIOUS ]]; then
    NOTES=$(git log --no-merges --pretty='- %s' "$PREVIOUS..HEAD" | grep -v "chore: 发布" || true)
  fi
  NOTES=${NOTES:-"- 常规更新"}
fi

echo "1/6 更新版本号 $VERSION ($BUILD_NUMBER)"
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml
if command -v xcodegen >/dev/null; then
  xcodegen generate --quiet
fi
if ! git diff --quiet; then
  git commit -qam "chore: 发布 $TAG"
fi

rm -rf "$WORK"
mkdir -p "$WORK"

echo "2/6 归档"
run xcodebuild archive -project BabyDays.xcodeproj -scheme BabyDays-macOS -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -derivedDataPath "$WORK/DerivedData" \
  -allowProvisioningUpdates CURRENT_PROJECT_VERSION=$BUILD_NUMBER

echo "3/6 Developer ID 签名并提交公证"
cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>N7Z52F27XK</string>
</dict>
</plist>
PLIST
# 首次使用新能力 (如 App Group) 时, 云端签名偶尔返回空结果, 重试即可
for attempt in {1..3}; do
  if EXPORT_LOG=$(xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$WORK/ExportOptions.plist" \
    -exportPath "$WORK/upload" -allowProvisioningUpdates 2>&1); then
    break
  fi
  if (( attempt == 3 )); then
    print -r -- "$EXPORT_LOG" | grep -E "error" || print -r -- "$EXPORT_LOG" | tail -20
    fail "导出与上传公证失败"
  fi
  sleep 10
done

echo "4/6 等待公证结果"
for attempt in {1..60}; do
  if xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$WORK/notarized" >"$WORK/notarize.log" 2>&1; then
    break
  fi
  if (( attempt == 60 )); then
    tail -20 "$WORK/notarize.log"
    fail "30 分钟内未拿到公证结果"
  fi
  sleep 30
done
APP=$WORK/notarized/BabyDays.app
xcrun stapler validate "$APP" >/dev/null
spctl --assess --type execute "$APP"

echo "5/6 打包并生成更新清单"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
STAGE=$WORK/dmg
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
run hdiutil create -volname "宝宝多大" -srcfolder "$STAGE" -format UDZO "$DMG"
cp "$DMG" "$HOME/Desktop/宝宝多大-$VERSION.dmg"

SIGN_UPDATE=$(find "$WORK/DerivedData/SourcePackages/artifacts" -path "*/Sparkle/bin/sign_update" -type f | head -1)
[[ -n $SIGN_UPDATE ]] || fail "找不到 Sparkle 的 sign_update"
SIGNATURE=$("$SIGN_UPDATE" --ed-key-file "$KEY_FILE" "$ZIP")
NOTES_HTML=$(print -r -- "$NOTES" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/^- \(.*\)/<li>\1<\/li>/')
cat > "$WORK/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>宝宝多大</title>
    <item>
      <title>$VERSION</title>
      <pubDate>$(LC_ALL=en_US.UTF-8 date -R)</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<ul>$NOTES_HTML</ul>]]></description>
      <enclosure url="https://github.com/$REPO/releases/download/$TAG/BabyDays-$VERSION.zip" $SIGNATURE type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML

echo "6/6 推送并发布 $TAG"
git tag "$TAG"
git push -q origin HEAD
git push -q origin "$TAG"
gh release create "$TAG" --repo "$REPO" --title "宝宝多大 $VERSION" --notes "$NOTES" \
  "$ZIP" "$DMG" "$WORK/appcast.xml"

# 构建目录中的同 ID 副本会被系统选作小组件扩展, 发布后全部注销并删除
find "$WORK" -name "BabyDays.app" -type d -prune | while read -r copy; do
  pluginkit -r "$copy/Contents/PlugIns/BabyDaysWidget.appex" 2>/dev/null || true
  "$LSREGISTER" -u "$copy" 2>/dev/null || true
done
rm -rf "$WORK"
echo "已发布 https://github.com/$REPO/releases/tag/$TAG"
echo "安装包副本: $HOME/Desktop/宝宝多大-$VERSION.dmg"
