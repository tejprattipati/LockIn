// ProgressView.swift
// Analytics hub: weight trend, compliance, body composition, TDEE engine.

import SwiftUI
import SwiftData
import Charts

struct CutProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .forward) private var weightEntries: [WeightEntry]
    @Query(sort: \AdherenceMetric.date, order: .forward) private var adherenceMetrics: [AdherenceMetric]
    @Query private var userProfiles: [UserProfile]
    @Query private var goalProfiles: [GoalProfile]
    @Query private var tdeeStates: [TDEEAdjustmentState]

    @State private var selectedView: ProgressSection = .weight
    @State private var showBodyComp = false

    enum ProgressSection: String, CaseIterable {
        case weight     = "Weight"
        case compliance = "Compliance"
        case bodyComp   = "Body Comp"
        case engine     = "TDEE Engine"
        case photos     = "Photos"
    }

    private var userProfile: UserProfile? { userProfiles.first }
    private var goalProfile: GoalProfile? { goalProfiles.first }
    private var tdeeState: TDEEAdjustmentState? { tdeeStates.first }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    segmentPicker
                    Divider().background(LockInTheme.Colors.border)
                    ScrollView {
                        VStack(spacing: LockInTheme.Spacing.md) {
                            switch selectedView {
                            case .weight:     weightSection
                            case .compliance: complianceSection
                            case .bodyComp:   bodyCompSection
                            case .engine:     tdeeEngineSection
                            case .photos:     ProgressPhotoView()
                            }
                        }
                        .padding(LockInTheme.Spacing.md)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PROGRESS")
                        .font(LockInTheme.Font.mono(14, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .tracking(3)
                        .glowAccent(radius: 8)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Segment Picker
    private var segmentPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(ProgressSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation { selectedView = section }
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 13, weight: selectedView == section ? .semibold : .regular))
                            .foregroundColor(selectedView == section ? LockInTheme.Colors.accent : LockInTheme.Colors.textSecondary)
                            .padding(.horizontal, LockInTheme.Spacing.md)
                            .padding(.vertical, LockInTheme.Spacing.sm + 2)
                    }
                    if selectedView == section {
                        Color.clear.frame(height: 2)
                    }
                }
            }
            .background(
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(ProgressSection.allCases, id: \.self) { section in
                            Rectangle()
                                .fill(selectedView == section ? LockInTheme.Colors.accent : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
            )
        }
        .background(LockInTheme.Colors.background)
    }

    // MARK: - Weight Section
    private var weightSection: some View {
        VStack(spacing: LockInTheme.Spacing.md) {
            // Stats row
            if let goal = goalProfile {
                let current = weightEntries.last?.weightLb ?? userProfile?.currentWeight ?? 170
                let avg7 = CalculationEngine.currentSevenDayAverage(from: Array(weightEntries.suffix(7)))
                let poundsToGo = current - goal.targetWeight

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: LockInTheme.Spacing.sm) {
                    MetricCard(label: "CURRENT", value: String(format: "%.1f", current), sublabel: "")
                    MetricCard(label: "7-DAY AVG", value: avg7 != nil ? String(format: "%.1f", avg7!) : "—", sublabel: "")
                    MetricCard(label: "TO GOAL", value: String(format: "%.1f", poundsToGo) + " lb", sublabel: "",
                               valueColor: poundsToGo > 0 ? LockInTheme.Colors.accentOrange : LockInTheme.Colors.accentGreen)
                }
            }

            // Weight chart
            WeightChartView(entries: weightEntries, goalWeight: goalProfile?.targetWeight ?? 147)

            // Projection
            if let goal = goalProfile, let tdeeState = tdeeState {
                let projection = CalculationEngine.goalProjection(
                    currentWeight: weightEntries.last?.weightLb ?? 170,
                    targetWeight: goal.targetWeight,
                    goalDate: goal.goalDate,
                    weeklyLossRate: tdeeState.rollingExpectedWeightLoss,
                    sevenDayAvg: CalculationEngine.currentSevenDayAverage(from: Array(weightEntries.suffix(7)))
                )
                ProjectionCard(projection: projection, goalDate: goal.goalDate)
            }
        }
    }

    // MARK: - Compliance Section
    private var complianceSection: some View {
        VStack(spacing: LockInTheme.Spacing.md) {
            ComplianceChartView(metrics: adherenceMetrics)
            ComplianceStreaksCard(metrics: adherenceMetrics)
            ComplianceCategoryBreakdown(metrics: adherenceMetrics)
        }
    }

    // MARK: - Body Comp Section
    private var bodyCompSection: some View {
        VStack(spacing: LockInTheme.Spacing.md) {
            if let profile = userProfile, let goal = goalProfile {
                let bfEst = weightEntries.last?.bodyFatPercent ?? profile.estimatedBodyFatPercent
                let result = CalculationEngine.compute(
                    weightLb: weightEntries.last?.weightLb ?? profile.currentWeight,
                    heightInches: profile.heightInches,
                    bodyFatPercent: bfEst,
                    activityLevel: profile.activityLevel,
                    targetCalories: goal.dailyCalorieTarget
                )
                BodyCompositionCard(result: result)
                ExplanationCard(lines: result.explanationLines)
            }
        }
    }

    // MARK: - TDEE Engine Section
    private var tdeeEngineSection: some View {
        VStack(spacing: LockInTheme.Spacing.md) {
            if let state = tdeeState {
                TDEEEngineCard(state: state)
                if !state.weeklyCheckpoints.isEmpty {
                    WeeklyCheckpointList(checkpoints: state.weeklyCheckpoints)
                }
            } else {
                Text("TDEE engine will activate after 10 weigh-ins.")
                    .font(LockInTheme.Font.label(14))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .padding()
            }
        }
    }
}

