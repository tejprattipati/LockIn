// InterveneView.swift
// Main Intervene tab — entry point for all crisis/decision flows.

import SwiftUI
import SwiftData

struct InterveneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var dailyLogs: [DailyLog]
    @Query private var goalProfiles: [GoalProfile]

    @State private var showAntiBingeFlow = false
    @State private var showMessedUpFlow = false
    @State private var showNightPlan = false
    @StateObject private var mndManager = MyNetDiaryManager.shared
    @State private var mndFallback: MNDIntegrationResult?

    private var todayLog: DailyLog? { dailyLogs.first { Calendar.current.isDateInToday($0.date) } }
    private var goalProfile: GoalProfile? { goalProfiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: LockInTheme.Spacing.md) {
                        statusHeader
                        mainCrisisButtons
                        Divider().background(LockInTheme.Colors.border).padding(.horizontal)
                        supportActions
                        if let fallback = mndFallback, !fallback.success {
                            fallbackBanner(result: fallback)
                        }
                    }
                    .padding(LockInTheme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("INTERVENE")
                        .font(LockInTheme.Font.mono(14, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accentRed)
                        .tracking(3)
                        .glowAccent(radius: 8)
                }
            }
            .sheet(isPresented: $showAntiBingeFlow) {
                AntiBingeFlowView(isPresented: $showAntiBingeFlow, log: todayLog)
            }
            .sheet(isPresented: $showMessedUpFlow) {
                MessedUpFlowView(isPresented: $showMessedUpFlow, log: todayLog)
            }
            .sheet(isPresented: $showNightPlan) {
                NightPlanSheet(isPresented: $showNightPlan, log: todayLog)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Status Header
    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CRISIS CONTROL")
                        .font(LockInTheme.Font.mono(11, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                        .tracking(2)
                    Text("If you're here, you're at risk.")
                        .font(LockInTheme.Font.title(18))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                }
                Spacer()
                Image(systemName: "shield.slash.fill")
                    .font(.system(size: 28))
                    .foregroundColor(LockInTheme.Colors.accentRed)
            }

            VStack(spacing: 4) {
                if let log = todayLog {
                    HStack {
                        Image(systemName: log.hadRestaurantFood ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(log.hadRestaurantFood ? LockInTheme.Colors.accentRed : LockInTheme.Colors.accentGreen)
                        Text("Restaurant food today")
                            .font(LockInTheme.Font.label(12))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                        Spacer()
                        Text(log.hadRestaurantFood ? "YES — Damaged" : "Clean")
                            .font(LockInTheme.Font.mono(11, weight: .semibold))
                            .foregroundColor(log.hadRestaurantFood ? LockInTheme.Colors.accentRed : LockInTheme.Colors.accentGreen)
                    }
                    HStack {
                        Image(systemName: log.nightMeal?.isCompleted == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(log.nightMeal?.isCompleted == true ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accentOrange)
                        Text("Night meal")
                            .font(LockInTheme.Font.label(12))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                        Spacer()
                        Text(log.nightMeal?.isCompleted == true ? "Done" : (log.nightMeal != nil ? "Planned" : "Not Set"))
                            .font(LockInTheme.Font.mono(11, weight: .semibold))
                            .foregroundColor(log.nightMeal?.isCompleted == true ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accentOrange)
                    }
                    if let cal = log.actualCalories, let target = goalProfile?.dailyCalorieTarget {
                        HStack {
                            Image(systemName: cal <= target ? "checkmark.circle.fill" : "flame.fill")
                                .foregroundColor(cal <= target ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accentRed)
                            Text("Calories today")
                                .font(LockInTheme.Font.label(12))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                            Spacer()
                            Text("\(cal) / \(target) kcal")
                                .font(LockInTheme.Font.mono(11, weight: .semibold))
                                .foregroundColor(cal <= target ? LockInTheme.Colors.textPrimary : LockInTheme.Colors.accentRed)
                        }
                    }
                }
                if let goal = goalProfile {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(LockInTheme.Colors.accent)
                        Text("Goal deadline")
                            .font(LockInTheme.Font.label(12))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(goal.daysUntilGoal) days left")
                            .font(LockInTheme.Font.mono(11, weight: .semibold))
                            .foregroundColor(LockInTheme.Colors.accent)
                    }
                }
            }
        }
        .padding(LockInTheme.Spacing.md)
        .cardStyle()
    }

    // MARK: - Main Crisis Buttons
    private var mainCrisisButtons: some View {
        VStack(spacing: LockInTheme.Spacing.sm) {
            CrisisButton(
                title: "I'M ABOUT TO ORDER FOOD",
                subtitle: "Start the anti-order intervention",
                icon: "xmark.shield.fill",
                color: LockInTheme.Colors.accentRed,
                action: { showAntiBingeFlow = true }
            )

            CrisisButton(
                title: "I'M HUNGRY RIGHT NOW",
                subtitle: "Walk me through what to eat instead",
                icon: "fork.knife",
                color: LockInTheme.Colors.accentOrange,
                action: { showAntiBingeFlow = true }
            )

            CrisisButton(
                title: "I ALREADY MESSED UP",
                subtitle: "Salvage the rest of today",
                icon: "arrow.clockwise.circle.fill",
                color: LockInTheme.Colors.accent,
                action: { showMessedUpFlow = true }
            )
        }
    }

    // MARK: - Support Actions
    private var supportActions: some View {
        VStack(spacing: LockInTheme.Spacing.sm) {
            Text("SUPPORT ACTIONS")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LockInTheme.Spacing.sm) {
                SupportActionButton(icon: "moon.fill", label: "Tonight's Plan") {
                    showNightPlan = true
                }
                SupportActionButton(icon: "checkmark.icloud", label: "Open MyNetDiary") {
                    Task {
                        let result = await mndManager.open(.openApp)
                        if !result.success { mndFallback = result }
                    }
                }
                SupportActionButton(icon: "scale.3d", label: "Log Weight") {
                    Task {
                        let result = await mndManager.open(.logWeight)
                        if !result.success { mndFallback = result }
                    }
                }
                SupportActionButton(icon: "note.text", label: "Log Food") {
                    Task {
                        let result = await mndManager.open(.logFood)
                        if !result.success { mndFallback = result }
                    }
                }
            }
        }
    }

    // MARK: - Fallback Banner
    private func fallbackBanner(result: MNDIntegrationResult) -> some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(LockInTheme.Colors.accent)
                Text("MyNetDiary: Manual Steps Required")
                    .font(LockInTheme.Font.label(13, weight: .semibold))
                    .foregroundColor(LockInTheme.Colors.textPrimary)
                Spacer()
                Button { mndFallback = nil } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                        .font(.system(size: 12))
                }
            }
            if let instructions = result.fallbackInstructions {
                Text(instructions)
                    .font(.system(size: 13))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
            }
        }
        .padding(LockInTheme.Spacing.md)
        .background(LockInTheme.Colors.accent.opacity(0.12))
        .cornerRadius(LockInTheme.Radius.md)
    }
}

