# 拾间

个人收藏库。书 / 电影 / 剧集 / 图片 / 链接，收进来，找得到。

不是每天打开的工具，是「先收着、以后要用的时候能找到」的那一层。

## 现在能做什么

- **六个板块**：书架（3D 弧形书脊，拖动吸附）、影视（海报墙 / 剧集扇形牌堆）、图集（宝丽来瀑布流）、链接（竖向时间轴，按月分组）、我的。
- **阅读器**：txt / epub 导入，分页、字号、行距、三种纸色、左右翻页与上下滚动、目录跳转、进度记忆（存档位置是 locator，不是页码 —— 换字号不会丢位置）。
- **全局搜索**：一次搜五类，结果按板块分组。
- **图片输出**：全屏看原图、保存到相册、分享、设为壁纸。
- **数据源匹配**：手动填永远可用；匹配是锦上添花。书走 Google Books / Open Library（ISBN 或书名），影视走 TMDB / Bangumi。Key 填在「我的 → 数据源」，不写进代码。国内直连不通时填一个 HTTP 代理地址即可。
- **备份**：导出 zip（library.json + blobs/），换机或重装后导入回去。
- **应用内更新**：启动静默检查 GitHub Release，比较 versionCode，下载后走系统安装器。

## 目录

```
lib/
  core/      纯 Dart：model / section / ids / reader locator。禁止 import flutter
  data/      sqlite + blob 存储 + 迁移 + 导入导出
  net/       数据源与代理
  ui/        界面（可整体重写，不影响数据）
  platform/  Android 能力出口（相册 / 分享 / 壁纸 / 安装 APK）
```

一条纪律：`core/` 里出现 `import 'package:flutter/...'` 就是架构破口。

## 数据

- 主键是 ULID 字符串，不再用数组下标寻址。
- 每条 item 带 `updated_at / device_id / rev / deleted`，写 `oplog` 只追加 —— 以后要多端同步时不需要改表。
- 二进制走内容寻址：`<support>/blobs/<ab>/<cd>/<sha256>`，文件名就是哈希，数据库里只存哈希。
- `schema_version` 一旦发版只能往上加。改表必须在 `db.dart` 的 `_migrateStep` 里补一段，否则老用户升级直接崩。

## 构建

```bash
flutter pub get
flutter test
flutter build apk --release
```

签名材料放 `android/key.properties`（已在 .gitignore 里）：

```properties
storeFile=/绝对路径/shijian-release.jks
storePassword=...
keyAlias=shijian
keyPassword=...
```

**这个 keystore 丢了就再也发不出能覆盖安装的更新**（只能卸载重装，数据全丢）。备份两处，别进仓库。

## 发版

```bash
# 改 pubspec.yaml 的 version: 1.0.0+2（+后面是 versionCode，应用内更新靠它比大小）
git tag v1.0.1 && git push --tags
```

`.github/workflows/android-release.yml` 会自动构建并把 APK 挂到 Release。

## 已知限制

- 只在 Android 上跑过；桌面端和网页端是「以后再说」，不是不做。
- TMDB / Google Books 在国内直连不通，需要代理。
- 微信内置浏览器不能选文件，这是宿主限制，与本应用无关。