// MARK: - Weight Chart
struct WeightChartView: View {
    let entries: [WeightEntry]
    let goalWeight: Double

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("WEIGHT TREND")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            if entries.isEmpty {
                Text("No weight entries yet. Weigh in every morning.")
                    .font(LockInTheme.Font.label(13))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .cardStyle()
            } else {
                Chart {
                    ForEach(entries.suffix(30)) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weightLb)
                        )
                        .foregroundStyle(LockInTheme.Colors.accent)
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(20)

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weightLb)
                        )
                        .foregroundStyle(LockInTheme.Colors.accent.opacity(0.6))
                        .symbolSize(8)
                    }

                    // 7-day moving average
                    ForEach(movingAverages(entries: Array(entries.suffix(30)), window: 7), id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Avg", point.value)
                        )
                        .foregroundStyle(LockInTheme.Colors.textSecondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }

                    // Goal line
                    RuleMark(y: .value("Goal", goalWeight))
                        .foregroundStyle(LockInTheme.Colors.accentGreen.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .annotation(position: .trailing) {
                            Text("goal")
                                .font(.system(size: 9))
                                .foregroundColor(LockInTheme.Colors.accentGreen.opacity(0.7))
                        }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine().foregroundStyle(LockInTheme.Colors.border)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(LockInTheme.Colors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(LockInTheme.Colors.border)
                        AxisValueLabel()
                            .foregroundStyle(LockInTheme.Colors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
                .padding(LockInTheme.Spacing.md)
                .cardStyle()
            }
        }
    }

    private struct AvgPoint { let date: Date; let value: Double }

    private func movingAverages(entries: [WeightEntry], window: Int) -> [AvgPoint] {
        guard entries.count >= window else { return [] }
        return entries.enumerated().compactMap { (i, entry) in
            guard i >= window - 1 else { return nil }
            let slice = entries[(i - window + 1)...i]
            let avg = slice.map { $0.weightLb }.reduce(0, +) / Double(window)
            return AvgPoint(date: entry.date, value: avg)
        }
    }
}

