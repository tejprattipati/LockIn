// DailyChecklistView.swift
// Full checklist for today — timestamped completions.

import SwiftUI
import SwiftData

struct DailyChecklistView: View {
    @Bindable var log: DailyLog
    @Environment(\.modelContext) private var modelContext

    // Groups for display order
    private let highPriority: [ComplianceCategory] = [
        .morningWeighIn, .noRestaurantFood, .noDessert, .noUnplannedEating
    ]
    private let nutritionItems: [ComplianceCategory] = [
        .loggedMeal1, .loggedMeal2, .loggedNightMeal,
        .hitProteinTarget, .underCalorieTarget, .loggedInMND
    ]
    private let activityItems: [ComplianceCategory] = [
        .workoutCompleted, .stepsGoalMet
    ]

    var body: some View {
        VStack(spacing: 1) {
            ChecklistGroupHeader(title: "NON-NEGOTIABLES")
            ForEach(highPriority, id: \.self) { cat in
                if let item = log.checklistItems.first(where: { $0.category == cat }) {
                    ChecklistItemRow(item: item, onToggle: { toggle(item) })
                }
            }

            ChecklistGroupHeader(title: "NUTRITION")
            ForEach(nutritionItems, id: \.self) { cat in
                if let item = log.checklistItems.first(where: { $0.category == cat }) {
                    ChecklistItemRow(item: item, onToggle: { toggle(item) })
                }
            }

            ChecklistGroupHeader(title: "ACTIVITY")
            ForEach(activityItems, id: \.self) { cat in
                if let item = log.checklistItems.first(where: { $0.category == cat }) {
                    ChecklistItemRow(item: item, onToggle: { toggle(item) })
                }
            }
        }
        .cardStyle()
    }

    private func toggle(_ item: ChecklistEntry) {
        item.toggle()
        log.complianceScore = ComplianceCalculator.score(for: log)
        try? modelContext.save()
    }
}

// MARK: - Group Header
private struct ChecklistGroupHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(LockInTheme.Colors.textTertiary)
                .tracking(1.5)
            Spacer()
        }
        .padding(.horizontal, LockInTheme.Spacing.md)
        .padding(.top, LockInTheme.Spacing.sm)
        .padding(.bottom, 2)
        .background(LockInTheme.Colors.surface)
    }
}

// MARK: - Row
struct ChecklistItemRow: View {
    @Bindable var item: ChecklistEntry
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: LockInTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .stroke(item.isCompleted ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.border, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if item.isCompleted {
                        Circle()
                            .fill(LockInTheme.Colors.accentGreen)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                    }
                }

                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .foregroundColor(item.isCompleted ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.textSecondary)
                    .frame(width: 18)

                Text(item.displayLabel)
                    .font(LockInTheme.Font.label(13))
                    .foregroundColor(item.isCompleted ? LockInTheme.Colors.textPrimary : LockInTheme.Colors.textSecondary)
                    .strikethrough(item.isCompleted, color: LockInTheme.Colors.textTertiary)

                Spacer()

                if let ts = item.completedAt {
                    Text(timeString(ts))
                        .font(.system(size: 10))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                } else {
                    Text("\(String(format: "%.0f", item.weight))pt")
                        .font(.system(size: 10))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, LockInTheme.Spacing.md)
            .padding(.vertical, 10)
            .background(item.isCompleted ? LockInTheme.Colors.accentGreen.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f.string(from: date).lowercased()
    }
}

#Preview {
    let log = DataSeeder.sampleDailyLog()
    return DailyChecklistView(log: log)
        .padding()
        .background(LockInTheme.Colors.background)
        .preferredColorScheme(.dark)
}
