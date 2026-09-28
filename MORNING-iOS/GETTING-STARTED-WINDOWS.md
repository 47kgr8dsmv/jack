# MORNING — Windows 用户的第一阶段操作

目标：先完成**云端 iOS 编译检查**，不是直接把未经签名的 App 装到 iPhone。

1. 在 GitHub 新建 **private** 仓库，如 `morning-ios`。
2. 解压下载的 ZIP，在解压目录中打开 Git Bash/PowerShell。执行：
   ```bash
   git init
   git add .
   git commit -m "MORNING phase 1: iOS scaffold and sleep tests"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/morning-ios.git
   git push -u origin main
   ```
   请将 `YOUR_USERNAME` 替换为自己的账号；按 GitHub 提示登录。
3. 打开仓库页面 `Actions` -> `MORNING iOS Build` 查看自动编译结果；也可以手动触发 `Run workflow`。
4. 如果失败，将出错步骤的日志发给我，我会按真实错误逐条修复。成功后进入设备安装与 HealthKit 授权阶段。

## 本阶段完成范围
- SwiftUI 首页及 HealthKit 只读接入代码（未在真实设备验证）。
- 睡眠分段去重及窗口裁剪的纯 Swift 测试。
- GitHub Actions 云端生成 Xcode 项目、测试和模拟器编译配置。
- 本机无需 Mac 即可修改源码、提交和查看云端 CI 结果。

## 当前不提供的能力
- ZIP 不是已签名 IPA，不可直接点击在 iPhone 上安装。
- macOS GitHub runner 构建成功不等于真实设备 HealthKit 可用。
- 安装需要 Apple 签名与合适的分发通道；后续确认是否采用 TestFlight/其他符合 Apple 要求的安装途径。
- 健康数据仅读取在 iPhone，**不会提交到 GitHub**；不要上传真实健康导出文件或证书密码到仓库。
