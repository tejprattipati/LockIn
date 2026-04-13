// PlanEditorView.swift
// Configure daily targets, meal templates, and motivational content.

import SwiftUI
import SwiftData

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goalProfiles: [GoalProfile]
    @Query(filter: #Predicate<MealTemplate> { $0.isActiveDefault == true })
    private var mealTemplates: [MealTemplate]

    @State private var showGoalEditor = false
    @State private var showMealEditor: MealTemplate? = nil
    @State private var showMotivationEditor = false

    private var goalProfile: GoalProfile? { goalProfiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                List {
                    targetsSection
                    mealTemplatesSection
                    motivationSection
                    dangerFoodsSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PLAN")
                        .font(LockInTheme.Font.mono(14, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .tracking(3)
                }
            }
            .sheet(isPresented: $showGoalEditor) {
                if let goal = goalProfile {
                    GoalEditorSheet(goal: goal, isPresented: $showGoalEditor)
                }
            }
            .sheet(item: $showMealEditor) { template in
                MealTemplateEditorView(template: template, isPresented: Binding(
                    get: { showMealEditor != nil },
                    set: { if !$0 { showMealEditor = nil } }
                ))
            }
            .sheet(isPresented: $showMotivationEditor) {
                if let goal = goalProfile {
                    MotivationEditorSheet(goal: goal, isPresented: $showMotivationEditor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Targets Section
    private var targetsSection: some View {
        Section {
            if let goal = goalProfile {
                HStack {
                    Text("Daily Calories")
                    Spacer()
                    Text("\(goal.dailyCalorieTarget) kcal")
                        .font(LockInTheme.Font.mono(14, weight: .semibold))
                        .foregroundColor(LockInTheme.Colors.accent)
                }
                HStack {
                    Text("Daily Protein")
                    Spacer()
                    Text("\(goal.dailyProteinTarget)g")
                        .font(LockInTheme.Font.mono(14, weight: .semibold))
                        .foregroundColor(LockInTheme.Colors.accent)
                }
                HStack {
                    Text("Goal Date")
                    Spacer()
                    Text(shortDate(goal.goalDate))
                        .font(LockInTheme.Font.mono(13))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                HStack {
                    Text("Target Weight")
                    Spacer()
                    Text("\(String(format: "%.0f", goal.targetWeight)) lb")
                        .font(LockInTheme.Font.mono(13))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                Button("Edit Targets & Goal") {
                    showGoalEditor = true
                }
                .foregroundColor(LockInTheme.Colors.accent)
            }
        } header: {
            Text("DAILY TARGETS")
                .sectionHeaderStyle()
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - Meal Templates
    private var mealTemplatesSection: some View {
        Section {
            ForEach(mealTemplates.sorted { $0.slot.sortOrder < $1.slot.sortOrder }) { template in
                Button {
                    showMealEditor = template
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.slot.rawValue)
                                .font(LockInTheme.Font.label(14))
                                .foregroundColor(LockInTheme.Colors.textPrimary)
                            Text("\(template.calorieTarget) kcal · \(template.proteinTarget)g protein")
                                .font(.system(size: 11))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(LockInTheme.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("MEAL TEMPLATES")
                .sectionHeaderStyle()
        } footer: {
            Text("These are your default meal templates. Tap any to edit foods, targets, and notes.")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - Motivation Section
    private var motivationSection: some View {
        Section {
            if let goal = goalProfile {
                VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                    Text(goal.motivationStatement)
                        .font(LockInTheme.Font.label(13))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                Button("Edit Motivation & Penalty Text") {
                    showMotivationEditor = true
                }
                .foregroundColor(LockInTheme.Colors.accent)
            }
        } header: {
            Text("MOTIVATION")
                .sectionHeaderStyle()
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - Danger Foods
    private var dangerFoodsSection: some View {
        Section {
            if let goal = goalProfile {
                ForEach(goal.redFlagFoods, id: \.self) { food in
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(LockInTheme.Colors.accentRed)
                            .font(.system(size: 12))
                        Text(food)
                            .font(LockInTheme.Font.label(13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                }
            }
        } header: {
            Text("RED-FLAG FOODS")
                .sectionHeaderStyle()
        } footer: {
            Text("These are your known binge triggers. Seeing them in the Intervene flow is intentional.")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

// MARK: - Goal Editor Sheet
struct GoalEditorSheet: View {
    @Bindable var goal: GoalProfile
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var calTarget: String = ""
    @State private var protTarget: String = ""
    @State private var targetWeight: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                Form {
                    Section("NUTRITION TARGETS") {
                        HStack {
                            Text("Calories")
                            Spacer()
                            TextField("1900", text: $calTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.accent)
                            Text("kcal")
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        HStack {
                            Text("Protein")
                            Spacer()
                            TextField("145", text: $protTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.accent)
                            Text("g")
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    Section("GOAL") {
                        DatePicker("Goal Date", selection: $goal.goalDate, displayedComponents: .date)
                        HStack {
                            Text("Target Weight")
                            Spacer()
                            TextField("147", text: $targetWeight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.accent)
                            Text("lb")
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        HStack {
                            Text("Target BF%")
                            Spacer()
                            Text("\(String(format: "%.0f", goal.targetBodyFatPercent))%")
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                    }
                    .listRowBackground(LockInTheme.Colors.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let cal = Int(calTarget) { goal.dailyCalorieTarget = cal }
                        if let prot = Int(protTarget) { goal.dailyProteinTarget = prot }
                        if let tw = Double(targetWeight) { goal.targetWeight = tw }
                        goal.updatedAt = .now
                        try? modelContext.save()
                        isPresented = false
                    }
                    .foregroundColor(LockInTheme.Colors.accent)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                calTarget = String(goal.dailyCalorieTarget)
                protTarget = String(goal.dailyProteinTarget)
                targetWeight = String(format: "%.0f", goal.targetWeight)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Motivation Editor Sheet
struct MotivationEditorSheet: View {
    @Bindable var goal: GoalProfile
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                Form {
                    Section("MAIN STATEMENT") {
                        TextEditor(text: $goal.motivationStatement)
                            .frame(minHeight: 80)
                            .font(LockInTheme.Font.label(13))
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    Section("PENALTY TEXT (shown in Intervene)") {
                        TextEditor(text: $goal.penaltyText)
                            .frame(minHeight: 60)
                            .font(LockInTheme.Font.label(13))
                    }
                    .listRowBackground(LockInTheme.Colors.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Motivation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        goal.updatedAt = .now
                        try? modelContext.save()
                        isPresented = false
                    }
                    .foregroundColor(LockInTheme.Colors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    PlanEditorView()
        .modelContainer(for: [GoalProfile.self, MealTemplate.self], inMemory: true)
}
