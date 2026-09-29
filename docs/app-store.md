# App Store 上架资料

本文档记录 iOS 与 tvOS 版本在 App Store Connect 中的配置, 商店文案与提交步骤. Mac 版通过 Developer ID 与 GitHub Releases 分发, 不在 Mac App Store 上架

## App Store Connect 记录

| 项目 | 值 |
|---|---|
| Apple ID (App 编号) | 6817262216 |
| 地址 | https://appstoreconnect.apple.com/apps/6817262216 |
| 套装 ID | com.caldis.babydays |
| SKU | babydays |
| 主要语言 | 简体中文 |
| 名称 | 宝宝多大 (以 App Store Connect 中的实际填写为准) |
| 平台 | iOS 已创建; tvOS 需要在 App 页面左侧 "添加平台" 中加入 |
| 开发团队 | BIAO CHEN (N7Z52F27XK), 个人账号 |

iOS 版本只支持 iPhone (TARGETED_DEVICE_FAMILY 为 1), 因此只需提供 iPhone 截图. tvOS 版本与 iOS 版本使用同一个套装 ID, 在 App Store 中合并为同一个 App (通用购买)

## 商店文案

副标题 (30 字以内)

```
桌面小组件, 一眼看见宝宝多大
```

推广文本 (170 字以内, 可随时修改, 无需审核)

```
设置一次宝宝的生日, 主屏幕上的小组件每天自动更新: 未满周岁显示出生天数, 满周岁后显示几岁几个月, 生日当天还有蛋糕和祝福
```

描述

```
宝宝多大是一组放在主屏幕上的小组件, 每天自动算好宝宝的年龄

未满周岁时显示出生天数与几个月几天, 满周岁后显示几岁几个月, 生日当天换上蛋糕与祝福. 大号小组件还会显示周龄, 已经度过的小时数, 心跳估算与生日倒计时

· 小, 中, 大三种尺寸
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
| 版权 | 2026 BIAO CHEN |
| 价格 | 免费 |
| 出口合规 | Info.plist 已声明 ITSAppUsesNonExemptEncryption 为 NO, 上传后无需再回答 |

审核备注

```
宝宝多大是主屏幕小组件 App. 首次打开 App 时在日历中选择宝宝的生日并点 "开始", 之后长按主屏幕空白处, 点左上角 "编辑" → "添加小组件", 搜索 "宝宝多大" 即可添加小, 中, 大三种尺寸. App 无需登录, 不访问网络. Apple TV 版打开后用遥控器选择年, 月, 日并保存, 即可全屏显示年龄
```

## 截图

截图由离线渲染脚本生成, 输出到 .build/app-store

```sh
scripts/render.sh appstore
```

| 文件 | 尺寸 | 上传位置 |
|---|---|---|
| iphone-1.png, iphone-2.png, iphone-3.png | 1290 × 2796 | iPhone 6.9 英寸显示屏 |
| tv-1.png, tv-2.png | 1920 × 1080 | Apple TV |

## 上传与提交

1. 确认 project.yml 的 MARKETING_VERSION 为本次要提交的版本号, App Store Connect 中待提交版本的版本号与之一致
2. 运行上传脚本, 默认同时上传 iOS 与 tvOS

```sh
scripts/release-appstore.sh          # iOS 与 tvOS
scripts/release-appstore.sh ios      # 只上传 iOS
```

3. 等待 App Store Connect 处理构建 (通常 10 到 30 分钟), 在 TestFlight 中可见后, 于版本页面的 "构建版本" 中选择该构建
4. 填写上文的文案, 截图与其他字段, 提交审核

构建号取上传时刻 (年月日时分), 每次上传自动递增. 同一版本号可以多次上传构建; 版本上架后, 下一次提交需要更高的版本号
