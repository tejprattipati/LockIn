// MessedUpFlowView.swift
// Damage-control flow. Prevents spiral after a failure.
// Goal: salvage the rest of today, not punish or catastrophize.

import SwiftUI
import SwiftData

struct MessedUpFlowView: View {
    @Binding var isPresented: Bool
    var log: DailyLog?

    @Environment(\.modelContext) private var modelContext
    @Query private var goalProfiles: [GoalProfile]

    @State private var messUpType: MessUpType? = nil
    @State private var showSalvage = false

    enum MessUpType: String, CaseIterable {
        case orderedFood    = "I ordered restaurant food"
        case ateDessert     = "I had dessert"
        case wentOverCals   = "I went over my calorie target"
        case skippedLogging = "I didn't log anything today"
        case ateLateNight   = "I ate unplanned food late at night"
        case multipleThings = "Multiple things"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    if messUpType == nil {
                        selectTypeView
                    } else {
                        salvageView
                    }
                }
                .padding(LockInTheme.Spacing.md)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DAMAGE CONTROL")
                        .font(LockInTheme.Font.mono(13, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accentOrange)
                        .tracking(2)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Select Mess-Up Type
    private var selectTypeView: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                Text("What happened?")
                    .font(LockInTheme.Font.title(24))
                    .foregroundColor(LockInTheme.Colors.textPrimary)
                Text("Be honest. This data helps the app and helps you. Don't minimize it.")
                    .font(.system(size: 13))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
            }

            VStack(spacing: LockInTheme.Spacing.sm) {
                ForEach(MessUpType.allCases, id: \.self) { type in
                    Button {
                        messUpType = type
                        logFailure(type: type)
                    } label: {
                        HStack {
                            Text(type.rawValue)
                                .font(LockInTheme.Font.label(14))
                                .foregroundColor(LockInTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(LockInTheme.Colors.textTertiary)
                        }
                        .padding(LockInTheme.Spacing.md)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Salvage Plan
    private var salvageView: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.lg) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(LockInTheme.Colors.accentOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Don't spiral.")
                        .font(LockInTheme.Font.title(22))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("One bad decision doesn't define the day.")
                        .font(.system(size: 13))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }

            Text(contextMessage)
                .font(LockInTheme.Font.label(13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
                .padding(LockInTheme.Spacing.md)
                .background(LockInTheme.Colors.accentOrange.opacity(0.08))
                .cornerRadius(LockInTheme.Radius.md)

            VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                Text("SALVAGE PROTOCOL")
                    .sectionHeaderStyle()
                ForEach(salvageSteps, id: \.self) { step in
                    HStack(alignment: .top, spacing: LockInTheme.Spacing.sm) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundColor(LockInTheme.Colors.accent)
                            .padding(.top, 2)
                        Text(step)
                            .font(LockInTheme.Font.label(13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()

            // Log damage in MND
            Button {
                Task { await MyNetDiaryManager.shared.open(.logFood) }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Log what happened in MyNetDiary")
                }
                .font(LockInTheme.Font.label(14, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LockInTheme.Colors.accent)
                .cornerRadius(LockInTheme.Radius.md)
            }

            if let goal = goalProfiles.first {
                VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                    Text("TOMORROW'S FOCUS")
                        .sectionHeaderStyle()
                    Text("You have \(goal.daysUntilGoal) days left. This was one. Move on.")
                        .font(LockInTheme.Font.mono(13))
                        .foregroundColor(LockInTheme.Colors.accent)
                }
                .padding(LockInTheme.Spacing.md)
                .cardStyle()
            }

            Button {
                isPresented = false
            } label: {
                Text("Close — Back to the Plan")
                    .font(LockInTheme.Font.label(14))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LockInTheme.Colors.surface)
                    .cornerRadius(LockInTheme.Radius.md)
            }
        }
    }

    // MARK: - Logic
    private func logFailure(type: MessUpType) {
        switch type {
        case .orderedFood:
            log?.hadRestaurantFood = true
            log?.checklist(for: .noRestaurantFood)?.isCompleted = false
        case .ateDessert:
            log?.hadDessert = true
            log?.checklist(for: .noDessert)?.isCompleted = false
        case .ateLateNight:
            log?.hadUnplannedNightEating = true
            log?.checklist(for: .noUnplannedEating)?.isCompleted = false
        case .wentOverCals, .skippedLogging, .multipleThings:
            break
        }
        if let log = log {
            log.complianceScore = ComplianceCalculator.score(for: log)
        }
        try? modelContext.save()
    }

    private var contextMessage: String {
        switch messUpType {
        case .orderedFood:
            return "You ordered restaurant food. That's logged and real. Now stop the spiral. Do not order again tonight. Log it accurately and move on."
        case .ateDessert:
            return "You had dessert. One dessert doesn't end the cut — but ordering more food after it does. Stop here."
        case .wentOverCals:
            return "You went over calories. Do not try to compensate by skipping tomorrow. Eat normally. The cut continues."
        case .skippedLogging:
            return "You skipped logging. Open MyNetDiary and try to reconstruct today honestly. Imperfect data is better than no data."
        case .ateLateNight:
            return "Unplanned late-night eating happened. Log what you ate. Figure out why it happened. Pre-plan the night meal tomorrow."
        case .multipleThings:
            return "Multiple things went wrong. That's okay. It happens. The goal right now is: log it, don't add more damage, and start fresh tomorrow."
        case nil:
            return ""
        }
    }

    private var salvageSteps: [String] {
        var steps = [
            "Stop eating now. The meal is over.",
            "Log everything you ate in MyNetDiary — honestly.",
            "Do not try to compensate by eating less tomorrow.",
            "Pre-plan your meals for tomorrow right now before sleeping."
        ]
        if messUpType == .orderedFood {
            steps.insert("Do not order anything else tonight.", at: 1)
        }
        if messUpType == .skippedLogging {
            steps.insert("Estimate what you ate as best you can and log it.", at: 1)
        }
        return steps
    }
}

#Preview {
    MessedUpFlowView(isPresented: .constant(true), log: nil)
        .modelContainer(for: [GoalProfile.self], inMemory: true)
}
