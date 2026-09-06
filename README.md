# 清醒贴

一个面向 macOS 15.0+ 的原生桌面提醒应用。它把 1 到任意多条行为提示作为一组贴纸悬浮在桌面上，并通过菜单栏图标集中管理。

## 下载

前往 [GitHub Releases](https://github.com/ex90rts/reminders/releases/latest) 下载最新的 `清醒贴-macOS15-arm64.zip`。当前发布包支持 macOS 15.0+ 和 Apple Silicon。

当前自动发布使用 ad-hoc 签名，尚未经过 Apple 公证，适合测试分发；macOS 可能在首次打开时显示安全提示。

## 功能

- 整组贴纸可拖动，位置自动保存；显示器布局改变后会自动校正回可见区域
- 统一新增、编辑、显示、隐藏、删除和排序常驻提醒
- 可选“始终置顶”，同时支持全部 Spaces、全屏应用和 Stage Manager
- 统一配置贴纸背景色、文字颜色与透明度
- 文案、主题、显示状态和位置均自动持久化
- 内容过多时限制到当前屏幕高度并允许滚动
- 菜单栏常驻，不占用 Dock；支持显示/隐藏、恢复位置和退出

## 构建与运行

需要 macOS 15.0+ 和 Swift 6 / Xcode 26 或更新版本。

```bash
cd reminders
./scripts/build-app.sh --test
./scripts/build-app.sh
open "dist/清醒贴.app"
```

每次成功打包都会将语义版本的 patch 位自动加 1，并把构建版本写为当前时间的 `YYYYMMDDHHmmss`；需要指定版本时可使用 `--version x.y.z`。

也可以使用 Xcode 打开 `Package.swift` 后直接运行 `Reminders` scheme。

## 发布新版本

推送符合 `vX.Y.Z` 格式的 tag 后，GitHub Actions 会自动运行测试、构建对应版本，并把应用压缩包上传到 GitHub Release：

```bash
git tag v1.0.2
git push origin v1.0.2
```

Release 的应用版本取自 tag；例如 `v1.0.2` 会构建为 `1.0.2`。如需重新执行同一 tag 的工作流，已有 Release 中的压缩包会被覆盖更新。

## 使用

1. 启动后，贴纸默认出现在主屏幕右上角。
2. 拖动贴纸组的任意区域，可移动整组贴纸。
3. 点击菜单栏的贴纸图标，选择“打开设置…”管理文案、配色与显示方式。
4. 若更换显示器后想重置位置，选择“恢复清醒贴位置”。

开发构建使用 ad-hoc 签名。正式分发时应改用 Developer ID Application 签名并完成 notarization。
