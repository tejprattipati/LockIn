// PastDayLogSheet.swift
// History browser + per-day editor.
// Lets the user go back to any previous day and adjust nutrition,
// macros, and checklist items after the fact.

import SwiftUI
import SwiftData

// MARK: - History List
struct PastDayLogSheet: View {
    @Binding var isPresented: Bool
    let goalProfile: GoalProfile?

    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]
    @State private var editingLog: DailyLog?

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                if allLogs.isEmpty {
                    VStack(spacing: LockInTheme.Spacing.sm) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 36))
                            .foregroundColor(LockInTheme.Colors.textTertiary)
                        Text("No days logged yet.")
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(allLogs) { log in
                            HistoryDayRow(log: log)
                                .listRowBackground(LockInTheme.Colors.surface)
                                .listRowSeparatorTint(LockInTheme.Colors.border)
                                .contentShape(Rectangle())
                                .onTapGesture { editingLog = log }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("LOG HISTORY")
                        .font(LockInTheme.Font.mono(12, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .tracking(2)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
            .sheet(item: $editingLog) { log in
                PastDayEditSheet(log: log, goalProfile: goalProfile)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - History Row
struct HistoryDayRow: View {
    let log: DailyLog

    var body: some View {
        HStack(spacing: LockInTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dayLabel)
                    .font(LockInTheme.Font.label(14, weight: .semibold))
                    .foregroundColor(LockInTheme.Colors.textPrimary)
                HStack(spacing: 10) {
                    if let cal = log.actualCalories {
                        Text("\(cal) kcal")
                            .font(LockInTheme.Font.mono(11))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                    if let prot = log.actualProtein {
                        Text("\(prot)g pro")
                            .font(LockInTheme.Font.mono(11))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                    if log.actualCalories == nil && log.actualProtein == nil {
                        Text("no nutrition logged")
                            .font(.system(size: 11))
                            .foregroundColor(LockInTheme.Colors.textTertiary)
                    }
                }
            }
            Spacer()
            if log.complianceScore > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(log.complianceScore))")
                        .font(LockInTheme.Font.mono(16, weight: .bold))
                        .foregroundColor(scoreColor)
                    Text("pts")
                        .font(.system(size: 10))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                }
            } else {
                Text("—")
                    .font(LockInTheme.Font.mono(16))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private var dayLabel: String {
        if Calendar.current.isDateInToday(log.date)     { return "Today" }
        if Calendar.current.isDateInYesterday(log.date) {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return "Yesterday · \(f.string(from: log.date))"
        }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: log.date)
    }

    private var scoreColor: Color {
        if log.complianceScore >= 85 { return LockInTheme.Colors.accentGreen }
        if log.complianceScore >= 65 { return LockInTheme.Colors.accent }
        return LockInTheme.Colors.accentOrange
    }
}

// MARK: - Per-Day Edit Sheet
struct PastDayEditSheet: View {
    @Bindable var log: DailyLog
    let goalProfile: GoalProfile?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var caloriesText = ""
    @State private var proteinText  = ""
    @State private var carbsText    = ""
    @State private var fatText      = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: LockInTheme.Spacing.md) {

                        // Date + score header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dateTitle)
                                    .font(LockInTheme.Font.title(18))
                                    .foregroundColor(LockInTheme.Colors.textPrimary)
                                Text(dateSubtitle)
                                    .font(LockInTheme.Font.label(12))
                                    .foregroundColor(LockInTheme.Colors.textSecondary)
                            }
                            Spacer()
                            if log.complianceScore > 0 {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(Int(log.complianceScore))")
                                        .font(LockInTheme.Font.mono(22, weight: .bold))
                                        .foregroundColor(headerScoreColor)
                                    Text("pts")
                                        .font(.system(size: 11))
                                        .foregroundColor(LockInTheme.Colors.textTertiary)
                                }
                            }
                        }
                        .padding(LockInTheme.Spacing.md)
                        .cardStyle()

                        // Nutrition
                        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                            Text("NUTRITION")
                                .sectionHeaderStyle()
                                .padding(.horizontal, 4)
                            macroField("Calories", unit: "kcal", text: $caloriesText)
                            macroField("Protein",  unit: "g",    text: $proteinText)
                            macroField("Carbs",    unit: "g",    text: $carbsText)
                            macroField("Fat",      unit: "g",    text: $fatText)
                        }

                        // Checklist
                        if !log.checklistItems.isEmpty {
                            VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                                Text("CHECKLIST")
                                    .sectionHeaderStyle()
                                    .padding(.horizontal, 4)
                                ForEach(log.checklistItems.sorted { $0.category.weight > $1.category.weight }) { item in
                                    PastChecklistRow(item: item) {
                                        log.complianceScore = ComplianceCalculator.score(for: log)
                                        try? modelContext.save()
                                    }
                                }
                            }
                        }
                    }
                    .padding(LockInTheme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT DAY")
                        .font(LockInTheme.Font.mono(12, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .tracking(2)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(LockInTheme.Colors.accent)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                caloriesText = log.actualCalories.map { String($0) } ?? ""
                proteinText  = log.actualProtein.map  { String($0) } ?? ""
                carbsText    = log.actualCarbs.map    { String($0) } ?? ""
                fatText      = log.actualFat.map      { String($0) } ?? ""
            }
        }
        .preferredColorScheme(.dark)
    }

    private var dateTitle: String {
        if Calendar.current.isDateInToday(log.date)     { return "Today" }
        if Calendar.current.isDateInYesterday(log.date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: log.date)
    }

    private var dateSubtitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM d, yyyy"
        return f.string(from: log.date)
    }

    private var headerScoreColor: Color {
        if log.complianceScore >= 85 { return LockInTheme.Colors.accentGreen }
        if log.complianceScore >= 65 { return LockInTheme.Colors.accent }
        return LockInTheme.Colors.accentOrange
    }

    private func macroField(_ label: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(LockInTheme.Font.label(14))
                .foregroundColor(LockInTheme.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)
            TextField("0", text: text)
                .font(LockInTheme.Font.mono(18, weight: .semibold))
                .foregroundColor(LockInTheme.Colors.textPrimary)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .font(LockInTheme.Font.mono(13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
        }
        .padding(LockInTheme.Spacing.md)
        .cardStyle()
    }

    private func save() {
        log.actualCalories = Int(caloriesText)
        log.actualProtein  = Int(proteinText)
        log.actualCarbs    = Int(carbsText)
        log.actualFat      = Int(fatText)

        let calTarget  = goalProfile?.dailyCalorieTarget ?? log.calorieTarget
        let protTarget = goalProfile?.dailyProteinTarget ?? log.proteinTarget
        if let cal  = log.actualCalories { log.checklist(for: .underCalorieTarget)?.isCompleted = cal  <= calTarget  }
        if let prot = log.actualProtein  { log.checklist(for: .hitProteinTarget)?.isCompleted   = prot >= protTarget }

        log.complianceScore = ComplianceCalculator.score(for: log)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Checklist Toggle Row
struct PastChecklistRow: View {
    @Bindable var item: ChecklistEntry
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: LockInTheme.Spacing.sm) {
            Toggle("", isOn: $item.isCompleted)
                .labelsHidden()
                .tint(LockInTheme.Colors.accent)
                .onChange(of: item.isCompleted) { _, _ in onToggle() }
            Text(item.displayLabel)
                .font(LockInTheme.Font.label(13))
                .foregroundColor(item.isCompleted ? LockInTheme.Colors.textPrimary : LockInTheme.Colors.textSecondary)
                .strikethrough(false)
            Spacer()
            if item.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(LockInTheme.Colors.accentGreen)
            }
        }
        .padding(LockInTheme.Spacing.sm + 2)
        .cardStyle()
    }
}
