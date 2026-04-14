// PlanEditorView.swift
// Configure daily targets, meal templates, and motivational content.
// Templates can be added to today's log directly from this view.

import SwiftUI
import SwiftData

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goalProfiles: [GoalProfile]
    // Show ALL templates (active and inactive) so the user can manage them freely
    @Query private var mealTemplates: [MealTemplate]
    @Query(sort: \DailyLog.date, order: .reverse) private var dailyLogs: [DailyLog]

    @State private var showGoalEditor = false
    @State private var showMealEditor: MealTemplate? = nil
    @State private var showMotivationEditor = false
    @State private var showNewTemplateSheet = false

    private var goalProfile: GoalProfile? { goalProfiles.first }
    private var todayLog: DailyLog? { dailyLogs.first { Calendar.current.isDateInToday($0.date) } }
    private var sortedTemplates: [MealTemplate] {
        mealTemplates.sorted { $0.slot.sortOrder < $1.slot.sortOrder }
    }

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewTemplateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(LockInTheme.Colors.accent)
                    }
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
            .sheet(isPresented: $showNewTemplateSheet) {
                NewMealTemplateSheet(isPresented: $showNewTemplateSheet)
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
                    Text(String(format: "%.0f lb", goal.targetWeight))
                        .font(LockInTheme.Font.mono(13))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                Button("Edit Targets & Goal") { showGoalEditor = true }
                    .foregroundColor(LockInTheme.Colors.accent)
            }
        } header: {
            Text("DAILY TARGETS").sectionHeaderStyle()
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - Meal Templates Section
    private var mealTemplatesSection: some View {
        Section {
            ForEach(sortedTemplates) { template in
                templateRow(template)
            }
            .onDelete { offsets in
                for i in offsets { modelContext.delete(sortedTemplates[i]) }
                try? modelContext.save()
            }
        } header: {
            Text("MEAL TEMPLATES").sectionHeaderStyle()
        } footer: {
            Text("Swipe left to delete. Tap to edit. Use + in top-right to add new templates.")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // Row — plain HStack with trailing edit chevron + add-to-today button
    // IMPORTANT: No Button wrapper around the row — it interferes with swipe-to-delete.
    @ViewBuilder
    private func templateRow(_ template: MealTemplate) -> some View {
        HStack(spacing: LockInTheme.Spacing.sm) {
            Image(systemName: template.slot.icon)
                .foregroundColor(LockInTheme.Colors.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(LockInTheme.Font.label(14))
                    .foregroundColor(LockInTheme.Colors.textPrimary)
                HStack(spacing: 6) {
                    Text("\(template.calorieTarget) kcal")
                        .font(.system(size: 11))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                    if template.proteinTarget > 0 {
                        Text("· P \(template.proteinTarget)g")
                            .font(.system(size: 11))
                            .foregroundColor(LockInTheme.Colors.accentGreen)
                    }
                    if template.carbTarget > 0 {
                        Text("C \(template.carbTarget)g")
                            .font(.system(size: 11))
                            .foregroundColor(LockInTheme.Colors.accentOrange)
                    }
                    if template.fatTarget > 0 {
                        Text("F \(template.fatTarget)g")
                            .font(.system(size: 11))
                            .foregroundColor(LockInTheme.Colors.accentYellow)
                    }
                }
            }

            Spacer()

            // "Add to today" button
            Button {
                addToToday(template)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: isInToday(template) ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 14))
                    Text(isInToday(template) ? "In Today" : "Add")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(isInToday(template) ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isInToday(template) ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accent).opacity(0.12))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Edit chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
                .onTapGesture { showMealEditor = template }
        }
        .contentShape(Rectangle())
        .onTapGesture { showMealEditor = template }
    }

    // MARK: - Motivation Section
    private var motivationSection: some View {
        Section {
            if let goal = goalProfile {
                Text(goal.motivationStatement)
                    .font(LockInTheme.Font.label(13))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                Button("Edit Motivation & Penalty Text") { showMotivationEditor = true }
                    .foregroundColor(LockInTheme.Colors.accent)
            }
        } header: {
            Text("MOTIVATION").sectionHeaderStyle()
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
            Text("RED-FLAG FOODS").sectionHeaderStyle()
        } footer: {
            Text("Known binge triggers. Seeing them in the Intervene flow is intentional.")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - Add to Today Logic
    private func isInToday(_ template: MealTemplate) -> Bool {
        guard let log = todayLog else { return false }
        return log.mealEvents.contains { $0.slot == template.slot && $0.name == template.name }
    }

    private func addToToday(_ template: MealTemplate) {
        guard let log = todayLog else { return }
        // Replace existing event for this slot if it came from a different template
        if let existing = log.mealEvents.first(where: { $0.slot == template.slot }) {
            modelContext.delete(existing)
        }
        let event = MealEvent.from(template: template)
        event.dailyLog = log
        log.mealEvents.append(event)
        try? modelContext.save()
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
                            Text("kcal").foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        HStack {
                            Text("Protein")
                            Spacer()
                            TextField("145", text: $protTarget)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.accent)
                            Text("g").foregroundColor(LockInTheme.Colors.textSecondary)
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
                            Text("lb").foregroundColor(LockInTheme.Colors.textSecondary)
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
                        if let cal = Int(calTarget)     { goal.dailyCalorieTarget = cal }
                        if let prot = Int(protTarget)   { goal.dailyProteinTarget = prot }
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
                calTarget    = String(goal.dailyCalorieTarget)
                protTarget   = String(goal.dailyProteinTarget)
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

// MARK: - New Meal Template Sheet
struct NewMealTemplateSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var slot: MealSlot = .meal1
    @State private var calorieText: String = ""
    @State private var proteinText: String = ""
    @State private var carbText: String = ""
    @State private var fatText: String = ""
    @State private var notes: String = ""
    @State private var foodInput: String = ""
    @State private var foods: [String] = []

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                Form {
                    Section("TEMPLATE NAME") {
                        TextField("e.g. High Protein Lunch", text: $name)
                            .font(LockInTheme.Font.label(14))
                            .foregroundColor(LockInTheme.Colors.textPrimary)
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    Section("MEAL SLOT") {
                        Picker("Slot", selection: $slot) {
                            ForEach(MealSlot.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(LockInTheme.Colors.accent)
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    Section("MACROS (per serving)") {
                        macroRow(label: "Calories", unit: "kcal", text: $calorieText)
                        macroRow(label: "Protein",  unit: "g",    text: $proteinText)
                        macroRow(label: "Carbs",    unit: "g",    text: $carbText)
                        macroRow(label: "Fat",      unit: "g",    text: $fatText)
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    Section {
                        ForEach(foods, id: \.self) { food in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundColor(LockInTheme.Colors.accent)
                                Text(food)
                                    .font(LockInTheme.Font.label(13))
                                    .foregroundColor(LockInTheme.Colors.textSecondary)
                            }
                        }
                        .onDelete { offsets in foods.remove(atOffsets: offsets) }

                        HStack {
                            TextField("Add food...", text: $foodInput)
                                .font(LockInTheme.Font.label(13))
                            Button {
                                let t = foodInput.trimmingCharacters(in: .whitespaces)
                                guard !t.isEmpty else { return }
                                foods.append(t)
                                foodInput = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(LockInTheme.Colors.accent)
                            }
                        }
                    } header: {
                        Text("FOODS")
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    Section("NOTES") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                            .font(.system(size: 13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                    .listRowBackground(LockInTheme.Colors.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let template = MealTemplate(
                            name: name.isEmpty ? slot.rawValue : name,
                            slot: slot,
                            suggestedFoods: foods,
                            calorieTarget: Int(calorieText) ?? 0,
                            proteinTarget: Int(proteinText) ?? 0,
                            carbTarget:    Int(carbText)    ?? 0,
                            fatTarget:     Int(fatText)     ?? 0,
                            notes: notes,
                            isActiveDefault: true
                        )
                        modelContext.insert(template)
                        try? modelContext.save()
                        isPresented = false
                    }
                    .foregroundColor(LockInTheme.Colors.accent)
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty && calorieText.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func macroRow(label: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(LockInTheme.Font.mono(14))
                .foregroundColor(LockInTheme.Colors.accent)
                .frame(width: 70)
            Text(unit).foregroundColor(LockInTheme.Colors.textSecondary)
        }
    }
}

#Preview {
    PlanEditorView()
        .modelContainer(for: [GoalProfile.self, MealTemplate.self, DailyLog.self,
                               MealEvent.self, ChecklistEntry.self], inMemory: true)
}
