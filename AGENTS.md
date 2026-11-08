# AGENTS.md

本仓库由 AI Agent 独立维护. 本文件是维护手册: 接手时先读完本文件, 再按任务查阅 docs/design.md (代码结构与设计决策) 与 docs/app-store.md (上架资料). 每次改变流程, 账号, 凭据位置或踩到新坑时, 同步更新本文件

## 1. 项目概况

宝宝多大 (工程名 BabyDays) 是显示宝宝年龄的小组件 App, 覆盖三个平台

| 平台 | 形态 | 分发方式 |
|---|---|---|
| macOS 14+ | 桌面小组件 + 预览 App | 两个渠道: GitHub Releases (Developer ID, Sparkle 自动更新, target BabyDays-macOS) 与 Mac App Store (target BabyDays-macOS-AppStore, 编译条件 APP_STORE, 不含 Sparkle 与更新检查) |
| iOS / iPadOS 17+ (iPhone 与 iPad) | 主屏幕小组件 + 预览 App | App Store / TestFlight |
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
| App Store Connect CLI | asc 6.5.3, Homebrew 官方源安装; 项目入口 scripts/asc.sh. API profiles 保存在系统钥匙串, 配置路径为 ~/.config/baby-days/asc.json, 不放进仓库 |
| Sparkle EdDSA 私钥 | ~/.config/baby-days/sparkle_private_key (权限 600); 登录钥匙串中 generate_keys 的 baby-days 账户另存一份. 公钥写在 project.yml 的 SPARKLE_PUBLIC_KEY. 私钥丢失后已安装的 Mac 版无法再验证更新, 不得删除或重新生成 |
| 更新清单地址 | https://github.com/Caldis/baby-days/releases/latest/download/appcast.xml (project.yml 的 UPDATE_FEED_URL) |

凭据文件不进仓库. ~/.config/baby-days 与 ~/Library/Caches/baby-days 之外不存放本项目的本机数据

## 3. 工程与目录

project.yml 是工程定义源头, 修改后执行 xcodegen generate, 生成的 BabyDays.xcodeproj 一并提交. 8 个 target: BabyDays-iOS, BabyDays-macOS, BabyDays-macOS-AppStore, BabyDays-tvOS, BabyDaysWidget-iOS, BabyDaysWidget-macOS, BabyDaysWidget-macOS-AppStore, BabyDaysTopShelf-tvOS. 与 Sparkle 相关的代码 (Updater, 检查更新菜单与按钮, 小组件的更新提示) 包在 #if !APP_STORE 中

| 目录 | 内容 |
|---|---|
| Shared/ | 年龄计算 BabyAge, 多宝宝存储 BabyProfile, 生肖 Zodiac, 配色字体 Theme, 装饰图形, 小组件视图, 更新清单读取 UpdateFeed; 编译进全部 target |
| App/ | iOS 与 macOS 的 App (GalleryView, Sparkle 的 Updater) |
| Widget/ | iOS 与 macOS 的小组件入口与时间线 |
| TV/, TopShelf/, TVShared/ | tvOS App, 顶部栏扩展, 两者共用的全屏与横幅视图 TVAgeBoard |
| Resources/ | 字体, AppIcon.icon (iOS 与 macOS 图标), TVIcon.xcassets (tvOS 图标与顶部栏静态图), TVShared.xcassets (小蛇图片), 本地化名称 |
| Tools/Render/ | 离线渲染工具: 效果图, 图标图层, tvOS 素材, App Store 截图; 新图标与透明小蛇源素材位于 Resources/Artwork |
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
scripts/render.sh zodiac      # 12 生肖图片, iOS 备选图标与生肖总览图
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

版本号沿用 project.yml 的 MARKETING_VERSION (所有平台共用一个版本号), 构建号取当前时间. 上传后在 App Store Connect 中把三个平台待提交版本的版本号改成同一值并选择构建. 文案, 截图与接口调用方法见 docs/app-store.md, 优先通过 asc 管理, 公开 API 未覆盖的字段再用浏览器. Apple 账号密码由用户本人输入

