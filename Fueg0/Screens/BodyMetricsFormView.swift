import SwiftUI

struct BodyMetricsFormView: View {
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var weightLbs = ""
    @State private var targetLbs = ""
    @State private var heightInches = ""
    @State private var age = ""
    @State private var calories = ""
    @State private var trainingDays = 4
    @State private var sleepHours = 7.0
    @State private var gender: Gender = .male
    @State private var sleepQuality: SleepQuality = .good
    @State private var error: String?

    var body: some View {
        Form {
            Section("Warrior stats") {
                numberField("Current weight (lbs)", text: $weightLbs)
                numberField("Target weight (lbs)", text: $targetLbs)
                numberField("Height (inches)", text: $heightInches)
                numberField("Age", text: $age)
            }
            Section("Training") {
                Picker("Gender", selection: $gender) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                    Text("Other").tag(Gender.other)
                }
                numberField("Daily calories", text: $calories)
                Stepper("Training days: \(trainingDays)", value: $trainingDays, in: 0...7)
                Stepper("Sleep hours: \(sleepHours, specifier: "%.0f")", value: $sleepHours, in: 4...12, step: 1)
                Picker("Sleep quality", selection: $sleepQuality) {
                    ForEach(SleepQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue.capitalized).tag(quality)
                    }
                }
            }
            if let error {
                Section {
                    Text(error).foregroundStyle(Palette.error)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Warrior Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear { prefill() }
        .preferredColorScheme(.dark)
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
    }

    private func prefill() {
        guard let metrics = ProgressService.loadMetrics() else { return }
        weightLbs = String(format: "%.1f", metrics.currentWeightLbs)
        if let target = metrics.targetWeightLbs {
            targetLbs = String(format: "%.1f", target)
        }
        heightInches = String(format: "%.1f", metrics.heightCm / 2.54)
        age = "\(metrics.age)"
        calories = "\(metrics.dailyCalorieIntake)"
        trainingDays = metrics.trainingDaysPerWeek
        sleepHours = metrics.sleepHours ?? 7
        gender = metrics.gender
        sleepQuality = metrics.sleepQuality ?? .good
    }

    private func save() {
        guard let lbs = Double(weightLbs), lbs > 0,
              let target = Double(targetLbs), target > 0,
              let inches = Double(heightInches), inches > 0,
              let ageValue = Int(age), ageValue > 0,
              let cals = Int(calories), cals > 0 else {
            error = "Enter weight, target, height, age, and calories."
            return
        }
        let metrics = UserBodyMetrics(
            currentWeightKg: lbs / 2.20462,
            targetWeightKg: target / 2.20462,
            targetBodyFatPercent: nil,
            currentBodyFatPercent: nil,
            heightCm: inches * 2.54,
            age: ageValue,
            gender: gender,
            dailyCalorieIntake: cals,
            trainingDaysPerWeek: trainingDays,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            goalType: .weight,
            startingWeightKg: nil,
            updatedAt: Date()
        )
        ProgressService.saveMetrics(metrics)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSaved()
        dismiss()
    }
}
