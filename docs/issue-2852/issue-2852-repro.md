# Kazumi #2852 复现材料

**适用客户端为 fork 的 Windows 测试构建。** `Hanime1DirectTest.json` 使用 `chapterMode: direct`，正式版 2.4.4 不支持此模式。该 fork 的 `pubspec.yaml` 标记为 `2.3.3+20303`。与上游 2.4.4 的共同基点为 `4fed48b`，fork 侧有 8 个独有提交，上游标签侧有 90 个独有提交。 [功能分支](https://github.com/jzy834894319/Kazumi/tree/feature/direct-playlist-chapter-modes) · [固定提交](https://github.com/jzy834894319/Kazumi/commit/e2f6df473198cd2897933eb100e07c1ebcd3bba9) · [与 2.4.4 对照](https://github.com/jzy834894319/Kazumi/compare/Predidit:2.4.4...feature/direct-playlist-chapter-modes)

## Windows 手动复测

1. 从该提交对应的 Actions 运行下载 `windows_outputs`，解压并启动其中的 Kazumi。也可自行检出固定提交构建。GitHub 目前记录该产物于 2026-12-21 到期。 [Windows 构建产物](https://github.com/jzy834894319/Kazumi/actions/runs/35696575275/artifacts/10681121355)
2. 打开「我的 → 规则管理 → 添加规则 → 从文件导入」，选择 `Hanime1DirectTest.json`。如使用剪贴板，复制完整 JSON 后选择「从剪贴板导入」。在编辑器检查搜索模式为 XPath，选集模式为「直接播放」。 [官方导入说明](https://kazumi.app/docs/intro/module-details/)
3. 使用该规则搜索能返回结果的关键词，选择一个指向 `/watch?v=…` 的结果。若搜索阶段遇到验证页或 HTTP 错误，记录该阶段结果。此最小样例沿用本地旧文件的搜索配置，未配置 `antiCrawlerConfig`。
4. 搜索成功后点击播放来源。预期生成「播放线路1」及「第1集」单条记录，其 URL 为搜索结果解析后的完整播放页地址。direct 生成选集时跳过额外的选集网络请求。再打开该条目，单独记录播放器是否成功加载媒体。

## Playlist 待复测

当前取得的本地 Hanime1 文件只有旧版 XPath 选集字段。原先的 playlist 导出、实际清单选择器和可复测条目仍缺失。获得原始导出后，核对 `chapterMode: playlist`，以及 `chapterRoads`、`chapterResult` 分别指向带 `href` 的清单入口与剧集链接，两个字段都使用 CSS 选择器。选择一个有独立清单入口的结果，预期同一线路按页面顺序列出剧集，重复 URL 去重。再选一个没有清单入口的结果，预期回退至单集。清单页等待剧集选择器超时会报错，应与回退单独记录。

## 验证记录

- 2026-11-18 本次执行了 JSON 字段检查，并在静态 XML 样例上验证搜索 XPath 可取出标题和相对链接，以及相对 URL 可解析为完整地址。样例使用系统 XPath 实现。JSON 源自本地旧版 `Hanime1_Kazumi.json`，此处改用 fork 的规则等级 8、独立规则名和 direct 模式，移除了旧版选集 XPath。
- 本机尝试执行 Flutter 测试与构建，因找不到 Flutter 命令而未启动。本次未执行 Windows 界面、源站、WebView 或媒体播放验证。
- 同一提交的历史 Actions 中 `flutter-test`、`flutter-analyze` 和 Windows 构建成功，整个运行因 iOS 和 macOS 的构建失败而标记失败。源码测试包含 direct 单集生成与 playlist 模式值规范化。清单页的 WebView 导航与 DOM 提取仍需手测。 [历史 CI](https://github.com/jzy834894319/Kazumi/actions/runs/35696575275)
- 此前分别报告过测试分支 direct 播放和 playlist 提取成功，以及正式版 2.4.4 搜索后提示「未能获取播放列表，请重试或选择其他结果」。正式版这次旧记录没有提供可确定根因的 HTTP 状态。 [此前的 Windows 记录](https://github.com/Predidit/Kazumi/issues/2852#issuecomment-6954833836)

如有分支所需的 Flutter SDK，可在固定提交下运行：

```powershell
flutter pub get
flutter test test/plugin_api_config_test.dart test/rule_engine_test.dart
flutter analyze --no-fatal-infos --fatal-warnings
flutter build windows --release
```

#2578 / #2579 对应 XPath 搜索阶段的非 2xx Challenge 检测，已在正式版 2.4.4 的规则引擎源码中核对。#2734 讨论选集请求的 Cookie / User-Agent，#2738 讨论搜索与选集的自定义 User-Agent。 [#2578](https://github.com/Predidit/Kazumi/issues/2578) · [#2579](https://github.com/Predidit/Kazumi/pull/2579) · [#2734](https://github.com/Predidit/Kazumi/issues/2734) · [#2738](https://github.com/Predidit/Kazumi/issues/2738)