版本资料, 截图与预检优先使用 scripts/asc.sh, 通过现有 API profile 操作. 认证前先同步并查询 United Memory 的 App Store 发布记录, 再核对执行主机与 asc auth status; 系统钥匙串中可能已有凭据, 不要因找不到原始 .p8 或当前主机未安装 asc 就要求用户重建密钥. 不同 Mac 的钥匙串需分别核对, 同步代码或 UM 不会同步钥匙串. 项目截图由 render.sh appstore 生成, 上传前用 asc screenshots validate 检查尺寸, 并另查 sips hasAlpha, 目前 CLI 的尺寸校验不能发现残留透明通道

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
| actool 报 No simulator runtime version ... available | Xcode 26 构建 iOS 或 tvOS 需要匹配 SDK 的模拟器运行时: xcodebuild -downloadPlatform iOS 或 tvOS. 本机已装 iOS 26.5 与 tvOS 26.5 运行时 |
| tvOS 归档报 requires a provisioning profile 或 Your team has no devices | 团队没有登记 Apple TV, 无法生成 tvOS 开发描述文件. release-appstore.sh 以 CODE_SIGNING_ALLOWED=NO 归档 tvOS, 用临时签名写入 App Group 权限后再由云端证书导出; 不签名直接导出会丢失 App Group 权限 |
| 上传校验报 UIRequiredDeviceCapabilities 缺少 arm64 | tvOS 的 App 与顶部栏扩展已在 project.yml 声明 INFOPLIST_KEY_UIRequiredDeviceCapabilities: arm64, 新增 tvOS target 时照做 |
| exportArchive 报 The request expected results but none were found | 云端签名首次遇到新能力时的偶发错误, 重试即可, 发布脚本已内置重试 |
| xcrun simctl launch 卡住 | 本机模拟器偶发. 放到后台执行并限时, 截图用 xcrun simctl io <设备> screenshot |
| 访达仍显示 BabyDays.app | 用户开启了显示扩展名, 且访达缓存了名称. LaunchServices 中已是 "宝宝多大", 重启访达后生效 |
| 模块名 Sparkle 与同名类型冲突 | 四角星图形已命名为 Twinkle, 新增类型避免与 Sparkle, WidgetKit 等模块同名 |
| iOS 26.5 模拟器中选了宝宝, 小组件仍显示默认宝宝 | AppEntity 在本地签名模拟器中可能无法注册, linkd 报 Unable to get teamId, 参数被还原为 nil. 小组件现使用原生字符串 babyID + BabyOptionsProvider 动态选项, 已实测同屏两个小组件独立显示宝宝与配色; 不要改回依赖实体注册的配置 |
| 图标模式点击后回跳, 关闭重开才更新 | 保存时重新创建 UserDefaults(suiteName:) 会让 AppStorage 观察不同实例. BabyProfile.defaults 必须保持进程内单例, 不要改回计算属性; 验证需使用真实持久化路径, 内存 preview 不能覆盖此问题 |
| asc auth status 能看到 profile, API 命令却报 credentials not found | status 与 doctor 可能只读到钥匙串元数据. 先检查执行主机和钥匙串是否解锁, 再实际验证 API 访问. SSH 中登录钥匙串锁定时, 读取私钥会被 macOS 拒绝; 原始 AuthKey_*.p8 也要先检查字节数, 不能只看文件名是否存在 |
| iPad 上应用四周出现黑边 | App 和 Widget 的 TARGETED_DEVICE_FAMILY 都需为 1,2, 并声明 iPad 四个方向与 UIRequiresFullScreen=NO, 否则系统以 iPhone 兼容模式运行 |
| install-mac.sh 构建后一直不安装 | pgrep -x BabyDays 会匹配正在运行的 iPhone 或 Apple TV 模拟器进程. 脚本现仅退出并等待 /Applications/BabyDays.app 的进程, 不影响模拟器 |
| SourceKit 报找不到类型 | 单文件诊断的噪音, 以 xcodebuild 或 swiftc 的结果为准 |
| 小组件库侧栏中的宝宝多大显示旧图标与名称 BabyDays | 系统小组件服务缓存了首次安装时的图标与名称, 安装包内的图标与本地化名称正确 (用 NSWorkspace 渲染可确认). killall chronod 或重启后刷新, 与构建无关 |
| GitHub 上旧提交仍可按 SHA 访问 | 历史已强推重写, 旧对象需要删除并重建仓库 (需 gh auth refresh -s delete_repo) 或联系 GitHub Support 清理 |

## 8. 协作约定

