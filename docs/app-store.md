# App Store 上架资料

本文档记录 iOS, tvOS 与 Mac App Store 版本在 App Store Connect 中的配置, 商店文案与提交步骤. Mac 版同时有两个渠道: Mac App Store 版本 (BabyDays-macOS-AppStore target, 不含 Sparkle, 由 App Store 更新) 与 GitHub Releases 的 Developer ID 版本 (BabyDays-macOS target, 内置 Sparkle). 两者 Bundle ID 相同, 同一台 Mac 上只装其中一个

## App Store Connect 记录

| 项目 | 值 |
|---|---|
| Apple ID (App 编号) | 6817262216 |
| 地址 | https://appstoreconnect.apple.com/apps/6817262216 |
| 套装 ID | com.caldis.babydays |
| SKU | babydays |
| 主要语言 | 简体中文 |
| 名称 | 宝宝多大啦 (商店名称; 设备上显示 "宝宝多大") |
| 平台 | iOS, macOS, tvOS |
| 销售范围 | 除中国大陆外的 174 个国家或地区, 新增地区自动上架; 中国大陆需要 ICP 备案号, 备案完成后在 App 信息中填写并加回中国大陆 |
| 价格 | 免费 |
| 开发团队 | BIAO CHEN (N7Z52F27XK), 个人账号 |

iOS 版本同时支持 iPhone 与 iPad (App 与 Widget 的 TARGETED_DEVICE_FAMILY 均为 1,2). 上传通用构建时同时提供 iPhone 与 iPad 截图, iPad 使用原生模拟器和示例生日 2025-01-01. tvOS 版本与 iOS 版本使用同一个套装 ID, 在 App Store 中合并为同一个 App (通用购买)

## 商店文案

1.3.0 的正式字段分别保存在 metadata/ios, metadata/macos 与 metadata/tvos, 每个平台的 version/1.3.0/zh-Hans.json 包含描述, 关键词, 推广文本与更新说明. 上传以这些文件为准, 修改现有版本前先拉取商店当前资料并检查 dry run, 保留未指定的字段和其他语言. 下文为旧版通用文案参考

副标题 (30 字以内)

```
桌面小组件, 一眼看见宝宝多大
```

推广文本 (170 字以内, 可随时修改, 无需审核)

```
设置一次宝宝的生日, 小组件每天自动更新: 未满周岁显示出生天数, 满周岁后显示几岁几个月, 生日当天还有蛋糕和祝福
```

描述

```
宝宝多大是一组放在主屏幕和桌面上的小组件, 每天自动算好宝宝的年龄

未满周岁时显示出生天数与几个月几天, 满周岁后显示几岁几个月, 生日当天换上蛋糕与祝福. 大号小组件还会显示周龄, 已经度过的小时数, 心跳估算与生日倒计时

· 小, 中, 大三种尺寸, iPhone, iPad 主屏幕与 Mac 桌面都能放
· 浅色为草地晴空, 深色为林间夜空, 也支持主屏幕的着色与透明样式
· 首次打开时设置宝宝的生日, 之后无需再打开 App
· 不需要账号, 不访问网络, 生日只保存在本机
· Apple TV 版全屏显示宝宝的年龄, 放在首行时顶部栏显示实时横幅
```

关键词 (100 字符以内, 逗号分隔)

```
宝宝,年龄,小组件,出生天数,月龄,周岁,生日倒计时,育儿,纪念日,满月,百天,成长
```

## 其他字段

| 字段 | 填写 |
|---|---|
| 类别 | 主要: 生活; 次要: 工具 |
| 年龄分级 | 问卷全部选 "无", 结果为 4+ |
| App 隐私 | 数据类型选 "不收集数据" |
| 隐私政策网址 | https://github.com/Caldis/baby-days/blob/main/PRIVACY.md |
| 技术支持网址 | https://github.com/Caldis/baby-days/issues |
| 营销网址 | https://github.com/Caldis/baby-days |
| Apple TV 隐私政策 (文本) | 与 PRIVACY.md 内容一致的一段文字 |
| 内容版权 | 不使用第三方内容 |
| 审核联系人 | 已在 App Store Connect 中填写, 联系方式不写入公开仓库; 三个平台各有一份审核信息, 备注按平台区分 |
| 版权 | 2026 BIAO CHEN |
| 价格 | 免费 |
| 出口合规 | Info.plist 已声明 ITSAppUsesNonExemptEncryption 为 NO, 上传后无需再回答 |

