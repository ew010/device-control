# phonecontrol

一个基于 Flutter 的跨设备控制工具（MVP），支持以下系统作为运行端：
- Android
- Windows
- macOS
- iPad（iOS）

## 功能（当前实现）
- 双角色模式：
  - 被控端（Agent）：启动 WebSocket 服务，接收控制命令
  - 控制端（Controller）：连接被控端，发送点击/拖拽/文本命令
- 配对码鉴权：控制端必须输入正确配对码才能下发命令
- 原生输入注入（被控端）：
  - Android: AccessibilityService 手势注入（tap/drag/text）
  - Windows: Win32 `SendInput`（tap/drag/text）
  - macOS: Quartz `CGEvent`（tap/drag/text）
- scrcpy 集成（控制端，Windows/macOS）：
  - 在控制端可直接发起 `adb connect` + `scrcpy -s <ip:port>` 镜像控制安卓设备
- 安卓ADB直连（控制端为安卓）：
  - 安卓控制端可直接连接目标 `adbd`，并用 `adb shell input` 执行 tap/drag/text
- 实时状态回传：被控端会把最后命令与指针坐标回传到控制端
- 可作为远程控制协议骨架继续扩展（认证、加密、屏幕推流、平台原生输入注入）

## 快速运行
```bash
flutter pub get
flutter run
```

运行后：
1. 在设备 A 选择“被控端”，启动监听（默认 8888 端口）
2. 记录 A 上显示的配对码
3. 在设备 B 选择“控制端”，输入 A 的 IP+端口+配对码并连接
4. 在控制面板点击/拖动/发送文本命令
5. 在 Windows/macOS 控制端可选启用 scrcpy（ADB 端口默认 `5555`）
6. 在安卓控制端可开启“安卓ADB直连”开关并重连（目标设备需已开启ADB TCP调试）

## 架构说明
- 通信协议：JSON over WebSocket
- 关键消息：
  - `hello`
  - `command` (`tap` / `drag` / `text`)
  - `state`（位置与最后命令）

## 平台限制（必须说明）
- iOS/iPadOS 无法在纯 Flutter 层直接注入系统级触控去控制其他 App，这需要系统级权限或 MDM/企业方案。
- Android/macOS/Windows 的“控制系统级界面”同样需要原生能力（Accessibility、输入驱动、系统 API）和额外授权。
- 当前仓库提供的是可运行的跨端通信与控制协议骨架，不是绕过系统安全策略的完整远控实现。
- 原生注入前置条件：
  - Android: 需手动打开本 App 的无障碍服务
  - macOS: 需在“隐私与安全性 -> 辅助功能”授权本 App
  - Windows: 对高权限窗口注入可能受 UAC/完整性级别限制
- scrcpy 前置条件：
  - 控制端机器已安装 `adb` 与 `scrcpy`，并加入 PATH
  - 安卓设备已开启开发者选项与无线调试（或通过 USB + `adb tcpip 5555`）
- 安卓ADB直连前置条件：
  - 目标安卓设备已开启开发者模式与ADB网络调试（`adb tcpip 5555`）
  - 首次连接通常需要在目标设备确认调试授权

## GitHub Actions（已配置）
工作流文件：`.github/workflows/flutter-build.yml`
- PR / Push：自动执行 `flutter analyze`、`flutter test`
- 构建产物：
  - Android APK
  - Windows Release
  - macOS Release
  - iOS no-codesign 包
- 当推送 `v*` tag 时，自动发布到 GitHub Releases 并附带构建产物

示例：
```bash
git tag v1.0.0
git push origin v1.0.0
```

## 下一步建议
- 增加鉴权（配对码、设备白名单）
- 增加端到端加密（TLS/WSS）
- 用 MethodChannel 接入各平台原生控制能力
- 接入屏幕采集与编码推流（例如 WebRTC）