- 用户使用中文沟通; 文档遵循用户全局规范: 不用加粗, 不用行内反引号, 行末不加句号, 英文标点, 中英文之间加空格, 陈述与论证分离
- 提交信息使用中文, 末尾附上当前会话提供的 Co-Authored-By 与 Claude-Session 行
- 用户已授权: 直接推送 main, 必要时强推覆盖历史, 在 GitHub Releases 与 App Store Connect 上传构建. 删除仓库, 修改价格或提交审核前先确认
- 视觉改动先出离线渲染图自查, 再构建真机或模拟器; 涉及用户桌面时截取小组件窗口验证
- App Review 要求的真机屏幕录制由用户本人录制. Agent 负责给出演示步骤, 在 App Store Connect 中回复审核并附上视频, 然后重新提交; 不用脚本模拟鼠标代录, 也不改动用户的台前调度, 桌面图标等系统设置
- 替换 /Applications/BabyDays.app (例如在 Developer ID 版与 App Store 版之间切换) 会让系统移除用户桌面上已添加的宝宝多大小组件, 替换前告知用户
- 新写整篇面向人阅读的文档时, 走 prose-polish skill 的写作流水线; 局部修订直接改, 改完用 slop-score 自查

## 9. 当前状态

- 已发布 macOS 1.2.1 (GitHub Releases), 用户的 Mac 已通过 Sparkle 更新到该版本
- App Store Connect: iOS, macOS, tvOS 的 1.2.1 已于 2026-09-29 提交审核, 发布方式为审核通过后自动发布. Mac 版于 2026-09-30 因 Guideline 2.1 Information Needed 被拒, 当天回复审核并附上用户录制的视频后重新提交, 三个平台均为等待审核. 审核联系人信息已在 App Store Connect 中填写, 不写入仓库
- 2026-11-08 为本地开发执行 scripts/install-mac.sh, /Applications/BabyDays.app 当前为 BabyDays-macOS 的 Release 开发签名构建, 版本 1.2.1, 构建号 202611082143, 含 Sparkle; 已启动并打开 Xcode 工程, 已安装独立生肖双版本与新版宝宝编辑界面. 替换前已告知用户桌面小组件会被移除
- 2026-11-08 已安装 design-playful-app-icons skill 到 ~/.codex/skills/design-playful-app-icons. 最新 12 生肖按动物独立生成, Resources/Artwork/Zodiac/calendar 为日历版图标原画, mascots 为无日历版 App 与小组件形象, designs-v2.json 与 generation-v2.json 保存角色设定和每张图的提示词. zodiac 渲染先生成默认蛇的 Artwork/app-icon.png, 再运行 icon, tv, docs, snapshots 与 appstore. 日历颜色随生肖变化, 不共用绿色日历
- 中国大陆: 首次提交未包含中国大陆, 避免没有 ICP 备案号拖住其他地区的审核. 三个 App Store 版本都不访问网络, 属于可能豁免备案的离线应用, 但 Apple 未公布豁免清单. 审核通过后先在销售范围中加回中国大陆 (POST /iris/v2/appAvailabilities, CHN 设为 available); 若被要求备案号, 联系 Apple Developer Support 说明离线, 或由用户办理 ICP 备案后在 App 信息中填写
- 仓库需保持公开: App Store 的隐私政策, 技术支持与营销网址, 以及 Mac 版 Sparkle 的更新清单和安装包都指向本仓库. 如需改为私有, 先新建公开仓库承接这些内容, 发布一版 Mac 更新把 UPDATE_FEED_URL 切过去, 在下一个 App Store 版本中更换网址, 最后再改私有
- 本机已安装 XcodeGen 2.46.0, 修改 project.yml 后必须执行 xcodegen generate 同步新增源文件与资源; 不可依赖旧工程继续构建
- 多宝宝数据保存在 App Group 的 babyCollection.v1, 旧 birthDate 自动迁移为稳定 ID legacy-baby 并保留镜像, 避免 App 与扩展同时迁移时产生不同 ID; Widget kind 不变, 每个小组件通过 AppIntent 保存宝宝 ID, 删除宝宝后提示重新选择. 生肖按农历新年换年, 默认图标仍为蛇
- 模型验证: swiftc Shared/BabyAge.swift Shared/BabyProfile.swift Shared/Zodiac.swift Tests/ModelTests.swift -o ~/Library/Caches/baby-days/model-tests, 然后运行产物. 覆盖春节边界, 12 生肖, 独立小组件关联, 旧数据迁移, 删除与图标偏好
- 2026-11-08 已在 tvOS 26.5 模拟器运行新版, 验证生肖主题与备选图标; iOS 26.5 模拟器已验证自动图标和同屏两个独立宝宝小组件. 三个平台均已构建, 用户真机尚未安装本轮开发改动
- 用户的 iPhone 上仍是旧的开发签名版本, 需要用 Xcode 重装或等待 TestFlight
- 主界面使用生肖头像选择宝宝, 生日旁直接显示编辑和删除, 添加入口为加号. BabyEditor 只保留称呼与生日, 图标设置的图片直接作为选项. 小组件使用独立的 ZodiacWidgets.xcassets 缩略图, 不要把完整图标目录加入扩展
- render.sh 的 Swift 模块缓存固定为 ~/Library/Caches/baby-days/ModuleCache, 避免沙盒尝试写入 ~/.cache/clang. tvOS 顶部栏图片 URL 包含构建号, 让素材升级后刷新系统缓存
- 本轮已逐张检查全部离线快照和 32/60/180 px 图标, 模型测试通过. Mac 隔离预览实测头像切换, 姓名保存, 直接删除确认和可点选图标网格; iOS 26.5 实测新编辑弹层, 同屏两个独立宝宝小组件与自动图标. 三个平台均构建通过, tvOS 顶部栏以不透明模式导出, 避免 alpha 254 的 actool 警告
- tvOS 底部操作使用明确前景色与焦点背景, 避免主题 tint 导致原生填充按钮的标签不可见; 编辑, 添加, 图标与删除直接可见. tvOS 添加宝宝可取消, 年月日选项随当前日期限制范围, 不再把用户选中的未来日期静默改成今天. 已在 tvOS 26.5 实测按钮焦点, 打开编辑与取消返回, 测试后关闭本轮启动的电视模拟器
- iOS 工程现为 iPhone / iPad 通用应用, iPad 支持四个方向和多任务窗口. GalleryView 用外层 GeometryReader 读取真实窗口宽度, 再选择双栏, 上下排列或窄屏纵向预览. 不要测量 ScrollView 内容宽度, 固定尺寸子视图会撑大测量值, 导致窗口缩小后仍沿用宽屏布局并被裁切
- 小蛇已按用户反馈恢复大头, 短脖子和厚盘圈比例, calendar 与 mascots 的正式 snake.png 使用新版本, snake-rounded-v3.json 保存此次提示词与透明边缘修订记录
- 已在真实持久化路径复现并修复图标模式回跳: 修复前点击后立即回默认, 重启才看到保存值; 修复后隔离应用与 /Applications 安装版均验证默认, 跟随宝宝和自选即时切换, 关闭重开和重启保留偏好. 实际用户的原默认模式已恢复
- iPad Pro 13-inch (M5) / iPadOS 26.5 模拟器已验证原生全屏, 横竖屏, 深色模式和拖动窗口至约 375 pt 后纵向重排. App 与 Widget 的成品 UIDeviceFamily 均为 [1,2], iPad 备选图标 11 个, 原生设置已实测切换并由系统确认自动图标
- 本轮最终 /Applications 构建号为 202611082143. 已验证实际安装版图标三种模式切换并恢复原默认, iPhone 模拟器完成回归. 当前没有可直接安装的实体 iPad, iPad 支持尚需用户设备安装新构建才会生效, 未上传 TestFlight 或 App Store
- 1.3.0 (202611082247) 已于 2026-11-08 经 release-appstore.sh 成功上传 iOS / iPadOS, tvOS 与 Mac App Store, 尚未绑定商店版本或提交审核. 源码与资料已推送到 main 的 01f341a. 三个平台的简体中文资料分别存于 metadata/ios, metadata/macos, metadata/tvos, CLI 离线校验通过. 9 张商店截图已逐张查看并校验尺寸, 全部为无 alpha 的 sRGB PNG, 包含原生 iPad 横竖屏
- 已核实历史 App Store 凭据在 MacBook 的标准 asc 系统钥匙串中, 原始 Downloads/AuthKey_*.p8 已是 0 字节. 用户已明确授权复制到 Mac mini, 迁移需先解锁 MacBook 的登录钥匙串. 不再要求用户重复创建 API Key, 不把文件名存在或 auth status 的元数据列表当作可用性证明
- 已安装 asc-cli-usage, asc-release-flow, asc-submission-health, asc-xcode-build, asc-metadata-sync, asc-shots-pipeline, asc-screenshot-resize, asc-build-lifecycle 与 asc-whats-new-writer, 来源固定为 rorkai/app-store-connect-cli-skills 的 266d7ad357acd3a1c437668b0e77021bb0ff2f02