审核备注

```
宝宝多大无需登录, 不访问网络, 宝宝资料只保存在本机. 首次打开时点 "添加宝宝", 填写称呼和生日后点 "添加"; 编辑已有宝宝时点 "完成". 顶部头像切换宝宝, 加号添加宝宝, 生日旁的铅笔和垃圾桶分别用于编辑和删除. 添加主屏幕小组件后, 长按小组件并选择 "编辑小组件", 可独立选择对应宝宝. 设置页可选择默认蛇图标, 跟随宝宝生肖或自选生肖. 测试可使用示例生日 2025-01-01
```

## 截图

截图由离线渲染脚本生成, 输出到 .build/app-store

```sh
scripts/render.sh appstore
```

| 文件 | 尺寸 | 上传位置 |
|---|---|---|
| iphone-1.png, iphone-2.png, iphone-3.png | 1284 × 2778 | iPhone 6.5 英寸显示屏 |
| ipad-1.png, ipad-2.png | 2064 × 2752, 2752 × 2064 | iPad 13 英寸显示屏 |
| tv-1.png, tv-2.png | 1920 × 1080 | Apple TV |
| mac-1.png, mac-2.png | 2880 × 1800 | Mac |

iPad 图片从 docs/images/ipad-portrait.png 与 ipad-landscape.png 原尺寸导出. 全部上架图片为无透明通道的 sRGB PNG, 原始文档图片不改动. 尺寸用 scripts/asc.sh screenshots sizes --all 与 screenshots validate 核对, 透明通道用 sips -g hasAlpha 单独检查

## 上传与提交

本机通过 Homebrew 官方源安装 asc, 配套发布 skills 来自 rorkai/app-store-connect-cli-skills. 所有项目命令使用 scripts/asc.sh, 该入口将配置放在 ~/.config/baby-days/asc.json, 网页会话缓存放在 ~/Library/Caches/baby-days/asc-web, 私钥使用系统钥匙串

Mac mini 的默认 profile 为 caldis-appstore, 已在项目之外的新终端通过普通 asc auth status --validate 与真实 App 查询验证. 非空备份按 AuthKey_*.p8 标准命名保存在 ~/.config/baby-days, 权限为 0600. 发布无需再连接 MacBook 或重新创建密钥

先查询 United Memory 中的 App Store 发布记录, 确认凭据所在主机, 再执行 scripts/asc.sh auth status. 历史流程已使用 asc 的系统钥匙串, 原始 .p8 可以不在磁盘上; 当前主机未找到文件不代表用户没有凭据, 不重复要求创建 API Key. 新增配置仅在确实缺少可复用授权时进行, 不把私钥或 Apple 账号密码写入文档与仓库

status 与 doctor 可以仅凭钥匙串条目元数据列出 profile, 仍需用实际 API 请求验证. SSH 与桌面会话的访问上下文不同, 在桌面解锁后 SSH 仍可能报 credentials not found. 已验证可在用户已解锁的 gui/UID 会话中通过一次性 launchd 任务运行官方 auth export-to-config, 不改变钥匙串访问控制; 完成传输后移除任务和临时文件, 保留原机 profile

使用原始 .p8 前先确认它非空. asc 5.14.1 导出时会继续引用已存在的 0 字节原文件; 此时仅临时移开已核实为空的占位文件, 用 EXIT trap 恢复原件, 再由官方命令导出钥匙串内嵌密钥. 本轮迁移和临时文件清理均已完成, 详细核验记录在 UM 的 20261108-asc-credential-discovery

2026-11-08 已上传三平台 1.3.0 (202611082247), 上传日志保存在 ~/Library/Caches/baby-days/appstore-1.3.0-upload.log. 构建均为 VALID, 已绑定三平台草稿. 9 张截图已完成服务器处理, 版本文案和审核说明已更新, 原联系人不变. 三平台预检均为 0 errors / 0 warnings, 提交 dry run 均为 wouldSubmit=true. 发布方式为审核通过后自动发布, 当前等待最终提交确认

