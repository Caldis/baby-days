# AGENTS.md

本仓库由 AI Agent 独立维护. 本文件是维护手册: 接手时先读完本文件, 再按任务查阅 docs/design.md (代码结构与设计决策) 与 docs/app-store.md (上架资料). 每次改变流程, 账号, 凭据位置或踩到新坑时, 同步更新本文件

## 1. 项目概况

宝宝多大 (工程名 BabyDays) 是显示宝宝年龄的小组件 App, 覆盖三个平台

| 平台 | 形态 | 分发方式 |
|---|---|---|
| macOS 14+ | 桌面小组件 + 预览 App | 两个渠道: GitHub Releases (Developer ID, Sparkle 自动更新, target BabyDays-macOS) 与 Mac App Store (target BabyDays-macOS-AppStore, 编译条件 APP_STORE, 不含 Sparkle 与更新检查) |
| iOS 17+ (仅 iPhone) | 主屏幕小组件 + 预览 App | App Store / TestFlight |
| tvOS 17+ | 全屏 App + 顶部栏横幅 (Top Shelf) | App Store / TestFlight |

宝宝生日在 App 中设置, 通过 App Group 与小组件或顶部栏扩展共享. 仓库公开, 任何真实的出生日期都不得写入仓库, 文档, 截图, 提交信息或随机种子; 示例一律使用 2025-01-01

## 2. 账号, 标识与凭据

| 项目 | 值或位置 |
|---|---|
| GitHub 仓库 | https://github.com/Caldis/baby-days (公开), 本机 gh 已登录 Caldis |
| 开发团队 | BIAO CHEN, Team ID N7Z52F27XK, 付费个人账号, Xcode 已登录 |
| 签名 | 全部自动签名; Developer ID Application 与 Apple Distribution 证书由云端管理, 本机钥匙串中没有私钥, 只能通过 xcodebuild -allowProvisioningUpdates 使用 |
| Bundle ID | App: com.caldis.babydays; 小组件: com.caldis.babydays.widget; 顶部栏: com.caldis.babydays.topshelf |
| App Group | iOS 与 tvOS: group.com.caldis.babydays; macOS: N7Z52F27XK.com.caldis.babydays |
| App Store Connect | App 编号 6817262216, SKU babydays, 详见 docs/app-store.md |
| Sparkle EdDSA 私钥 | ~/.config/baby-days/sparkle_private_key (权限 600); 登录钥匙串中 generate_keys 的 baby-days 账户另存一份. 公钥写在 project.yml 的 SPARKLE_PUBLIC_KEY. 私钥丢失后已安装的 Mac 版无法再验证更新, 不得删除或重新生成 |
| 更新清单地址 | https://github.com/Caldis/baby-days/releases/latest/download/appcast.xml (project.yml 的 UPDATE_FEED_URL) |

凭据文件不进仓库. ~/.config/baby-days 与 ~/Library/Caches/baby-days 之外不存放本项目的本机数据

## 3. 工程与目录

project.yml 是工程定义源头, 修改后执行 xcodegen generate, 生成的 BabyDays.xcodeproj 一并提交. 8 个 target: BabyDays-iOS, BabyDays-macOS, BabyDays-macOS-AppStore, BabyDays-tvOS, BabyDaysWidget-iOS, BabyDaysWidget-macOS, BabyDaysWidget-macOS-AppStore, BabyDaysTopShelf-tvOS. 与 Sparkle 相关的代码 (Updater, 检查更新菜单与按钮, 小组件的更新提示) 包在 #if !APP_STORE 中

| 目录 | 内容 |
|---|---|
| Shared/ | 年龄计算 BabyAge, 生日存储 BabyProfile, 配色字体 Theme, 装饰图形, 小组件视图, 更新清单读取 UpdateFeed; 编译进全部 target |
| App/ | iOS 与 macOS 的 App (GalleryView, Sparkle 的 Updater) |
| Widget/ | iOS 与 macOS 的小组件入口与时间线 |
| TV/, TopShelf/, TVShared/ | tvOS App, 顶部栏扩展, 两者共用的全屏与横幅视图 TVAgeBoard |
| Resources/ | 字体, AppIcon.icon (iOS 与 macOS 图标), TVIcon.xcassets (tvOS 图标与顶部栏静态图), TVShared.xcassets (小蛇图片), 本地化名称 |
| Tools/Render/ | 离线渲染工具: 效果图, 图标图层, 铅笔风小蛇, tvOS 素材, App Store 截图 |
| scripts/ | render.sh, install-mac.sh, release-mac.sh, release-appstore.sh |

## 4. 常用操作

构建目录一律放在 ~/Library/Caches/baby-days 下, 禁止放在 ~/Desktop 下 (原因见第 7 节)

