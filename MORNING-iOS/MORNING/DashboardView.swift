import SwiftUI
import Charts

private let ink = Color(red: 0.10, green: 0.14, blue: 0.21)
private let page = Color(red: 0.965, green: 0.972, blue: 0.982)

struct DashboardView: View {
    @StateObject private var health = HealthService.shared
    private var r: DailyReport { health.report }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if !health.hasRequestedAccess { permissionPanel }
                    sleepCard
                    trendCard
                    Text("心率与呼吸").font(.title3.bold()).padding(.top, 4)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metric("静息心率 · 昨日", r.restingHeartRate, "次/分", "heart.fill", .pink, precision: 0)
                        metric("HRV · 昨日", r.heartRateVariability, "ms", "waveform.path.ecg", .purple, precision: 0)
                        metric("睡眠窗平均心率", r.sleepingHeartRate, "次/分", "moon.stars.fill", .indigo, precision: 0)
                        metric("睡眠窗呼吸频率", r.respiratoryRate, "次/分", "wind", .teal, precision: 1)
                        metric("睡眠腕温（支持时）", r.wristTemperature, "°C", "thermometer.medium", .orange, precision: 1)
                    }
                    Text("昨日活动").font(.title3.bold()).padding(.top, 4)
                    HStack(spacing: 12) {
                        metric("步数", r.stepsYesterday, "步", "figure.walk", .green, precision: 0)
                        metric("活动能量", r.activeEnergyYesterday, "kcal", "flame.fill", .orange, precision: 0)
                    }
                    HStack { metric("锻炼时间", r.exerciseMinutesYesterday, "分钟", "figure.run", .blue, precision: 0) }
                    insights
                    settings
                    Text("数据来自你授权的 Apple Health。趋势仅供健康记录，不用于诊断。没有记录可能意味着数据尚未同步或未授权。")
                        .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 24)
                }
                .padding(18)
            }
            .background(page).foregroundStyle(ink)
            .navigationBarHidden(true)
            .refreshable { await health.refresh() }
            .task { if health.hasRequestedAccess { await health.refresh(); health.startBackgroundObservation() } }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("MORNING", systemImage: "sun.max.fill").font(.subheadline.bold()).foregroundStyle(.orange)
                Spacer()
                if health.isLoading { ProgressView() }
            }
            Text("早上好，Jack").font(.largeTitle.bold())
            Text(Date().formatted(date: .complete, time: .omitted)).font(.subheadline).foregroundStyle(.secondary)
            Text(r.status).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }
    private var permissionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("连接 Apple 健康", systemImage: "heart.text.square.fill").font(.headline)
            Text("读取你允许的睡眠、心率、活动等数据，报告在本机计算，不上传健康数据。")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { Task { await health.requestAccess() } } label: {
                Text("授权读取健康数据").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(ink)
        }.card()
    }
    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("昨晚睡眠", systemImage: "moon.zzz.fill").font(.headline).foregroundStyle(.indigo)
            Text(r.sleep.total > 0 ? durationText(r.sleep.total) : "暂无数据")
                .font(.system(size: 33, weight: .bold, design: .rounded))
            GeometryReader { proxy in
                let total = max(1, r.sleep.total)
                HStack(spacing: 0) {
                    stageBar(r.sleep.deep / total, .indigo, proxy.size.width)
                    stageBar(r.sleep.core / total, .blue, proxy.size.width)
                    stageBar(r.sleep.rem / total, .teal, proxy.size.width)
                    stageBar(r.sleep.unspecified / total, .gray, proxy.size.width)
                }.frame(height: 13).clipShape(Capsule())
            }.frame(height: 13)
            HStack(spacing: 12) {
                stageLabel("深睡", r.sleep.deep, .indigo)
                stageLabel("核心", r.sleep.core, .blue)
                stageLabel("REM", r.sleep.rem, .teal)
            }
            if r.sleep.unspecified > 0 { Text("另有未细分睡眠：\(durationText(r.sleep.unspecified))").font(.caption).foregroundStyle(.secondary) }
        }.card()
    }
    private func stageBar(_ fraction: Double, _ color: Color, _ available: CGFloat) -> some View {
        Rectangle().fill(color).frame(width: available * max(0, fraction))
    }
    private func stageLabel(_ name: String, _ time: TimeInterval, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) { Circle().fill(color).frame(width: 7, height: 7); Text(name).font(.caption).foregroundStyle(.secondary) }
            Text(time > 0 ? durationText(time) : "—").font(.caption.bold())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("此前 7 晚睡眠").font(.headline)
            let entries = r.sevenDaySleepHours.enumerated().compactMap { i, v -> SleepPoint? in
                guard let v else { return nil }; return SleepPoint(day: i, hours: v)
            }
            if entries.isEmpty {
                Text("积累睡眠记录后显示趋势图").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 110)
            } else {
                Chart(entries) { item in
                    BarMark(x: .value("日期", item.day), y: .value("小时", item.hours)).foregroundStyle(.indigo.gradient)
                }.chartYScale(domain: 0...max(10, (entries.map(\.hours).max() ?? 8) + 1))
                    .frame(height: 130)
                if let avg = r.sevenDayAverage { Text(String(format: "有记录日期平均 %.1f 小时", avg)).font(.caption).foregroundStyle(.secondary) }
            }
        }.card()
    }
    private func metric(_ title: String, _ value: Double?, _ unit: String, _ symbol: String, _ tint: Color, precision: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol).foregroundStyle(tint).font(.title3)
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(height: 30, alignment: .topLeading)
            Text(value.map { String(format: "%.*f", precision, $0) } ?? "—").font(.system(size: 25, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }
    private var insights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("晨间解读", systemImage: "sparkles").font(.headline)
            ForEach(r.insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(.green).frame(width: 6, height: 6).padding(.top, 7)
                    Text(insight).font(.subheadline)
                }
            }
        }.card()
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置").font(.headline)
            Button("重新请求健康权限") { Task { await health.requestAccess() } }
            if !health.notificationsEnabled {
                Button("开启晨报通知") { Task { await health.requestNotifications() } }
            } else {
                Label("已允许晨报通知", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
            Button("立即刷新报告") { Task { await health.refresh() } }
        }.card()
    }
}

private struct SleepPoint: Identifiable {
    let day: Int
    let hours: Double
    var id: Int { day }
}

private extension View {
    func card() -> some View {
        self.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}