// MARK: - Projection Card
struct ProjectionCard: View {
    let projection: GoalProjection
    let goalDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("GOAL PROJECTION")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            VStack(spacing: LockInTheme.Spacing.sm) {
                StatRow(
                    label: "Current pace",
                    value: String(format: "%.2f lb/week", projection.weeklyLossRate)
                )
                StatRow(
                    label: "Projected goal date",
                    value: dateString(projection.projectedDate),
                    valueColor: projection.isOnTrack ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accentRed
                )
                StatRow(
                    label: "Actual goal date",
                    value: dateString(goalDate)
                )
                StatRow(
                    label: "On track",
                    value: projection.isOnTrack ? "YES" : "NO — behind",
                    valueColor: projection.isOnTrack ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accentRed
                )
                StatRow(
                    label: "Pounds remaining",
                    value: String(format: "%.1f lb", projection.poundsToLose)
                )
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

// MARK: - Compliance Chart
struct ComplianceChartView: View {
    let metrics: [AdherenceMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("30-DAY COMPLIANCE")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            if metrics.isEmpty {
                Text("No data yet. Start checking off your daily items.")
                    .font(.system(size: 13))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 140)
                    .cardStyle()
            } else {
                let recent = Array(metrics.suffix(30))
                Chart(recent) { metric in
                    BarMark(
                        x: .value("Date", metric.date),
                        y: .value("Score", metric.complianceScore)
                    )
                    .foregroundStyle(barColor(metric.complianceScore))
                    .cornerRadius(2)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine().foregroundStyle(LockInTheme.Colors.border)
                        AxisValueLabel(format: .dateTime.day())
                            .foregroundStyle(LockInTheme.Colors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 50, 75, 100]) { _ in
                        AxisGridLine().foregroundStyle(LockInTheme.Colors.border)
                        AxisValueLabel()
                            .foregroundStyle(LockInTheme.Colors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
                .chartYScale(domain: 0...100)
                .padding(LockInTheme.Spacing.md)
                .cardStyle()
            }
        }
    }

    private func barColor(_ score: Double) -> Color {
        if score >= 85 { return LockInTheme.Colors.accentGreen }
        if score >= 65 { return LockInTheme.Colors.accent }
        if score >= 40 { return LockInTheme.Colors.accentOrange }
        return LockInTheme.Colors.accentRed
    }
}

// MARK: - Compliance Streaks
struct ComplianceStreaksCard: View {
    let metrics: [AdherenceMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("STREAKS")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            let sorted = metrics.sorted { $0.date > $1.date }

            VStack(spacing: LockInTheme.Spacing.sm) {
                StreakRow(label: "No restaurant food", count: streak(sorted, keyPath: \.noRestaurantFood))
                StreakRow(label: "No dessert",          count: streak(sorted, keyPath: \.noDessert))
                StreakRow(label: "Morning weigh-in",    count: streak(sorted, keyPath: \.weighedIn))
                StreakRow(label: "Hit protein",         count: streak(sorted, keyPath: \.hitProtein))
                StreakRow(label: "Under calories",      count: streak(sorted, keyPath: \.underCalories))
                StreakRow(label: "Logged in MND",       count: streak(sorted, keyPath: \.loggedInMND))
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()
        }
    }

    private func streak(_ metrics: [AdherenceMetric], keyPath: KeyPath<AdherenceMetric, Bool>) -> Int {
        var count = 0
        for m in metrics {
            if m[keyPath: keyPath] { count += 1 } else { break }
        }
        return count
    }
}

struct StreakRow: View {
    let label: String
    let count: Int

    var body: some View {
        HStack {
            Text(label)
                .font(LockInTheme.Font.label(13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
            Spacer()
            HStack(spacing: 3) {
                Text("\(count)")
                    .font(LockInTheme.Font.mono(16, weight: .bold))
                    .foregroundColor(count >= 7 ? LockInTheme.Colors.accentGreen : (count >= 3 ? LockInTheme.Colors.accent : LockInTheme.Colors.textPrimary))
                Text("days")
                    .font(.system(size: 11))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
            }
        }
    }
}

// MARK: - Compliance Category Breakdown
struct ComplianceCategoryBreakdown: View {
    let metrics: [AdherenceMetric]

    private var recent30: [AdherenceMetric] { Array(metrics.suffix(30)) }

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("30-DAY RATE")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            VStack(spacing: LockInTheme.Spacing.sm) {
                CategoryRateRow(label: "No restaurant food", rate: rate(\.noRestaurantFood))
                CategoryRateRow(label: "No dessert",          rate: rate(\.noDessert))
                CategoryRateRow(label: "Under calories",      rate: rate(\.underCalories))
                CategoryRateRow(label: "Hit protein",         rate: rate(\.hitProtein))
                CategoryRateRow(label: "Morning weigh-in",    rate: rate(\.weighedIn))
                CategoryRateRow(label: "Logged in MND",       rate: rate(\.loggedInMND))
                CategoryRateRow(label: "Logged all meals",    rate: rate(\.loggedAllMeals))
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()
        }
    }

    private func rate(_ keyPath: KeyPath<AdherenceMetric, Bool>) -> Double {
        guard !recent30.isEmpty else { return 0 }
        let success = recent30.filter { $0[keyPath: keyPath] }.count
        return Double(success) / Double(recent30.count)
    }
}

struct CategoryRateRow: View {
    let label: String
    let rate: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(LockInTheme.Font.label(12))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                Spacer()
                Text("\(Int(rate * 100))%")
                    .font(LockInTheme.Font.mono(12, weight: .semibold))
                    .foregroundColor(barColor(rate))
            }
            LockInProgressBar(value: rate, color: barColor(rate), height: 3)
        }
    }

    private func barColor(_ r: Double) -> Color {
        if r >= 0.85 { return LockInTheme.Colors.accentGreen }
        if r >= 0.65 { return LockInTheme.Colors.accent }
        if r >= 0.45 { return LockInTheme.Colors.accentOrange }
        return LockInTheme.Colors.accentRed
    }
}