```sh
xcodegen generate
D=~/Library/Caches/baby-days/DerivedData
xcodebuild -project BabyDays.xcodeproj -scheme BabyDays-macOS -destination 'generic/platform=macOS' -derivedDataPath $D -allowProvisioningUpdates build
xcodebuild -project BabyDays.xcodeproj -scheme BabyDays-iOS -destination 'generic/platform=iOS Simulator' -derivedDataPath $D build
xcodebuild -project BabyDays.xcodeproj -scheme BabyDays-tvOS -destination 'generic/platform=tvOS Simulator' -derivedDataPath $D build
```

在本机构建过 macOS 的 Debug 或 Release 产物后, 注销并删除该副本, 只保留 /Applications 中的版本

```sh
P=$D/Build/Products/Debug/BabyDays.app
pluginkit -r "$P/Contents/PlugIns/BabyDaysWidget.appex"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$P"
rm -rf "$P"
```

离线渲染 (swiftc 直接编译 Shared, TVShared 与 Tools/Render, 不经过 Xcode)

```sh
scripts/render.sh snapshots   # 全部场景, 配色, 尺寸的检查图与 tvOS 画面, 输出到 .build/snapshots
scripts/render.sh docs        # README 配图, 输出到 docs/images
scripts/render.sh icon        # iOS 与 macOS 图标图层, 输出到 Resources/AppIcon.icon/Assets
scripts/render.sh tv          # tvOS 图标, 顶部栏静态图与小蛇图片, 输出到 Resources
scripts/render.sh appstore    # App Store 截图, 输出到 .build/app-store
```

改动视图后先跑 snapshots 并逐张查看图片, 再进 Xcode 构建

## 5. 发布

### macOS (GitHub Releases + Sparkle)

```sh
scripts/release-mac.sh 1.3.0 "- 更新说明第一条
- 更新说明第二条"
```

脚本要求工作区干净, 依次完成: 改写 MARKETING_VERSION 并提交, 归档, Developer ID 导出并上传公证 (导出失败自动重试 3 次), 等待公证并装订, 打包 zip 与 dmg, 用私钥签名 zip, 生成 appcast.xml, 打标签并推送, gh release create 上传. 桌面会多一份 宝宝多大-<版本>.dmg, 发布后把旧版本的 dmg 移到废纸篓

发布后在本机验证自动更新: 打开 babydays://update 弹出 Sparkle 窗口, 用辅助功能点击 "安装更新" 与 "安装并重启应用" (第 6 节), 再确认 /Applications/BabyDays.app 的 CFBundleShortVersionString

### iOS, tvOS 与 Mac App Store (App Store Connect)

```sh
scripts/release-appstore.sh          # iOS, tvOS 与 macOS
scripts/release-appstore.sh macos    # 只传 Mac App Store 版本
```

版本号沿用 project.yml 的 MARKETING_VERSION (所有平台共用一个版本号), 构建号取当前时间. 上传后在 App Store Connect 中把三个平台待提交版本的版本号改成同一值并选择构建. 文案, 截图与接口调用方法见 docs/app-store.md: 用户在 claude-in-chrome 控制的 Chrome 中登录后, 通过页面内 fetch 调用 /iris/v1 接口完成大部分填写, App 隐私与价格用网页点击完成. Apple 账号密码由用户本人输入

### 版本号规则

MARKETING_VERSION 只增不减. 修复用第三位, 功能用第二位. macOS 发布脚本会自动改写并提交版本号; App Store 上传前如需新版本号, 先手动修改 project.yml 并提交. 构建号 (CFBundleVersion) 始终为时间戳, Sparkle 与 WidgetKit 都依赖它递增

## 6. 验证方法

1. 离线渲染: scripts/render.sh snapshots, 查看 .build/snapshots 中的图片
2. 真实 WidgetKit 渲染: 打开 /System/Library/CoreServices/WidgetKit Simulator.app, 在 Choose a Widget 中选择 BabyDays → 宝宝多大, 可查看三种尺寸与 7 天时间线. 窗口操作可以用 osascript 调用 System Events (本机终端已有辅助功能与屏幕录制权限)
3. 桌面上的小组件: 用 CGWindowListCopyWindowInfo 找到所有者为 "通知中心" 且尺寸为 180 或 360 的窗口, 再用 screencapture -l <窗口号> -o -x 截图. 桌面前有窗口时小组件处于浅色化状态, 截到的是单色版
4. 系统显示的图标: 用 NSWorkspace.shared.icon(forFile:) 渲染 /Applications/BabyDays.app 的图标
5. Gatekeeper: 复制 dmg, 加上 com.apple.quarantine 属性, hdiutil attach -nobrowse 后对其中的 App 执行 spctl -a -vv -t exec, 结果应为 Notarized Developer ID
6. 小组件进程与注册: pluginkit -m -v -D -p com.apple.widgetkit-extension | grep babydays 只应列出 /Applications 中的一项; 崩溃记录在 ~/Library/Logs/DiagnosticReports/BabyDaysWidget-*.ips
7. App Group 中的生日: defaults read "$HOME/Library/Group Containers/N7Z52F27XK.com.caldis.babydays/Library/Preferences/N7Z52F27XK.com.caldis.babydays"

