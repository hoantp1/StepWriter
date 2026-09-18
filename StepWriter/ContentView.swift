import SwiftUI
import HealthKit

struct ContentView: View {
    private let healthStore = HKHealthStore()
    @State private var stepText = "100"
    @State private var status = "Chưa cấp quyền HealthKit"
    @State private var samples: [String] = []

    var body: some View {
        NavigationView {
            Form {
                Section("Ghi số bước") {
                    TextField("Số bước", text: $stepText)
                        .keyboardType(.numberPad)
                    Button("Ghi vào Sức khỏe") { saveSteps() }
                }

                Section("Trạng thái") {
                    Text(status)
                    Button("Xin quyền / Đọc dữ liệu hôm nay") {
                        requestAuthorization()
                    }
                }

                Section("Nguồn dữ liệu hôm nay") {
                    if samples.isEmpty {
                        Text("Chưa có dữ liệu")
                    } else {
                        ForEach(samples, id: \.self) { Text($0).font(.caption) }
                    }
                }
            }
            .navigationTitle("StepWriter")
            .onAppear { requestAuthorization() }
        }
    }

    private var stepType: HKQuantityType {
        HKQuantityType.quantityType(forIdentifier: .stepCount)!
    }

    private func requestAuthorization() {
        healthStore.requestAuthorization(toShare: [stepType], read: [stepType]) { ok, error in
            DispatchQueue.main.async {
                status = ok ? "Đã cấp quyền HealthKit" : "Không thể cấp quyền: \(error?.localizedDescription ?? "Không rõ")"
            }
            if ok { readToday() }
        }
    }

    private func saveSteps() {
        guard let value = Double(stepText), value > 0 else {
            status = "Số bước không hợp lệ"
            return
        }

        // Intentionally do not set HKMetadataKeyWasUserEntered.
        let now = Date()
        let start = now.addingTimeInterval(-60)
        let quantity = HKQuantity(unit: .count(), doubleValue: value)
        let sample = HKQuantitySample(type: stepType, quantity: quantity, start: start, end: now)

        healthStore.save(sample) { ok, error in
            DispatchQueue.main.async {
                status = ok ? "Đã ghi \(Int(value)) bước" : "Ghi thất bại: \(error?.localizedDescription ?? "Không rõ")"
            }
            if ok { readToday() }
        }
    }

    private func readToday() {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) {
            _, results, error in
            let rows = (results as? [HKQuantitySample] ?? []).map {
                let count = Int($0.quantity.doubleValue(for: .count()))
                let source = $0.sourceRevision.source.name
                let bundle = $0.sourceRevision.source.bundleIdentifier
                let device = $0.device?.name ?? "không có device"
                let entered = ($0.metadata?[HKMetadataKeyWasUserEntered] as? Bool).map(String.init) ?? "nil"
                return "\(count) bước | source: \(source) | \(bundle) | device: \(device) | WasUserEntered: \(entered)"
            }
            DispatchQueue.main.async {
                samples = rows
                if let error = error { status = "Đọc thất bại: \(error.localizedDescription)" }
            }
        }
        healthStore.execute(query)
    }
}