1. 确认 project.yml 的 MARKETING_VERSION 为本次要提交的版本号, App Store Connect 中待提交版本的版本号与之一致
2. 运行上传脚本, 默认同时上传 iOS, tvOS 与 Mac App Store 版本

```sh
scripts/release-appstore.sh          # iOS, tvOS 与 macOS
scripts/release-appstore.sh ios      # 只上传 iOS
```

3. 等待 App Store Connect 处理构建 (通常 10 到 30 分钟), 在 TestFlight 中可见后, 于版本页面的 "构建版本" 中选择该构建
4. 用 asc 拉取并预览 metadata/<平台> 的资料变更, 上传经校验的截图, 绑定本次构建. 先运行 validate 和 review submit --dry-run, 确认具体版本后再提交审核

构建号取上传时刻 (年月日时分), 每次上传自动递增. 同一版本号可以多次上传构建; 版本上架后, 下一次提交需要更高的版本号

## 通过网页会话调用 App Store Connect 接口

正常发布优先使用 asc 的公开 API 命令. 以下网页会话方法保留为 API 未覆盖字段的备用入口. 用户在浏览器中登录 App Store Connect 后, 在页面中执行 fetch 调用 /iris/v1 接口即可读写, 请求沿用网页登录态, 无需额外请求头. 接口结构与公开的 App Store Connect API 相同, 已验证可用的操作:

| 操作 | 接口 |
|---|---|
| 版本号, 版权 | PATCH /iris/v1/appStoreVersions/{id} |
| 选择构建 | PATCH /iris/v1/appStoreVersions/{id}/relationships/build |
| 描述, 关键词, 推广文本, 网址 | PATCH /iris/v1/appStoreVersionLocalizations/{id} |
| 副标题, 隐私政策网址与文本 | PATCH /iris/v1/appInfoLocalizations/{id} |
| 类别 | PATCH /iris/v1/appInfos/{id} (primaryCategory LIFESTYLE, secondaryCategory UTILITIES) |
| 年龄分级 | PATCH /iris/v1/ageRatingDeclarations/{id} |
| 内容版权 | PATCH /iris/v1/apps/{id} (contentRightsDeclaration) |
| 销售范围 | POST /iris/v2/appAvailabilities |
| 截图 | POST /iris/v1/appScreenshotSets, POST /iris/v1/appScreenshots, 按 uploadOperations 上传, 再 PATCH uploaded 为 true |
| 审核信息 | POST 或 PATCH /iris/v1/appStoreReviewDetails (contactPhone 必填, 需带国家码) |
| 提交审核 | 每个平台 POST /iris/v1/reviewSubmissions (platform 为 IOS, MAC_OS 或 TV_OS), POST /iris/v1/reviewSubmissionItems 关联版本, 再 PATCH reviewSubmissions 的 submitted 为 true |
| 被拒后重新提交 | 先 PATCH /iris/v1/reviewSubmissionItems/{id} 的 resolved 为 true (状态变为 READY_FOR_REVIEW), 再 PATCH reviewSubmissions 的 submitted 为 true; 网页上的 "Resubmit to App Review" 按钮在条目仍为 REJECTED 时不可点 |

截图文件通过 claude-in-chrome 的 file_upload 放进页面中临时创建的 input, 再由脚本读取上传. App 隐私 (数据收集) 与价格在网页中点击完成

## 审核被拒的处理

新账号首次提交可能收到 Guideline 2.1 Information Needed, 要求在真机上录屏 (从启动 App 开始, 展示主要流程) 并回答用途, 使用方法, 外部服务, 地区差异与资质五项. 处理步骤:

1. 用户本人在真机上录屏, 录屏文件用 ffmpeg 压缩到 1080p MP4 (file_upload 单次上限 10 MB)
2. 在提交详情页点 "Reply to App Review", 回复框填写五项说明; 页面自带的 input[type=file] 先加上 aria-label, 再用 find 取得引用并通过 file_upload 附上视频, 最后点 Reply
3. 同样的说明写入该平台 appStoreReviewDetails 的 notes, 供以后提交参考
4. 按上表 "被拒后重新提交" 的两步接口重新提交