// MARK: - Crisis Button
struct CrisisButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LockInTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
            }
            .padding(LockInTheme.Spacing.md)
            .background(color.opacity(0.10))
            .cornerRadius(LockInTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: LockInTheme.Radius.md)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Support Action Button
struct SupportActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LockInTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(LockInTheme.Colors.accent)
                Text(label)
                    .font(LockInTheme.Font.label(13))
                    .foregroundColor(LockInTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(LockInTheme.Spacing.sm + 4)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Night Plan Sheet
struct NightPlanSheet: View {
    @Binding var isPresented: Bool
    var log: DailyLog?

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: LockInTheme.Spacing.md) {
                        Text("TONIGHT'S PLAN")
                            .font(LockInTheme.Font.mono(13, weight: .bold))
                            .foregroundColor(LockInTheme.Colors.accent)
                            .tracking(2)

                        if let nightMeal = log?.nightMeal {
                            VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                                Text(nightMeal.name)
                                    .font(LockInTheme.Font.title(20))
                                    .foregroundColor(LockInTheme.Colors.textPrimary)
                                Text("\(nightMeal.plannedCalories) kcal · \(nightMeal.plannedProtein)g protein")
                                    .font(LockInTheme.Font.mono(13))
                                    .foregroundColor(LockInTheme.Colors.accent)
                                Divider().background(LockInTheme.Colors.border)
                                ForEach(nightMeal.foods, id: \.self) { food in
                                    HStack {
                                        Circle()
                                            .fill(LockInTheme.Colors.accent)
                                            .frame(width: 4, height: 4)
                                        Text(food)
                                            .font(LockInTheme.Font.label(14))
                                            .foregroundColor(LockInTheme.Colors.textSecondary)
                                    }
                                }
                                if !nightMeal.notes.isEmpty {
                                    Text(nightMeal.notes)
                                        .font(.system(size: 12))
                                        .foregroundColor(LockInTheme.Colors.textTertiary)
                                        .italic()
                                }
                            }
                            .padding(LockInTheme.Spacing.md)
                            .cardStyle()
                        } else {
                            Text("No night meal planned. Set one up in the Plan tab.")
                                .font(LockInTheme.Font.label(14))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }

                        if let snack = log?.emergencySnack {
                            VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                                Text("EMERGENCY SNACK (if still hungry)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(LockInTheme.Colors.textTertiary)
                                    .tracking(1)
                                ForEach(snack.foods, id: \.self) { food in
                                    Text("• \(food)")
                                        .font(LockInTheme.Font.label(13))
                                        .foregroundColor(LockInTheme.Colors.textSecondary)
                                }
                                Text("\(snack.plannedCalories) kcal · Use only if absolutely necessary.")
                                    .font(.system(size: 11))
                                    .foregroundColor(LockInTheme.Colors.textTertiary)
                            }
                            .padding(LockInTheme.Spacing.md)
                            .cardStyle()
                        }
                    }
                    .padding(LockInTheme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    InterveneView()
        .modelContainer(for: [DailyLog.self, GoalProfile.self, MealEvent.self,
                               ChecklistEntry.self], inMemory: true)
}
