// ScreenshotImportView.swift
// Import a MyNetDiary food diary screenshot and extract macros using Gemini Vision.
// Gemini 1.5 Flash reads the image and returns calories / protein / carbs / fat.
// All four values are editable before confirming.
//
// Usage:
//   1. In MyNetDiary → go to Diary or Food Report → take a screenshot
//   2. LockIn Today → Quick Actions → Import Screenshot
//   3. Select the screenshot from your photo library
//   4. Tap "Analyze with AI" — Gemini extracts the numbers
//   5. Review/adjust if needed → Confirm saves to today's log

import SwiftUI
import PhotosUI

struct ScreenshotImportView: View {
    @Binding var isPresented: Bool
    /// Called with (calories, protein, carbs, fat) when the user confirms
    var onConfirm: (Int, Int, Int, Int) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var parseStatus: ParseStatus = .idle
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var rawResponse = ""
    @State private var showRaw = false

    enum ParseStatus: Equatable {
        case idle
        case analyzing
        case success
        case partial(String)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: LockInTheme.Spacing.lg) {
                        instructionHeader
                        photoPickerSection
                        if selectedImage != nil { analyzeSection }
                        if parseStatus != .idle { statusBanner }
                        if parseStatus == .success || hasAnyValue { resultFields }
                        if !rawResponse.isEmpty { rawDebugSection }
                        if hasAnyValue { confirmButton }
                    }
                    .padding(LockInTheme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("IMPORT SCREENSHOT")
                        .font(LockInTheme.Font.mono(12, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .tracking(2)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Instruction Header
    private var instructionHeader: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            HStack(spacing: LockInTheme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundColor(LockInTheme.Colors.accent)
                Text("AI-powered macro extraction")
                    .font(LockInTheme.Font.label(14, weight: .semibold))
                    .foregroundColor(LockInTheme.Colors.textPrimary)
            }
            Text("Screenshot your MyNetDiary diary or food report showing daily totals. Claude AI reads calories, protein, carbs, and fat automatically.")
                .font(.system(size: 13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
        }
        .padding(LockInTheme.Spacing.md)
        .cardStyle()
    }

    // MARK: - Photo Picker
    private var photoPickerSection: some View {
        PhotosPicker(selection: $selectedItem, matching: .screenshots) {
            HStack {
                Image(systemName: selectedImage != nil ? "photo.fill" : "photo.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(LockInTheme.Colors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedImage != nil ? "Screenshot Selected" : "Select Screenshot")
                        .font(LockInTheme.Font.label(14, weight: .semibold))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text(selectedImage != nil ? "Tap to change" : "Opens your Screenshots album")
                        .font(.system(size: 11))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()
        }
        .onChange(of: selectedItem) { _, item in
            Task {
                guard let item else { return }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    selectedImage = img
                    parseStatus = .idle
                    caloriesText = ""
                    proteinText = ""
                    carbsText = ""
                    fatText = ""
                    rawResponse = ""
                }
            }
        }
    }

    // MARK: - Analyze Section
    @ViewBuilder
    private var analyzeSection: some View {
        if let img = selectedImage {
            VStack(spacing: LockInTheme.Spacing.sm) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .cornerRadius(LockInTheme.Radius.md)

                Button {
                    runAnalysis(image: img)
                } label: {
                    HStack {
                        if isAnalyzing {
                            ProgressView().scaleEffect(0.8).tint(.black)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isAnalyzing ? "Analyzing..." : "Analyze with Claude AI")
                    }
                    .font(LockInTheme.Font.label(14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isAnalyzing ? LockInTheme.Colors.accentDim : LockInTheme.Colors.accent)
                    .cornerRadius(LockInTheme.Radius.md)
                }
                .disabled(isAnalyzing)
            }
        }
    }

    // MARK: - Status Banner
    @ViewBuilder
    private var statusBanner: some View {
        HStack(spacing: LockInTheme.Spacing.sm) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            Text(statusMessage)
                .font(.system(size: 13))
                .foregroundColor(statusColor)
        }
        .padding(LockInTheme.Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor.opacity(0.1))
        .cornerRadius(LockInTheme.Radius.sm)
    }

    private var statusIcon: String {
        switch parseStatus {
        case .success:    return "checkmark.circle.fill"
        case .partial:    return "exclamationmark.triangle.fill"
        case .failed:     return "xmark.circle.fill"
        default:          return "info.circle"
        }
    }
    private var statusColor: Color {
        switch parseStatus {
        case .success:    return LockInTheme.Colors.accentGreen
        case .partial:    return LockInTheme.Colors.accentOrange
        case .failed:     return LockInTheme.Colors.accentRed
        default:          return LockInTheme.Colors.textSecondary
        }
    }
    private var statusMessage: String {
        switch parseStatus {
        case .idle:           return ""
        case .analyzing:      return "Analyzing screenshot..."
        case .success:        return "All four macros extracted."
        case .partial(let m): return m
        case .failed(let e):  return "Error: \(e)"
        }
    }

    // MARK: - Result Fields
    private var resultFields: some View {
        VStack(spacing: LockInTheme.Spacing.sm) {
            Text("EXTRACTED MACROS")
                .sectionHeaderStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            macroField(label: "Calories", unit: "kcal", text: $caloriesText,
                       color: caloriesText.isEmpty ? LockInTheme.Colors.textTertiary : LockInTheme.Colors.textPrimary)
            macroField(label: "Protein",  unit: "g",    text: $proteinText,
                       color: proteinText.isEmpty  ? LockInTheme.Colors.textTertiary : LockInTheme.Colors.accentGreen)
            macroField(label: "Carbs",    unit: "g",    text: $carbsText,
                       color: carbsText.isEmpty    ? LockInTheme.Colors.textTertiary : LockInTheme.Colors.accentOrange)
            macroField(label: "Fat",      unit: "g",    text: $fatText,
                       color: fatText.isEmpty      ? LockInTheme.Colors.textTertiary : LockInTheme.Colors.accentYellow)
            Text("Edit any value before confirming.")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private func macroField(label: String, unit: String, text: Binding<String>, color: Color) -> some View {
        HStack {
            Text(label)
                .font(LockInTheme.Font.label(14))
                .foregroundColor(LockInTheme.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)
            TextField("0", text: text)
                .font(LockInTheme.Font.mono(18, weight: .semibold))
                .foregroundColor(color)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .font(LockInTheme.Font.mono(13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
        }
        .padding(LockInTheme.Spacing.md)
        .cardStyle()
    }

    // MARK: - Raw debug
    @ViewBuilder
    private var rawDebugSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { showRaw.toggle() } label: {
                HStack {
                    Text(showRaw ? "Hide Gemini response" : "Show raw Gemini response")
                        .font(.system(size: 11))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                    Image(systemName: showRaw ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                }
            }
            if showRaw {
                Text(rawResponse)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
                    .padding(LockInTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LockInTheme.Colors.surfaceElevated)
                    .cornerRadius(LockInTheme.Radius.sm)
            }
        }
    }

    // MARK: - Confirm Button
    private var confirmButton: some View {
        Button {
            onConfirm(
                Int(caloriesText) ?? 0,
                Int(proteinText)  ?? 0,
                Int(carbsText)    ?? 0,
                Int(fatText)      ?? 0
            )
            isPresented = false
        } label: {
            Text("CONFIRM & SAVE TO TODAY")
                .font(LockInTheme.Font.label(14, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LockInTheme.Colors.accent)
                .cornerRadius(LockInTheme.Radius.md)
        }
    }

    // MARK: - Helpers
    private var hasAnyValue: Bool {
        !caloriesText.isEmpty || !proteinText.isEmpty || !carbsText.isEmpty || !fatText.isEmpty
    }

    // MARK: - Gemini Call
    private func runAnalysis(image: UIImage) {
        isAnalyzing = true
        parseStatus = .analyzing
        Task {
            do {
                let result = try await GeminiService.parseNutritionScreenshot(image)
                rawResponse = result.rawResponse
                if let c  = result.calories { caloriesText = String(c) }
                if let p  = result.protein  { proteinText  = String(p) }
                if let cb = result.carbs    { carbsText    = String(cb) }
                if let f  = result.fat      { fatText      = String(f) }

                let found = [result.calories, result.protein, result.carbs, result.fat]
                    .compactMap { $0 }.count
                if found == 4 {
                    parseStatus = .success
                } else if found > 0 {
                    let missing = [
                        result.calories == nil ? "calories" : nil,
                        result.protein  == nil ? "protein"  : nil,
                        result.carbs    == nil ? "carbs"    : nil,
                        result.fat      == nil ? "fat"      : nil
                    ].compactMap { $0 }.joined(separator: ", ")
                    parseStatus = .partial("Found \(found)/4. Missing: \(missing). Fill in manually.")
                } else {
                    parseStatus = .partial("No values detected. Make sure the screenshot shows daily totals. Fill in manually.")
                }
            } catch {
                rawResponse = error.localizedDescription
                parseStatus = .failed(error.localizedDescription)
            }
            isAnalyzing = false
        }
    }
}
