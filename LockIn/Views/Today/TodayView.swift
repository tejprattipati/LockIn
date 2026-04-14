// TodayView.swift
// Main command center: daily status, metrics, risk level, quick actions.

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query private var goalProfiles: [GoalProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query(sort: \DailyLog.date, order: .reverse) private var dailyLogs: [DailyLog]
    @Query private var tdeeStates: [TDEEAdjustmentState]

    @StateObject private var hkManager = HealthKitManager.shared
    @StateObject private var mndManager = MyNetDiaryManager.shared

    @State private var showWeighInSheet = false
    @State private var showCalorieSheet = false
    @State private var showInterveneTab = false
    @State private var showScreenshotImport = false
    @State private var newWeight: String = ""
    @State private var newCalories: String = ""
    @State private var newProtein: String = ""

    private var userProfile: UserProfile? { userProfiles.first }
    private var goalProfile: GoalProfile? { goalProfiles.first }
    private var todayLog: DailyLog? { dailyLogs.first { Calendar.current.isDateInToday($0.date) } }
    private var tdeeState: TDEEAdjustmentState? { tdeeStates.first }

    private var sevenDayAvg: Double? {
        CalculationEngine.currentSevenDayAverage(from: Array(weightEntries.prefix(7)))
    }

    private var currentWeight: Double {
        weightEntries.first?.weightLb ?? userProfile?.currentWeight ?? 170.0
    }

    private var bodyComposition: BodyCompositionResult? {
        guard let profile = userProfile, let goal = goalProfile else { return nil }
        return CalculationEngine.compute(
            weightLb: currentWeight,
            heightInches: profile.heightInches,
            bodyFatPercent: profile.estimatedBodyFatPercent,
            activityLevel: profile.activityLevel,
            targetCalories: goal.dailyCalorieTarget,
            goalWeightLb: goal.targetWeight
        )
    }

    private var nightRisk: NightRiskLevel {
        let hour = Calendar.current.component(.hour, from: .now)
        return CalculationEngine.nightRiskLevel(
            currentHour: hour,
            actualCaloriesToday: todayLog?.actualCalories,
            proteinHit: todayLog?.checklist(for: .hitProteinTarget)?.isCompleted ?? false,
            nightMealPlanned: todayLog?.nightMeal != nil,
            hadPreviousIntervention: (todayLog?.interveneSessionCount ?? 0) > 0
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: LockInTheme.Spacing.md) {
                        headerSection
                        riskBanner
                        metricsGrid
                        todayNutritionSection
                        mealStatusSection
                        checklistPreviewSection
                        quickActionsSection
                    }
                    .padding(.horizontal, LockInTheme.Spacing.md)
                    .padding(.vertical, LockInTheme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("LOCKIN")
                        .font(LockInTheme.Font.mono(16, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .tracking(4)
                        .glowAccent(radius: 8)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showWeighInSheet = true
                    } label: {
                        Image(systemName: "scalemass")
                            .foregroundColor(LockInTheme.Colors.accent)
                    }
                }
            }
            .sheet(isPresented: $showWeighInSheet) {
                WeighInSheet(isPresented: $showWeighInSheet, onSave: saveWeighIn)
            }
            .sheet(isPresented: $showCalorieSheet) {
                CalorieLogSheet(
                    isPresented: $showCalorieSheet,
                    currentCalories: todayLog?.actualCalories,
                    currentProtein: todayLog?.actualProtein,
                    onSave: { cal, prot in saveCalories(calories: cal, protein: prot) }
                )
            }
            .sheet(isPresented: $showScreenshotImport) {
                ScreenshotImportView(isPresented: $showScreenshotImport) { cal, prot, carbs, fat in
                    saveCalories(calories: cal, protein: prot, carbs: carbs, fat: fat)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            DataSeeder.ensureTodayLog(in: modelContext)
            WidgetDataStore.sync(log: todayLog, goal: goalProfile, dayNumber: daysSinceStart)
        }
        .onChange(of: todayLog?.complianceScore) { _, _ in
            WidgetDataStore.sync(log: todayLog, goal: goalProfile, dayNumber: daysSinceStart)
        }
        .onChange(of: todayLog?.actualCalories) { _, _ in
            WidgetDataStore.sync(log: todayLog, goal: goalProfile, dayNumber: daysSinceStart)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todayDateString)
                        .font(LockInTheme.Font.label(12))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                    Text("Day \(daysSinceStart)")
                        .font(LockInTheme.Font.title(20))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                }
                Spacer()
                countdownBadge
            }
        }
        .padding(LockInTheme.Spacing.md)
        .cardStyle()
    }

    private var countdownBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(goalProfile?.daysUntilGoal ?? 0)")
                .font(LockInTheme.Font.mono(28, weight: .bold))
                .foregroundColor(LockInTheme.Colors.accent)
                .glowAccent(radius: 10)
            Text("days left")
                .font(LockInTheme.Font.label(10))
                .foregroundColor(LockInTheme.Colors.textSecondary)
        }
    }

    // MARK: - Risk Banner
    @ViewBuilder
    private var riskBanner: some View {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 18 {
            HStack(spacing: LockInTheme.Spacing.sm) {
                Image(systemName: riskIcon)
                    .foregroundColor(riskColor)
                    .font(.system(size: 18, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("TONIGHT: \(nightRisk.rawValue)")
                        .font(LockInTheme.Font.mono(12, weight: .bold))
                        .foregroundColor(riskColor)
                    Text(nightRisk.message)
                        .font(.system(size: 12))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(LockInTheme.Spacing.md)
            .background(riskColor.opacity(0.12))
            .cornerRadius(LockInTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: LockInTheme.Radius.md)
                    .stroke(riskColor.opacity(0.4), lineWidth: 1)
            )
        }
    }

    private var riskColor: Color {
        switch nightRisk {
        case .low:      return LockInTheme.Colors.accentGreen
        case .moderate: return LockInTheme.Colors.accent
        case .high:     return LockInTheme.Colors.accentOrange
        case .critical: return LockInTheme.Colors.accentRed
        }
    }

    private var riskIcon: String {
        switch nightRisk {
        case .low:      return "checkmark.shield"
        case .moderate: return "exclamationmark.triangle"
        case .high:     return "exclamationmark.triangle.fill"
        case .critical: return "xmark.shield.fill"
        }
    }

    // MARK: - Metrics Grid
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LockInTheme.Spacing.sm) {
            MetricCard(label: "CURRENT", value: String(format: "%.1f lb", currentWeight), sublabel: "body weight")
            MetricCard(label: "7-DAY AVG",
                       value: sevenDayAvg != nil ? String(format: "%.1f lb", sevenDayAvg!) : "—",
                       sublabel: "rolling avg")
            MetricCard(label: "CALORIES",
                       value: todayLog?.actualCalories != nil ? "\(todayLog!.actualCalories!) kcal" : "— kcal",
                       sublabel: "target: \(goalProfile?.dailyCalorieTarget ?? 1900)",
                       valueColor: calorieColor)
            MetricCard(label: "PROTEIN",
                       value: todayLog?.actualProtein != nil ? "\(todayLog!.actualProtein!)g" : "—g",
                       sublabel: "target: \(goalProfile?.dailyProteinTarget ?? 145)g",
                       valueColor: proteinColor)
            MetricCard(label: "STREAK",
                       value: "\(currentStreak) days",
                       sublabel: "no-restaurant")
            MetricCard(label: "COMPLIANCE",
                       value: todayLog != nil ? "\(Int(todayLog!.complianceScore))%" : "—%",
                       sublabel: "today",
                       valueColor: complianceColor)
        }
    }

    // MARK: - Today Nutrition
    private var todayNutritionSection: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("TODAY'S NUTRITION")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            VStack(spacing: LockInTheme.Spacing.sm) {
                // Calories
                HStack {
                    Text("Calories")
                        .font(LockInTheme.Font.label(14))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                    Spacer()
                    Text(todayLog?.actualCalories != nil
                         ? "\(todayLog!.actualCalories!) / \(goalProfile?.dailyCalorieTarget ?? 1900)"
                         : "not logged")
                        .font(LockInTheme.Font.mono(14, weight: .semibold))
                        .foregroundColor(calorieColor)
                }
                LockInProgressBar(value: calorieProgress, color: calorieColor)

                // Protein
                HStack {
                    Text("Protein")
                        .font(LockInTheme.Font.label(14))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                    Spacer()
                    Text(todayLog?.actualProtein != nil
                         ? "\(todayLog!.actualProtein!)g / \(goalProfile?.dailyProteinTarget ?? 145)g"
                         : "not logged")
                        .font(LockInTheme.Font.mono(14, weight: .semibold))
                        .foregroundColor(proteinColor)
                }
                LockInProgressBar(value: proteinProgress, color: proteinColor)

                // Carbs + Fat (from screenshot import)
                if todayLog?.actualCarbs != nil || todayLog?.actualFat != nil {
                    Divider().background(LockInTheme.Colors.border)
                    HStack(spacing: LockInTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Carbs")
                                .font(.system(size: 11))
                                .foregroundColor(LockInTheme.Colors.textTertiary)
                            Text(todayLog?.actualCarbs != nil ? "\(todayLog!.actualCarbs!)g" : "—")
                                .font(LockInTheme.Font.mono(14, weight: .semibold))
                                .foregroundColor(LockInTheme.Colors.accentOrange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fat")
                                .font(.system(size: 11))
                                .foregroundColor(LockInTheme.Colors.textTertiary)
                            Text(todayLog?.actualFat != nil ? "\(todayLog!.actualFat!)g" : "—")
                                .font(LockInTheme.Font.mono(14, weight: .semibold))
                                .foregroundColor(LockInTheme.Colors.accentYellow)
                        }
                        Spacer()
                    }
                }
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()

            // Action buttons row
            HStack(spacing: LockInTheme.Spacing.sm) {
                Button {
                    showCalorieSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Update Manually")
                    }
                    .font(LockInTheme.Font.label(12))
                    .foregroundColor(LockInTheme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(LockInTheme.Colors.accent.opacity(0.12))
                    .cornerRadius(LockInTheme.Radius.sm)
                }

                Button {
                    Task { await mndManager.open(.logDiary) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open MND")
                    }
                    .font(LockInTheme.Font.label(12))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(LockInTheme.Colors.surface)
                    .cornerRadius(LockInTheme.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: LockInTheme.Radius.sm)
                            .stroke(LockInTheme.Colors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Meal Status
    private var mealStatusSection: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("MEAL STATUS")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                ForEach([MealSlot.meal1, .meal2, .nightMeal, .emergencySnack], id: \.self) { slot in
                    MealStatusRow(
                        slot: slot,
                        mealEvent: todayLog?.mealEvents.first { $0.slot == slot }
                    )
                    if slot != .emergencySnack {
                        Divider()
                            .background(LockInTheme.Colors.border)
                            .padding(.horizontal, LockInTheme.Spacing.md)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Checklist Preview
    private var checklistPreviewSection: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            HStack {
                Text("CHECKLIST")
                    .sectionHeaderStyle()
                Spacer()
                if let log = todayLog {
                    let done = log.checklistItems.filter { $0.isCompleted }.count
                    let total = log.checklistItems.count
                    Text("\(done)/\(total)")
                        .font(LockInTheme.Font.mono(12))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 4)

            if let log = todayLog {
                DailyChecklistView(log: log)
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("QUICK ACTIONS")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            HStack(spacing: LockInTheme.Spacing.sm) {
                QuickActionButton(icon: "scalemass", label: "Weigh In") {
                    showWeighInSheet = true
                }
                QuickActionButton(icon: "checkmark.icloud", label: "Log MND") {
                    Task { await mndManager.open(.logDiary) }
                }
                QuickActionButton(icon: "flame", label: "Log Cals") {
                    showCalorieSheet = true
                }
            }

            HStack(spacing: LockInTheme.Spacing.sm) {
                QuickActionButton(icon: "camera.viewfinder", label: "Import Screenshot") {
                    showScreenshotImport = true
                }
                QuickActionButton(icon: "fork.knife", label: "Log Food MND") {
                    Task { await mndManager.open(.logFood) }
                }
                QuickActionButton(icon: "chart.bar", label: "Open MND") {
                    Task { await mndManager.open(.openApp) }
                }
            }
        }
    }

    // MARK: - Computed helpers
    private var calorieProgress: Double {
        guard let cal = todayLog?.actualCalories, let target = goalProfile?.dailyCalorieTarget, target > 0
        else { return 0 }
        return Double(cal) / Double(target)
    }

    private var proteinProgress: Double {
        guard let prot = todayLog?.actualProtein, let target = goalProfile?.dailyProteinTarget, target > 0
        else { return 0 }
        return Double(prot) / Double(target)
    }

    private var calorieColor: Color {
        guard let cal = todayLog?.actualCalories, let target = goalProfile?.dailyCalorieTarget else {
            return LockInTheme.Colors.textSecondary
        }
        let tdee = bodyComposition?.tdeeKcal ?? Double(target) * 1.15
        if Double(cal) <= Double(target) { return LockInTheme.Colors.accentGreen }
        if Double(cal) <= tdee           { return LockInTheme.Colors.accentOrange }
        return LockInTheme.Colors.accentRed
    }

    private var proteinColor: Color {
        guard let prot = todayLog?.actualProtein, let target = goalProfile?.dailyProteinTarget else {
            return LockInTheme.Colors.textSecondary
        }
        if prot >= target { return LockInTheme.Colors.accentGreen }
        return LockInTheme.Colors.accentOrange
    }

    private var complianceColor: Color {
        guard let score = todayLog?.complianceScore else { return LockInTheme.Colors.textSecondary }
        if score >= 85 { return LockInTheme.Colors.accentGreen }
        if score >= 65 { return LockInTheme.Colors.accent }
        return LockInTheme.Colors.accentRed
    }

    private var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: .now).uppercased()
    }

    private var daysSinceStart: Int {
        // Count from when first weight entry was made or app installed
        guard let first = weightEntries.last else { return 1 }
        return max(1, Calendar.current.dateComponents([.day], from: first.date, to: .now).day ?? 1)
    }

    private var currentStreak: Int {
        var streak = 0
        let sortedLogs = dailyLogs.sorted { $0.date > $1.date }
        for log in sortedLogs {
            if log.hadRestaurantFood { break }
            streak += 1
        }
        return streak
    }

    // MARK: - Actions
    private func saveWeighIn(weightLb: Double) {
        // Update profile first so the computed BF% is available for the entry
        userProfile?.updateWeightKeepingLBM(weightLb)
        let computedBF = userProfile?.estimatedBodyFatPercent
        let entry = WeightEntry(date: .now, weightLb: weightLb, bodyFatPercent: computedBF, source: .manual)
        modelContext.insert(entry)
        todayLog?.checklist(for: .morningWeighIn)?.isCompleted = true
        todayLog?.checklist(for: .morningWeighIn)?.completedAt = .now
        try? modelContext.save()
        NotificationManager.shared.cancelWeighInFollowUps()
        WidgetDataStore.sync(log: todayLog, goal: goalProfile, dayNumber: daysSinceStart)
    }

    private func saveCalories(calories: Int, protein: Int, carbs: Int = 0, fat: Int = 0) {
        todayLog?.actualCalories = calories
        todayLog?.actualProtein  = protein
        if carbs > 0 { todayLog?.actualCarbs = carbs }
        if fat  > 0 { todayLog?.actualFat   = fat  }
        if protein >= (goalProfile?.dailyProteinTarget ?? 145) {
            todayLog?.checklist(for: .hitProteinTarget)?.isCompleted = true
        }
        if calories <= (goalProfile?.dailyCalorieTarget ?? 1900) {
            todayLog?.checklist(for: .underCalorieTarget)?.isCompleted = true
        }
        if let log = todayLog { log.complianceScore = ComplianceCalculator.score(for: log) }
        try? modelContext.save()
        NotificationManager.shared.cancelFoodLoggingReminders()
        WidgetDataStore.sync(log: todayLog, goal: goalProfile, dayNumber: daysSinceStart)
    }
}

// MARK: - Sub-Views

struct MetricCard: View {
    let label: String
    let value: String
    let sublabel: String
    var valueColor: Color = LockInTheme.Colors.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(LockInTheme.Colors.textTertiary)
                .tracking(1.5)
            Text(value)
                .font(LockInTheme.Font.mono(16, weight: .bold))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(sublabel)
                .font(.system(size: 10))
                .foregroundColor(LockInTheme.Colors.textSecondary)
        }
        .padding(LockInTheme.Spacing.sm + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct MealStatusRow: View {
    let slot: MealSlot
    let mealEvent: MealEvent?

    var body: some View {
        HStack(spacing: LockInTheme.Spacing.sm) {
            Image(systemName: slot.icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(slot.rawValue)
                .font(LockInTheme.Font.label(13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
            Spacer()
            if let event = mealEvent {
                if event.isCompleted {
                    HStack(spacing: 4) {
                        Text("\(event.estimatedCalories) kcal")
                            .font(LockInTheme.Font.mono(12))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(LockInTheme.Colors.accentGreen)
                            .font(.system(size: 14))
                    }
                } else {
                    Text("planned")
                        .font(.system(size: 11))
                        .foregroundColor(LockInTheme.Colors.accent)
                }
            } else {
                Text("not set")
                    .font(.system(size: 11))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, LockInTheme.Spacing.md)
        .padding(.vertical, LockInTheme.Spacing.sm + 2)
    }

    private var iconColor: Color {
        guard let event = mealEvent else { return LockInTheme.Colors.textTertiary }
        return event.isCompleted ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accent
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(LockInTheme.Colors.accent)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LockInTheme.Spacing.sm + 4)
            .cardStyle()
        }
    }
}

// MARK: - Weigh-In Sheet
struct WeighInSheet: View {
    @Binding var isPresented: Bool
    var onSave: (Double) -> Void
    @State private var weightText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                VStack(spacing: LockInTheme.Spacing.lg) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 48))
                        .foregroundColor(LockInTheme.Colors.accent)
                    Text("Morning Weigh-In")
                        .font(LockInTheme.Font.title(24))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("Before food or water. Same time every day.")
                        .font(LockInTheme.Font.label(14))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    HStack {
                        TextField("170.0", text: $weightText)
                            .font(LockInTheme.Font.mono(32, weight: .bold))
                            .foregroundColor(LockInTheme.Colors.textPrimary)
                            .keyboardType(.decimalPad)
                            .focused($focused)
                            .multilineTextAlignment(.center)
                        Text("lb")
                            .font(LockInTheme.Font.mono(20))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                    .padding()
                    .cardStyle()
                    .padding(.horizontal)

                    Button {
                        if let w = Double(weightText), w > 0 {
                            onSave(w)
                            isPresented = false
                        }
                    } label: {
                        Text("LOG WEIGHT")
                            .font(LockInTheme.Font.label(15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LockInTheme.Colors.accent)
                            .cornerRadius(LockInTheme.Radius.md)
                    }
                    .padding(.horizontal)
                    .disabled(Double(weightText) == nil)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
            .onAppear { focused = true }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Calorie Log Sheet
struct CalorieLogSheet: View {
    @Binding var isPresented: Bool
    var currentCalories: Int?
    var currentProtein: Int?
    var onSave: (Int, Int) -> Void
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @FocusState private var focusedField: Field?
    enum Field { case calories, protein }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                VStack(spacing: LockInTheme.Spacing.lg) {
                    Text("Update Today's Intake")
                        .font(LockInTheme.Font.title(22))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("Pull from MyNetDiary and enter here.")
                        .font(LockInTheme.Font.label(13))
                        .foregroundColor(LockInTheme.Colors.textSecondary)

                    VStack(spacing: LockInTheme.Spacing.sm) {
                        HStack {
                            Text("Calories")
                                .font(LockInTheme.Font.label(15))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                                .frame(width: 80, alignment: .leading)
                            TextField(String(currentCalories ?? 0), text: $caloriesText)
                                .font(LockInTheme.Font.mono(20, weight: .semibold))
                                .foregroundColor(LockInTheme.Colors.textPrimary)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .calories)
                                .multilineTextAlignment(.trailing)
                            Text("kcal")
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        .padding()
                        .cardStyle()

                        HStack {
                            Text("Protein")
                                .font(LockInTheme.Font.label(15))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                                .frame(width: 80, alignment: .leading)
                            TextField(String(currentProtein ?? 0), text: $proteinText)
                                .font(LockInTheme.Font.mono(20, weight: .semibold))
                                .foregroundColor(LockInTheme.Colors.textPrimary)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .protein)
                                .multilineTextAlignment(.trailing)
                            Text("g")
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        .padding()
                        .cardStyle()
                    }
                    .padding(.horizontal)

                    Button {
                        let cal = Int(caloriesText) ?? currentCalories ?? 0
                        let prot = Int(proteinText) ?? currentProtein ?? 0
                        onSave(cal, prot)
                        isPresented = false
                    } label: {
                        Text("SAVE")
                            .font(LockInTheme.Font.label(15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LockInTheme.Colors.accent)
                            .cornerRadius(LockInTheme.Radius.md)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, LockInTheme.Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
            .onAppear {
                caloriesText = currentCalories != nil ? String(currentCalories!) : ""
                proteinText = currentProtein != nil ? String(currentProtein!) : ""
                focusedField = .calories
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview
#Preview {
    TodayView()
        .modelContainer(for: [UserProfile.self, GoalProfile.self, DailyLog.self,
                               WeightEntry.self, MealTemplate.self, TDEEAdjustmentState.self,
                               ReminderRule.self, ExternalIntegrationStatus.self,
                               MealEvent.self, ChecklistEntry.self, AdherenceMetric.self,
                               WorkoutEntry.self], inMemory: true)
}
