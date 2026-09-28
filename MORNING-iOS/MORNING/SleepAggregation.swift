import Foundation

// A deterministic sleep timeline builder, independent of HealthKit and testable on Windows/Linux.
// Detailed stages win over unspecified sleep; a single stage wins for each instant.
struct SleepInterval {
    enum Stage: Int { case awake, unspecified, core, deep, rem }
    var start: Date
    var end: Date
    var stage: Stage
    var sourcePriority: Int = 0 // Higher = preferred source; no false claims about which app produced it.
}

func summarizeSleep(_ intervals: [SleepInterval], windowStart: Date, windowEnd: Date) -> SleepBreakdown {
    let valid = intervals.compactMap { sample -> SleepInterval? in
        let start = max(sample.start, windowStart)
        let end = min(sample.end, windowEnd)
        guard end > start else { return nil }
        return SleepInterval(start: start, end: end, stage: sample.stage, sourcePriority: sample.sourcePriority)
    }
    guard !valid.isEmpty else { return SleepBreakdown() }
    let boundaries = Array(Set(valid.flatMap { [$0.start, $0.end] })).sorted()
    var result = SleepBreakdown()
    // A single output per atomic interval prevents double-counting overlapping sources.
    for index in 0..<(boundaries.count - 1) {
        let start = boundaries[index], end = boundaries[index + 1]
        let covering = valid.filter { $0.start <= start && $0.end >= end }
        // If both detailed and unspecified sources cover the interval, prefer stage detail.
        guard let chosen = covering.max(by: { a, b in
            let aDetail = a.stage == .unspecified ? 0 : 1
            let bDetail = b.stage == .unspecified ? 0 : 1
            if aDetail != bDetail { return aDetail < bDetail }
            if a.sourcePriority != b.sourcePriority { return a.sourcePriority < b.sourcePriority }
            return a.stage.rawValue < b.stage.rawValue
        }) else { continue }
        let seconds = end.timeIntervalSince(start)
        switch chosen.stage {
        case .core: result.core += seconds
        case .deep: result.deep += seconds
        case .rem: result.rem += seconds
        case .unspecified: result.unspecified += seconds
        case .awake: result.awake += seconds
        }
    }
    return result
}
