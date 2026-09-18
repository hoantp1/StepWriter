import SwiftUI
import HealthKit

struct ContentView: View {
    private let healthStore = HKHealthStore()
    @State private var steps = "1000"
    @State private var status = "Chưa cấp quyền"
    @State private var todayInfo = "Chưa có dữ liệu"

    private var stepType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .stepCount)!
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ghi số bước") {
                    TextField("Số bước", text: $steps)
                        .keyboardType(.numberPad)
                    Button("Ghi vào Sức khỏe") { saveSteps() }
                }
                Section("Trạng thái") {
                    Text(status)
                    Button("Xin quyền / Đọc dữ liệu hôm nay") { requestAccess() }
                }
                Section("Nguồn dữ liệu hôm nay") {
                    Text(todayInfo)
                }
            }
            .navigationTitle("StepWriter")
            .onAppear { requestAccess() }
        }
    }

    private func requestAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "HealthKit không khả dụng trên thiết bị này."
            return
        }
        healthStore.requestAuthorization(toShare: [stepType], read: [stepType]) { success, error in
            DispatchQueue.main.async {
                status = success ? "Đã gửi yêu cầu quyền HealthKit." :
                    "Không thể cấp quyền: \(error?.localizedDescription ?? "Không rõ lỗi")"
            }
            if success { readToday() }
        }
    }

    private func saveSteps() {
        guard let value = Double(steps), value > 0 else {
            status = "Số bước không hợp lệ."
            return
        }
        let quantity = HKQuantity(unit: .count(), doubleValue: value)
        let sample = HKQuantitySample(type: stepType,
                                      quantity: quantity,
                                      start: Date(),
                                      end: Date())
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                status = success ? "Đã ghi \(Int(value)) bước vào Sức khỏe." :
                    "Ghi thất bại: \(error?.localizedDescription ?? "Không rõ lỗi")"
            }
            if success { readToday() }
        }
    }

    private func readToday() {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, error in
            let total = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            DispatchQueue.main.async {
                todayInfo = error == nil ? "Tổng Apple Health hôm nay: \(Int(total)) bước" :
                    "Không đọc được: \(error!.localizedDescription)"
            }
        }
        healthStore.execute(query)
    }
}
