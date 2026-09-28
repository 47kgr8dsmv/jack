import Foundation

var report = DailyReport()
assert(report.sleep.total == 0)
assert(report.sevenDayAverage == nil)
assert(report.insights.contains(where: { $0.contains("尚未取得") }))
report.sleep.core = 4 * 3600
report.sleep.deep = 1.5 * 3600
report.sleep.rem = 1.5 * 3600
report.sevenDaySleepHours = [6, 6, nil, 7, 7, 7, 7]
assert(report.sleepHours == 7)
assert(abs(report.sevenDayAverage! - (40.0 / 6.0)) < 0.001)
assert(durationText(3900) == "1 小时 5 分")
print("PASS: report model, missing data, seven-day average, duration formatting")

// Two duplicate sources for the same 2h interval must not produce 4h of sleep.
let t = Date(timeIntervalSince1970: 1_700_000_000)
func interval(_ start: Double, _ end: Double, _ stage: SleepInterval.Stage) -> SleepInterval {
    SleepInterval(start: t.addingTimeInterval(start), end: t.addingTimeInterval(end), stage: stage)
}
let deduplicated = summarizeSleep([
    interval(0, 7200, .unspecified),
    interval(0, 3600, .core),
    interval(3600, 7200, .deep),
    interval(0, 7200, .unspecified)
], windowStart: t, windowEnd: t.addingTimeInterval(7200))
assert(deduplicated.total == 7200)
assert(deduplicated.core == 3600 && deduplicated.deep == 3600)
let clipped = summarizeSleep([interval(-1000, 1800, .rem)], windowStart: t, windowEnd: t.addingTimeInterval(7200))
assert(clipped.rem == 1800)
print("PASS: overlapping sleep sources, stage precedence, sleep window clipping")
