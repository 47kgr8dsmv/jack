import Foundation

struct SleepBreakdown {
    var core: TimeInterval = 0
    var deep: TimeInterval = 0
    var rem: TimeInterval = 0
    var unspecified: TimeInterval = 0
    var awake: TimeInterval = 0
    var total: TimeInterval { core + deep + rem + unspecified }
}

struct DailyReport {
    var generatedAt = Date()
    var sleep = SleepBreakdown()
    var sevenDaySleepHours: [Double?] = Array(repeating: nil, count: 7)
    var restingHeartRate: Double?
    var heartRateVariability: Double?
    var sleepingHeartRate: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
    var stepsYesterday: Double?
    var activeEnergyYesterday: Double?
    var exerciseMinutesYesterday: Double?
    var restingHeartRateBaseline: Double?
    var hrvBaseline: Double?
    var status: String = "等待授权"

    var sleepHours: Double { sleep.total / 3600 }
    var sevenDayAverage: Double? {
        let valid = sevenDaySleepHours.compactMap { $0 }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0,+) / Double(valid.count)
    }
    var insights: [String] {
        var results: [String] = []
        if sleep.total == 0 {
            results.append("尚未取得昨晚的睡眠记录。请确认睡眠追踪已开启，并等待健康数据同步。")
        } else if let average = sevenDayAverage {
            let delta = sleepHours - average
            if abs(delta) >= 0.5 {
                results.append(String(format: "昨晚睡眠比此前 7 天有记录日期的平均值%@ %.1f 小时。", delta > 0 ? "多" : "少", abs(delta)))
            } else { results.append("昨晚睡眠时长与近期有记录日期的平均水平接近。") }
        } else { results.append("昨晚睡眠数据已读取。积累更多记录后可查看趋势。") }
        if let current = restingHeartRate, let baseline = restingHeartRateBaseline {
            let delta = current - baseline
            if abs(delta) >= 5 { results.append(String(format: "昨日静息心率与此前 7 天平均值相差 %+.0f 次/分；可结合疲劳及运动情况观察趋势。", delta)) }
        }
        if let current = heartRateVariability, let baseline = hrvBaseline, baseline > 0 {
            let delta = (current - baseline) / baseline * 100
            if abs(delta) >= 20 { results.append(String(format: "昨日 HRV 与此前 7 天平均值相差 %+.0f%%；单次变化不能代表疾病或恢复状态。", delta)) }
        }
        if stepsYesterday == nil { results.append("昨日步数暂不可用，可能尚未同步或未授予读取权限。") }
        return results
    }
}

func durationText(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int(seconds / 60))
    return "\(minutes / 60) 小时 \(minutes % 60) 分"
}