// MARK: - Body Composition Card
struct BodyCompositionCard: View {
    let result: BodyCompositionResult

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("BODY COMPOSITION")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            VStack(spacing: LockInTheme.Spacing.sm) {
                StatRow(label: "Body Weight",      value: String(format: "%.1f lb", result.weightLb))
                StatRow(label: "Body Fat %",       value: String(format: "%.1f%%", result.bodyFatPercent))
                StatRow(label: "Lean Body Mass",   value: String(format: "%.1f lb", result.leanBodyMassLb))
                StatRow(label: "Fat Mass",         value: String(format: "%.1f lb", result.fatMassLb))
                Divider().background(LockInTheme.Colors.border)
                StatRow(label: "BMR (\(result.bmrMethod.components(separatedBy: " (").first ?? ""))",
                        value: String(format: "%.0f kcal/day", result.bmrKcal))
                StatRow(label: "Conservative TDEE",
                        value: String(format: "%.0f kcal/day", result.tdeeKcal),
                        caption: "×\(String(format: "%.2f", result.activityMultiplier)) × 0.95 haircut")
                StatRow(label: "Target Calories",
                        value: "\(result.targetCalories) kcal/day")
                StatRow(label: "Daily Deficit",
                        value: String(format: "%.0f kcal/day", result.currentDeficit),
                        valueColor: LockInTheme.Colors.accent)
                StatRow(label: "Expected Loss",
                        value: String(format: "%.2f lb/week", result.expectedWeeklyLossLb),
                        valueColor: LockInTheme.Colors.accent)
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()
        }
    }
}

// MARK: - Explanation Card
struct ExplanationCard: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("CALCULATION NOTES")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(LockInTheme.Colors.accent)
                        Text(line)
                            .font(.system(size: 11))
                            .foregroundColor(LockInTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()
        }
    }
}

// MARK: - TDEE Engine Card
struct TDEEEngineCard: View {
    let state: TDEEAdjustmentState

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("ADAPTIVE TDEE ENGINE")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            VStack(spacing: LockInTheme.Spacing.sm) {
                StatRow(label: "Initial TDEE estimate",  value: String(format: "%.0f kcal/day", state.initialEstimatedTDEE))
                StatRow(label: "Current TDEE estimate",  value: String(format: "%.0f kcal/day", state.currentAdjustedTDEE),
                        valueColor: LockInTheme.Colors.accent)
                StatRow(label: "Cumulative adjustment",
                        value: String(format: "%+.0f kcal/day", state.cumulativeAdjustment),
                        valueColor: state.cumulativeAdjustment < 0 ? LockInTheme.Colors.accentRed : LockInTheme.Colors.accentGreen)
                StatRow(label: "Status",                 value: state.correctionDirection.rawValue.components(separatedBy: " (").first ?? "")
                StatRow(label: "Expected loss",          value: String(format: "%.2f lb/week", state.rollingExpectedWeightLoss))
                if let actual = state.rollingActualWeightLoss {
                    StatRow(label: "Actual loss (rolling)",
                            value: String(format: "%.2f lb/week", actual),
                            valueColor: actual >= state.rollingExpectedWeightLoss * 0.8 ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accentOrange)
                }
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()

            if !state.explanationText.isEmpty {
                Text(state.explanationText)
                    .font(.system(size: 11))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
                    .padding(LockInTheme.Spacing.md)
                    .cardStyle()
            }
        }
    }
}

// MARK: - Weekly Checkpoint List
struct WeeklyCheckpointList: View {
    let checkpoints: [WeeklyCheckpoint]

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("WEEKLY EVALUATIONS")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)

            VStack(spacing: LockInTheme.Spacing.sm) {
                ForEach(checkpoints.suffix(5)) { cp in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(weekLabel(cp.weekStartDate))
                                .font(LockInTheme.Font.mono(11, weight: .semibold))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                            Spacer()
                            Text(cp.performanceLabel)
                                .font(.system(size: 10))
                                .foregroundColor(performanceColor(cp.discrepancy))
                        }
                        HStack(spacing: LockInTheme.Spacing.md) {
                            Text("Expected: \(String(format: "%.2f", cp.expectedLossPounds)) lb")
                            Text("Actual: \(String(format: "%.2f", cp.actualLossPounds)) lb")
                            Text("Correction: \(String(format: "%+.0f", cp.correctionApplied)) kcal")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                    }
                    .padding(LockInTheme.Spacing.sm + 4)
                    .cardStyle()
                }
            }
        }
    }

    private func weekLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Week of \(f.string(from: date))"
    }

    private func performanceColor(_ discrepancy: Double) -> Color {
        if abs(discrepancy) < 0.2 { return LockInTheme.Colors.accentGreen }
        if discrepancy < 0 { return LockInTheme.Colors.accentOrange }
        return LockInTheme.Colors.accent
    }
}

#Preview {
    CutProgressView()
        .modelContainer(for: [UserProfile.self, GoalProfile.self, WeightEntry.self,
                               AdherenceMetric.self, TDEEAdjustmentState.self], inMemory: true)
}
