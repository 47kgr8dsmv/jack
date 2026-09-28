# MORNING 1.0 — Apple Watch 晨报（SwiftUI）

本项目是原生 iOS MVP 源代码。适用于 Apple Watch Series 6–8 同步到 iPhone Apple Health 的兼容数据。**尚未在 macOS/Xcode 或真实 iPhone 上编译和实测。**

## 包含
- HealthKit **只读授权**；本机计算睡眠阶段、过去 7 晚睡眠趋势、昨日静息心率、HRV、步数、活动能量、运动分钟数。
- 读取可用的夜间呼吸频率、睡眠时间窗口平均心率和腕温（后者主要 Series 8，视记录而定）。
- 新睡眠样本的 HealthKit 后台观察，并尝试发送通用、不暴露敏感数值的每日通知。
- 所有数据只在手机本地读取和分析，未集成第三方服务器或模型。

## 在 Mac 上生成 Xcode 项目
1. 安装最新稳定版 Xcode（建议 iOS 17+ SDK），以及 XcodeGen：`brew install xcodegen`。
2. 在本目录运行 `xcodegen generate`，生成 `MORNING.xcodeproj`。
3. 用 Xcode 打开项目，选中 `MORNING` target，在 Signing & Capabilities 里选择你的 Team，确认 HealthKit 和其 Background Delivery 权限均可用；替换 Bundle Identifier 为自己的唯一值。
4. 使用已配对 Apple Watch、且有睡眠数据的真实 iPhone 运行，首次启动允许健康数据读取及（可选）通知权限。模拟器不能验证真实 HealthKit 后台更新。
5. 如果 `xcodegen` 生成项目时 Info.plist 重复设置，请保留由 Xcode 生成的 Info.plist 与 `NSHealthShareUsageDescription`，删除重复配置。

## 注意与已知限制
- Series 6/7 没有睡眠腕温传感器；Series 8 可视实际数据支持显示。
- HealthKit 不能可靠告知被拒绝的**读取**权限；空白会显示“缺失/尚未同步”，而不是假装获得权限。
- 这是 MVP：睡眠汇总未实现对多设备/多 App 重叠睡眠样本的去重，故多个来源记录可能导致时长偏高；正式版应使用可信来源优先级和时间段去重。
- “睡眠窗心率/呼吸”按昨晚 18:00 到今日 15:00 的窗口求平均，**不是严格只限睡眠阶段**；正式版应按睡眠区间筛选心率/呼吸样本。
- 心率昨日均值与 HRV 昨日均值不构成医学诊断。睡眠阶段是手表估计值。
- iOS 不保证后台监听会在刚起床的瞬间触发；新数据到达时尽力刷新。下拉刷新或打开 App 可直接同步。
- 当前代码还没有完成 iPhone 真机编译验证、自动化 UI 测试、长期电量测试或 App Store 审核，不要当作已上架产品。
- HealthKit 健康数据不会上传到本项目服务端；如果以后引入云端 AI，应单独提供明确同意和隐私机制。

参考：Apple Developer — Configuring HealthKit access, Executing Observer Queries。

## Windows 阶段 1（更新）
请优先阅读 `GETTING-STARTED-WINDOWS.md`。附带 `.github/workflows/ios-build.yml`，在 GitHub macOS runner 上完成无签名模拟器编译。
`SleepAggregation.swift` 新增重叠睡眠分段的去重和时间窗裁剪，替代初版简单累加逻辑。仍需真实设备核实多来源优先策略。
