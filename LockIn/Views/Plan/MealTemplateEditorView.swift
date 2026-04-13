// MealTemplateEditorView.swift
// Edit a single meal template's foods, calorie/protein targets, and notes.

import SwiftUI
import SwiftData

struct MealTemplateEditorView: View {
    @Bindable var template: MealTemplate
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var calorieText: String = ""
    @State private var proteinText: String = ""
    @State private var newFood: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                Form {
                    // MARK: Targets
                    Section("TARGETS") {
                        HStack {
                            Text("Calories")
                            Spacer()
                            TextField("0", text: $calorieText)
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
                            TextField("0", text: $proteinText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.accent)
                            Text("g")
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    // MARK: Suggested Foods
                    Section {
                        ForEach(template.suggestedFoods, id: \.self) { food in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(LockInTheme.Colors.accent)
                                Text(food)
                                    .font(LockInTheme.Font.label(13))
                                    .foregroundColor(LockInTheme.Colors.textSecondary)
                                Spacer()
                            }
                        }
                        .onDelete { offsets in
                            template.suggestedFoods.remove(atOffsets: offsets)
                        }

                        HStack {
                            TextField("Add food item...", text: $newFood)
                                .font(LockInTheme.Font.label(13))
                                .foregroundColor(LockInTheme.Colors.textPrimary)
                            Button {
                                let trimmed = newFood.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty {
                                    template.suggestedFoods.append(trimmed)
                                    newFood = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(LockInTheme.Colors.accent)
                            }
                        }
                    } header: {
                        Text("SUGGESTED FOODS")
                            .sectionHeaderStyle()
                    } footer: {
                        Text("Swipe left to remove. These are suggestions, not rules.")
                            .font(.system(size: 11))
                            .foregroundColor(LockInTheme.Colors.textTertiary)
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    // MARK: Notes
                    Section("NOTES") {
                        TextEditor(text: $template.notes)
                            .frame(minHeight: 80)
                            .font(.system(size: 13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                    .listRowBackground(LockInTheme.Colors.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(template.slot.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let cal = Int(calorieText) { template.calorieTarget = cal }
                        if let prot = Int(proteinText) { template.proteinTarget = prot }
                        template.updatedAt = .now
                        try? modelContext.save()
                        isPresented = false
                    }
                    .foregroundColor(LockInTheme.Colors.accent)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                calorieText = String(template.calorieTarget)
                proteinText = String(template.proteinTarget)
            }
        }
        .preferredColorScheme(.dark)
    }
}