## 7. 已知问题与处理

| 现象 | 原因与处理 |
|---|---|
| 桌面小组件显示旧版画面或一直是占位图 | 系统选用了构建目录中的副本, 位于 ~/Desktop 下的副本启动即崩溃. 构建目录放在 ~/Library/Caches, 构建后注销并删除副本, 每次安装使用新构建号 |
| Sparkle 更新后桌面仍显示旧画面或 "有新版本" | 系统复用旧扩展进程. 1.1.2 起旧进程检测到构建号不一致会自行退出; 必要时 pkill -f BabyDaysWidget |
| 固定尺寸容器内文字被截成 "…" | WidgetKit 宿主渲染比扩展布局略宽, 离线渲染看不出. 这类文字加 lineLimit(1) + minimumScaleFactor |
| actool 报 No simulator runtime version ... available | Xcode 26 构建 iOS 或 tvOS 需要匹配 SDK 的模拟器运行时: xcodebuild -downloadPlatform iOS 或 tvOS. 本机已装 iOS 26.3 与 tvOS 26.2 运行时 |
| tvOS 归档报 requires a provisioning profile 或 Your team has no devices | 团队没有登记 Apple TV, 无法生成 tvOS 开发描述文件. release-appstore.sh 以 CODE_SIGNING_ALLOWED=NO 归档 tvOS, 用临时签名写入 App Group 权限后再由云端证书导出; 不签名直接导出会丢失 App Group 权限 |
| 上传校验报 UIRequiredDeviceCapabilities 缺少 arm64 | tvOS 的 App 与顶部栏扩展已在 project.yml 声明 INFOPLIST_KEY_UIRequiredDeviceCapabilities: arm64, 新增 tvOS target 时照做 |
| exportArchive 报 The request expected results but none were found | 云端签名首次遇到新能力时的偶发错误, 重试即可, 发布脚本已内置重试 |
| xcrun simctl launch 卡住 | 本机模拟器偶发. 放到后台执行并限时, 截图用 xcrun simctl io <设备> screenshot |
| 访达仍显示 BabyDays.app | 用户开启了显示扩展名, 且访达缓存了名称. LaunchServices 中已是 "宝宝多大", 重启访达后生效 |
| 模块名 Sparkle 与同名类型冲突 | 四角星图形已命名为 Twinkle, 新增类型避免与 Sparkle, WidgetKit 等模块同名 |
| SourceKit 报找不到类型 | 单文件诊断的噪音, 以 xcodebuild 或 swiftc 的结果为准 |
| GitHub 上旧提交仍可按 SHA 访问 | 历史已强推重写, 旧对象需要删除并重建仓库 (需 gh auth refresh -s delete_repo) 或联系 GitHub Support 清理 |

## 8. 协作约定

- 用户使用中文沟通; 文档遵循用户全局规范: 不用加粗, 不用行内反引号, 行末不加句号, 英文标点, 中英文之间加空格, 陈述与论证分离
- 提交信息使用中文, 末尾附上当前会话提供的 Co-Authored-By 与 Claude-Session 行
- 用户已授权: 直接推送 main, 必要时强推覆盖历史, 在 GitHub Releases 与 App Store Connect 上传构建. 删除仓库, 修改价格或提交审核前先确认
- 视觉改动先出离线渲染图自查, 再构建真机或模拟器; 涉及用户桌面时截取小组件窗口验证
- 新写整篇面向人阅读的文档时, 走 prose-polish skill 的写作流水线; 局部修订直接改, 改完用 slop-score 自查

## 9. 当前状态

- 已发布 macOS 1.2.1 (GitHub Releases), 用户的 Mac 已通过 Sparkle 更新到该版本
- App Store Connect: iOS, macOS, tvOS 的 1.2.1 均已选好构建, 填好文案, 截图, 分级, 类别, 隐私 (不收集数据), 价格 (免费) 与销售范围 (除中国大陆外); 等待用户填写审核联系电话后提交审核
- 中国大陆区需要 ICP 备案号, 用户尚未办理; 备案完成后在 App 信息中填写备案号, 并在销售范围中加回中国大陆
- tvOS 版只经过编译, 离线渲染与上传校验, 尚未在模拟器或真机上运行验证 (本机 tvOS 模拟器启动 App 卡住)
- 用户的 iPhone 上仍是旧的开发签名版本, 需要用 Xcode 重装或等待 TestFlight
