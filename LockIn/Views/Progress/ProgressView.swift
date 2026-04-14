// ProgressView.swift
// Analytics hub: weight trend, charts, body composition, TDEE engine.

import SwiftUI
import SwiftData
import Charts

struct CutProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .forward) private var weightEntries: [WeightEntry]
    @Query(sort: \DailyLog.date, order: .forward) private var dailyLogs: [DailyLog]
    @Query private var userProfiles: [UserProfile]
    @Query private var goalProfiles: [GoalProfile]
    @Query private var tdeeStates: [TDEEAdjustmentState]

    @State private var selectedView: ProgressSection = .weight

    enum ProgressSection: String, CaseIterable {
        case weight   = "Weight"
        case charts   = "Charts"
        case bodyComp = "Body Comp"
        case engine   = "TDEE Engine"
        case photos   = "Photos"
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
                            case .weight:   weightSection
                            case .charts:   InteractiveChartsView(weightEntries: weightEntries, dailyLogs: dailyLogs, goalWeight: goalProfile?.targetWeight ?? 147)
                            case .bodyComp: bodyCompSection
                            case .engine:   tdeeEngineSection
                            case .photos:   ProgressPhotoView()
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
                    targetCalories: goal.dailyCalorieTarget,
                    goalWeightLb: goal.targetWeight
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
                Divider().background(LockInTheme.Colors.border)
                let for1lb  = max(1200, Int(result.tdeeKcal) - 500)
                let for15lb = max(1000, Int(result.tdeeKcal) - 750)
                StatRow(label: "Budget → 1 lb/wk",   value: "\(for1lb) kcal/day",  valueColor: LockInTheme.Colors.accentGreen)
                StatRow(label: "Budget → 1.5 lb/wk", value: "\(for15lb) kcal/day", valueColor: LockInTheme.Colors.accentOrange)
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

// MARK: - Interactive Charts View
struct InteractiveChartsView: View {
    let weightEntries: [WeightEntry]
    let dailyLogs: [DailyLog]
    let goalWeight: Double

    var body: some View {
        VStack(spacing: LockInTheme.Spacing.md) {
            InteractiveWeightChart(entries: weightEntries, goalWeight: goalWeight)
            InteractiveScoreChart(logs: dailyLogs)
        }
    }
}

// MARK: - Interactive Weight Chart
struct InteractiveWeightChart: View {
    let entries: [WeightEntry]
    let goalWeight: Double

    @State private var selectedDate: Date?

    private var display: [WeightEntry] { Array(entries.suffix(60)) }
    private var selected: WeightEntry? {
        guard let d = selectedDate else { return nil }
        return display.min(by: { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) })
    }
    private var movingAvgs: [(date: Date, value: Double)] {
        guard display.count >= 7 else { return [] }
        return display.enumerated().compactMap { i, e in
            guard i >= 6 else { return nil }
            let w = display[(i-6)...i]
            return (date: e.date, value: w.map { $0.weightLb }.reduce(0,+) / 7.0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            HStack {
                Text("WEIGHT OVER TIME").sectionHeaderStyle()
                Spacer()
                if let e = selected {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.1f lb", e.weightLb))
                            .font(LockInTheme.Font.mono(13, weight: .semibold))
                            .foregroundColor(LockInTheme.Colors.accent)
                            .glowAccent(radius: 4)
                        Text(fmtDate(e.date))
                            .font(.system(size: 10))
                            .foregroundColor(LockInTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 4)

            if display.isEmpty {
                Text("No weigh-ins yet. Log your weight every morning.")
                    .font(.system(size: 13))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 200)
                    .cardStyle()
            } else {
                Chart {
                    ForEach(display) { e in
                        AreaMark(x: .value("Date", e.date), y: .value("lb", e.weightLb))
                            .foregroundStyle(LinearGradient(
                                colors: [LockInTheme.Colors.accent.opacity(0.15), .clear],
                                startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Date", e.date), y: .value("lb", e.weightLb))
                            .foregroundStyle(LockInTheme.Colors.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                    }
                    ForEach(movingAvgs, id: \.date) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("Avg", pt.value))
                            .foregroundStyle(LockInTheme.Colors.textSecondary.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .interpolationMethod(.catmullRom)
                    }
                    RuleMark(y: .value("Goal", goalWeight))
                        .foregroundStyle(LockInTheme.Colors.accentGreen.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .annotation(position: .trailing, spacing: 4) {
                            Text("goal").font(.system(size: 9))
                                .foregroundColor(LockInTheme.Colors.accentGreen.opacity(0.7))
                        }
                    if let e = selected {
                        RuleMark(x: .value("Sel", e.date))
                            .foregroundStyle(LockInTheme.Colors.accent.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        PointMark(x: .value("Date", e.date), y: .value("lb", e.weightLb))
                            .foregroundStyle(LockInTheme.Colors.accent)
                            .symbolSize(50)
                    }
                }
                .frame(height: 210)
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, display.count / 5))) { _ in
                        AxisGridLine().foregroundStyle(LockInTheme.Colors.border)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(LockInTheme.Colors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(LockInTheme.Colors.border)
                        AxisValueLabel().foregroundStyle(LockInTheme.Colors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
                .padding(LockInTheme.Spacing.md)
                .cardStyle()
            }
        }
    }

    private func fmtDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}

// MARK: - Interactive Score Chart
struct InteractiveScoreChart: View {
    let logs: [DailyLog]

    @State private var selectedDate: Date?

    private var scored: [DailyLog] { Array(logs.filter { $0.complianceScore > 0 }.suffix(60)) }
    private var selected: DailyLog? {
        guard let d = selectedDate else { return nil }
        return scored.min(by: { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            HStack {
                Text("DAILY SCORE OVER TIME").sectionHeaderStyle()
                Spacer()
                if let log = selected {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(log.complianceScore)) pts")
                            .font(LockInTheme.Font.mono(13, weight: .semibold))
                            .foregroundColor(scoreColor(log.complianceScore))
                        Text(fmtDate(log.date))
                            .font(.system(size: 10))
                            .foregroundColor(LockInTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 4)

            if scored.isEmpty {
                Text("No score data yet. Complete your daily checklist items.")
                    .font(.system(size: 13))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 180)
                    .cardStyle()
            } else {
                Chart {
                    ForEach(scored) { log in
                        AreaMark(x: .value("Date", log.date), y: .value("Score", log.complianceScore))
                            .foregroundStyle(LinearGradient(
                                colors: [LockInTheme.Colors.accentGreen.opacity(0.12), .clear],
                                startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Date", log.date), y: .value("Score", log.complianceScore))
                            .foregroundStyle(LockInTheme.Colors.accentGreen)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                    }
                    RuleMark(y: .value("Target", 85))
                        .foregroundStyle(LockInTheme.Colors.accent.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .annotation(position: .trailing, spacing: 4) {
                            Text("85").font(.system(size: 9))
                                .foregroundColor(LockInTheme.Colors.accent.opacity(0.6))
                        }
                    if let log = selected {
                        RuleMark(x: .value("Sel", log.date))
                            .foregroundStyle(LockInTheme.Colors.accentGreen.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        PointMark(x: .value("Date", log.date), y: .value("Score", log.complianceScore))
                            .foregroundStyle(scoreColor(log.complianceScore))
                            .symbolSize(50)
                    }
                }
                .frame(height: 190)
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, scored.count / 5))) { _ in
                        AxisGridLine().foregroundStyle(LockInTheme.Colors.border)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(LockInTheme.Colors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { _ in
                        AxisGridLine().foregroundStyle(LockInTheme.Colors.border)
                        AxisValueLabel().foregroundStyle(LockInTheme.Colors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
                .padding(LockInTheme.Spacing.md)
                .cardStyle()
            }
        }
    }

    private func scoreColor(_ s: Double) -> Color {
        if s >= 85 { return LockInTheme.Colors.accentGreen }
        if s >= 65 { return LockInTheme.Colors.accent }
        if s >= 40 { return LockInTheme.Colors.accentOrange }
        return LockInTheme.Colors.accentRed
    }
    private func fmtDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}

#Preview {
    CutProgressView()
        .modelContainer(for: [UserProfile.self, GoalProfile.self, WeightEntry.self,
                               DailyLog.self, TDEEAdjustmentState.self], inMemory: true)
}
