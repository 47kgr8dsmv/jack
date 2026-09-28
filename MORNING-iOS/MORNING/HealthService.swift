import Foundation
import HealthKit
import UserNotifications

@MainActor
final class HealthService: ObservableObject {
    static let shared = HealthService()
    @Published private(set) var report = DailyReport()
    @Published private(set) var isLoading = false
    @Published private(set) var notificationsEnabled = UserDefaults.standard.bool(forKey: "morningNotifications")
    @Published private(set) var hasRequestedAccess = UserDefaults.standard.bool(forKey: "healthAccessRequested")
    private let store = HKHealthStore()
    private var observer: HKObserverQuery?
    private var lastNotifiedDay = UserDefaults.standard.string(forKey: "lastNotifiedDay")
    private let calendar = Calendar.current

    private var sleepType: HKCategoryType { HKObjectType.categoryType(forIdentifier: .sleepAnalysis)! }
    private func quantity(_ identifier: HKQuantityTypeIdentifier) -> HKQuantityType {
        HKObjectType.quantityType(forIdentifier: identifier)!
    }
    private var readTypes: Set<HKObjectType> {
        [sleepType, quantity(.restingHeartRate), quantity(.heartRate),
         quantity(.heartRateVariabilitySDNN), quantity(.respiratoryRate),
         quantity(.stepCount), quantity(.activeEnergyBurned),
         quantity(.appleExerciseTime), quantity(.appleSleepingWristTemperature)]
    }

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            report.status = "此设备不支持 HealthKit"; return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // A successful prompt does not prove that each read permission was granted.
            hasRequestedAccess = true
            UserDefaults.standard.set(true, forKey: "healthAccessRequested")
            await refresh()
            startBackgroundObservation()
        } catch { report.status = "授权请求未完成：\(error.localizedDescription)" }
    }

    func requestNotifications() async {
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            notificationsEnabled = allowed
            UserDefaults.standard.set(allowed, forKey: "morningNotifications")
        } catch { report.status = "通知授权失败：\(error.localizedDescription)" }
    }

    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isLoading = true
        defer { isLoading = false }
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let sleepStart = calendar.date(byAdding: .hour, value: -6, to: today)! // yesterday 18:00
        let sleepEnd = calendar.date(byAdding: .hour, value: 15, to: today)!
        let sleepSamples = await loadSleep(start: sleepStart, end: min(now, sleepEnd))
        var next = DailyReport()
        next.sleep = aggregateSleep(sleepSamples, from: sleepStart, to: min(now, sleepEnd))
        // Prior seven completed sleep windows. Missing days remain missing, never zero.
        for i in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -(i+1), to: today)!
            let windowStart = calendar.date(byAdding: .hour, value: -6, to: day)!
            let windowEnd = calendar.date(byAdding: .hour, value: 15, to: day)!
            let samples = await loadSleep(start: windowStart, end: windowEnd)
            let hours = aggregateSleep(samples, from: windowStart, to: windowEnd).total / 3600
            next.sevenDaySleepHours[6-i] = hours > 0 ? hours : nil
        }
        next.restingHeartRate = await statistics(.restingHeartRate, from: yesterday, to: today, average: true, unit: HKUnit.count().unitDivided(by: .minute()))
        next.heartRateVariability = await statistics(.heartRateVariabilitySDNN, from: yesterday, to: today, average: true, unit: .secondUnit(with: .milli))
        next.stepsYesterday = await statistics(.stepCount, from: yesterday, to: today, average: false, unit: .count())
        next.activeEnergyYesterday = await statistics(.activeEnergyBurned, from: yesterday, to: today, average: false, unit: .kilocalorie())
        next.exerciseMinutesYesterday = await statistics(.appleExerciseTime, from: yesterday, to: today, average: false, unit: .minute())
        if next.sleep.total > 0 {
            next.sleepingHeartRate = await statistics(.heartRate, from: sleepStart, to: min(now,sleepEnd), average: true, unit: HKUnit.count().unitDivided(by: .minute()))
            next.respiratoryRate = await statistics(.respiratoryRate, from: sleepStart, to: min(now,sleepEnd), average: true, unit: HKUnit.count().unitDivided(by: .minute()))
            next.wristTemperature = await statistics(.appleSleepingWristTemperature, from: sleepStart, to: min(now,sleepEnd), average: true, unit: .degreeCelsius())
        }
        let baselineStart = calendar.date(byAdding: .day, value: -8, to: today)!
        next.restingHeartRateBaseline = await statistics(.restingHeartRate, from: baselineStart, to: yesterday, average: true, unit: HKUnit.count().unitDivided(by: .minute()))
        next.hrvBaseline = await statistics(.heartRateVariabilitySDNN, from: baselineStart, to: yesterday, average: true, unit: .secondUnit(with: .milli))
        next.generatedAt = Date()
        next.status = next.sleep.total > 0 ? "已从 Apple Health 更新 · \(next.generatedAt.formatted(date: .omitted, time: .shortened))" : "没有可读的睡眠数据；请检查同步与权限"
        report = next
    }

    private func loadSleep(start: Date, end: Date) async -> [HKCategorySample] {
        guard end > start else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private func aggregateSleep(_ samples: [HKCategorySample], from start: Date, to end: Date) -> SleepBreakdown {
        let intervals: [SleepInterval] = samples.compactMap { sample in
            let stage: SleepInterval.Stage
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepCore: stage = .core
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            case .asleepUnspecified: stage = .unspecified
            case .awake: stage = .awake
            default: return nil // inBed overlaps stages and is intentionally excluded
            }
            return SleepInterval(start: sample.startDate, end: sample.endDate, stage: stage)
        }
        return summarizeSleep(intervals, windowStart: start, windowEnd: end)
    }

    private func statistics(_ identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date, average: Bool, unit: HKUnit) async -> Double? {
        let type = quantity(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: average ? .discreteAverage : .cumulativeSum) { _, result, _ in
                let quantity = average ? result?.averageQuantity() : result?.sumQuantity()
                continuation.resume(returning: quantity?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    func startBackgroundObservation() {
        guard hasRequestedAccess, observer == nil else { return }
        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil else { completion(); return }
            Task { @MainActor [weak self] in
                guard let self else { completion(); return }
                await self.refresh()
                await self.notifyIfNewSleepReport()
                completion()
            }
        }
        observer = query
        store.execute(query)
        store.enableBackgroundDelivery(for: sleepType, frequency: .hourly) { success, error in
            if !success { print("MORNING: background delivery unavailable: \(error?.localizedDescription ?? "unknown")") }
        }
    }

    private func notifyIfNewSleepReport() async {
        guard notificationsEnabled, report.sleep.total > 0 else { return }
        let key = calendar.startOfDay(for: Date()).formatted(.iso8601.year().month().day().dateSeparator(.dash))
        guard key != lastNotifiedDay else { return }
        let content = UNMutableNotificationContent()
        content.title = "MORNING 晨报已更新"
        content.body = "昨晚的睡眠数据已同步，打开查看今天的晨间报告。"
        content.sound = .default
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "morning-\(key)", content: content, trigger: nil))
            lastNotifiedDay = key
            UserDefaults.standard.set(key, forKey: "lastNotifiedDay")
        } catch { print("MORNING: notification failed \(error)") }
    }
}
