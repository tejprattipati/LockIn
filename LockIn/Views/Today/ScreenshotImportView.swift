// ScreenshotImportView.swift
// Import a MyNetDiary screenshot and extract calorie/protein data using
// Apple's on-device Vision OCR (VNRecognizeTextRequest). No external API needed.
//
// How to use:
//   1. In MyNetDiary, go to Diary → take a screenshot (or Food Report)
//   2. Come back to LockIn → Today → tap "Import from Screenshot"
//   3. Select the screenshot from your photo library
//   4. LockIn reads the text, finds calories and protein, pre-fills the fields
//   5. Confirm to save to today's log

import SwiftUI
import Vision
import PhotosUI
import SwiftData

struct ScreenshotImportView: View {
    @Binding var isPresented: Bool
    var onConfirm: (Int, Int) -> Void   // (calories, protein)

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isProcessing = false
    @State private var parsedCalories: Int? = nil
    @State private var parsedProtein: Int? = nil
    @State private var rawText: String = ""
    @State private var parseStatus: ParseStatus = .idle
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var showRawText = false

    enum ParseStatus {
        case idle
        case processing
        case foundBoth
        case foundCaloriesOnly
        case foundProteinOnly
        case nothingFound
        case error(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: LockInTheme.Spacing.lg) {
                        instructionHeader
                        photoPickerSection
                        if let image = selectedImage { imagePreview(image) }
                        if case .processing = parseStatus { processingIndicator }
                        resultsSection
                        if case .nothingFound = parseStatus { noResultsHelp }
                        confirmButton
                    }
                    .padding(LockInTheme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("IMPORT FROM SCREENSHOT")
                        .font(LockInTheme.Font.mono(11, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .tracking(1.5)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                if !rawText.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(showRawText ? "Hide OCR" : "Show OCR") {
                            showRawText.toggle()
                        }
                        .font(.system(size: 12))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task { await loadAndProcess(item: newItem) }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Instruction Header
    private var instructionHeader: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            HStack(spacing: LockInTheme.Spacing.sm) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28))
                    .foregroundColor(LockInTheme.Colors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screenshot Import")
                        .font(LockInTheme.Font.title(20))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("Reads calories & protein from your MND screenshot")
                        .font(.system(size: 12))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                instructionStep(n: "1", text: "In MyNetDiary, screenshot your Diary or Nutrients page")
                instructionStep(n: "2", text: "Tap below to select that screenshot")
                instructionStep(n: "3", text: "LockIn reads it on-device — nothing is uploaded")
                instructionStep(n: "4", text: "Confirm the values to save to today's log")
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()
        }
    }

    private func instructionStep(n: String, text: String) -> some View {
        HStack(alignment: .top, spacing: LockInTheme.Spacing.sm) {
            Text(n)
                .font(LockInTheme.Font.mono(11, weight: .bold))
                .foregroundColor(LockInTheme.Colors.accent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(LockInTheme.Colors.textSecondary)
        }
    }

    // MARK: - Photo Picker
    private var photoPickerSection: some View {
        PhotosPicker(
            selection: $selectedPhoto,
            matching: .screenshots,
            photoLibrary: .shared()
        ) {
            HStack {
                Image(systemName: selectedImage == nil ? "photo.badge.plus" : "arrow.clockwise.circle")
                    .font(.system(size: 20))
                Text(selectedImage == nil ? "Select Screenshot from Photos" : "Choose Different Screenshot")
                    .font(LockInTheme.Font.label(14, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(LockInTheme.Colors.accent)
            .cornerRadius(LockInTheme.Radius.md)
        }
    }

    // MARK: - Image Preview
    private func imagePreview(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("SELECTED SCREENSHOT")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .cornerRadius(LockInTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: LockInTheme.Radius.md)
                        .stroke(LockInTheme.Colors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Processing Indicator
    private var processingIndicator: some View {
        HStack(spacing: LockInTheme.Spacing.sm) {
            ProgressView()
                .tint(LockInTheme.Colors.accent)
            Text("Reading text from screenshot...")
                .font(LockInTheme.Font.label(13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
    }

    // MARK: - Results
    private var resultsSection: some View {
        Group {
            switch parseStatus {
            case .idle: EmptyView()
            case .processing: EmptyView()
            case .error(let msg):
                Text("Error: \(msg)")
                    .font(.system(size: 13))
                    .foregroundColor(LockInTheme.Colors.accentRed)
                    .padding()
                    .cardStyle()
            default:
                VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                    HStack {
                        Text("PARSED RESULTS")
                            .sectionHeaderStyle()
                        Spacer()
                        Text(parseStatusLabel)
                            .font(.system(size: 10))
                            .foregroundColor(parseStatusColor)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: LockInTheme.Spacing.sm) {
                        // Calories field
                        HStack {
                            Image(systemName: parsedCalories != nil ? "checkmark.circle.fill" : "questionmark.circle")
                                .foregroundColor(parsedCalories != nil ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.textTertiary)
                            Text("Calories")
                                .font(LockInTheme.Font.label(14))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                            Spacer()
                            TextField(parsedCalories != nil ? String(parsedCalories!) : "Enter manually", text: $caloriesText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(16, weight: .semibold))
                                .foregroundColor(LockInTheme.Colors.accent)
                                .frame(width: 80)
                            Text("kcal")
                                .font(LockInTheme.Font.mono(13))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        .padding(LockInTheme.Spacing.md)
                        .cardStyle()

                        // Protein field
                        HStack {
                            Image(systemName: parsedProtein != nil ? "checkmark.circle.fill" : "questionmark.circle")
                                .foregroundColor(parsedProtein != nil ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.textTertiary)
                            Text("Protein")
                                .font(LockInTheme.Font.label(14))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                            Spacer()
                            TextField(parsedProtein != nil ? String(parsedProtein!) : "Enter manually", text: $proteinText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(16, weight: .semibold))
                                .foregroundColor(LockInTheme.Colors.accent)
                                .frame(width: 80)
                            Text("g")
                                .font(LockInTheme.Font.mono(13))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        .padding(LockInTheme.Spacing.md)
                        .cardStyle()
                    }

                    if showRawText && !rawText.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RAW OCR TEXT (debug)")
                                .sectionHeaderStyle()
                            Text(rawText)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(LockInTheme.Colors.textTertiary)
                                .lineLimit(30)
                        }
                        .padding(LockInTheme.Spacing.sm)
                        .cardStyle()
                    }
                }
            }
        }
    }

    private var noResultsHelp: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("COULDN'T FIND DATA AUTOMATICALLY")
                .sectionHeaderStyle()
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 6) {
                Text("Try these screenshot types:")
                    .font(LockInTheme.Font.label(13))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                tipRow("MND Diary → shows each meal with calorie totals")
                tipRow("MND Nutrients report → shows 'Calories' and 'Protein' labels")
                tipRow("Make sure the text is readable (not blurry)")
                Text("Or enter the values manually in the fields above.")
                    .font(.system(size: 12))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·").foregroundColor(LockInTheme.Colors.accent)
            Text(text).font(.system(size: 12)).foregroundColor(LockInTheme.Colors.textTertiary)
        }
    }

    // MARK: - Confirm Button
    private var confirmButton: some View {
        Group {
            let cal = Int(caloriesText) ?? parsedCalories
            let prot = Int(proteinText) ?? parsedProtein
            if cal != nil || prot != nil {
                Button {
                    onConfirm(cal ?? 0, prot ?? 0)
                    isPresented = false
                } label: {
                    VStack(spacing: 2) {
                        Text("SAVE TO TODAY'S LOG")
                            .font(LockInTheme.Font.label(15, weight: .bold))
                        if let c = cal, let p = prot {
                            Text("\(c) kcal · \(p)g protein")
                                .font(.system(size: 11))
                                .opacity(0.8)
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LockInTheme.Colors.accentGreen)
                    .cornerRadius(LockInTheme.Radius.md)
                }
            }
        }
    }

    // MARK: - Load + Process
    private func loadAndProcess(item: PhotosPickerItem?) async {
        guard let item else { return }
        parseStatus = .processing

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            parseStatus = .error("Couldn't load image from photo library.")
            return
        }
        selectedImage = image

        let (calories, protein, text) = await runOCR(on: image)
        rawText = text
        parsedCalories = calories
        parsedProtein = protein

        if let c = calories { caloriesText = String(c) }
        if let p = protein { proteinText = String(p) }

        if calories != nil && protein != nil {
            parseStatus = .foundBoth
        } else if calories != nil {
            parseStatus = .foundCaloriesOnly
        } else if protein != nil {
            parseStatus = .foundProteinOnly
        } else {
            parseStatus = .nothingFound
        }
    }

    // MARK: - Vision OCR
    private func runOCR(on image: UIImage) async -> (calories: Int?, protein: Int?, rawText: String) {
        guard let cgImage = image.cgImage else { return (nil, nil, "") }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: (nil, nil, ""))
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let fullText = lines.joined(separator: "\n")

                let calories = ScreenshotParser.parseCalories(from: lines)
                let protein  = ScreenshotParser.parseProtein(from: lines)

                continuation.resume(returning: (calories, protein, fullText))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false   // faster, better for numbers

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Computed Labels
    private var parseStatusLabel: String {
        switch parseStatus {
        case .foundBoth:          return "Both found ✓"
        case .foundCaloriesOnly:  return "Calories found, protein missing"
        case .foundProteinOnly:   return "Protein found, calories missing"
        case .nothingFound:       return "Nothing detected — enter manually"
        default: return ""
        }
    }

    private var parseStatusColor: Color {
        switch parseStatus {
        case .foundBoth:  return LockInTheme.Colors.accentGreen
        case .nothingFound: return LockInTheme.Colors.accentOrange
        default: return LockInTheme.Colors.textSecondary
        }
    }
}

// MARK: - Screenshot Parser
// Handles multiple MyNetDiary display formats.
// MyNetDiary typically shows:
//   "Calories    1,847"  or  "Total   1,847 cal"  or  "1847 kcal"
//   "Protein     138 g"  or  "Protein  138"
enum ScreenshotParser {

    static func parseCalories(from lines: [String]) -> Int? {
        // Strategy: scan lines for calorie-related keywords and extract nearby numbers
        let calorieKeywords = ["calorie", "calories", "kcal", "cal", "energy", "total cal", "total calories"]
        let excludeKeywords  = ["protein", "fat", "carb", "fiber", "sodium", "sugar", "sat"]

        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            let hasCalorie = calorieKeywords.contains { lower.contains($0) }
            let hasExclude = excludeKeywords.contains { lower.contains($0) }
            guard hasCalorie && !hasExclude else { continue }

            // Try to extract number from this line
            if let n = extractLargestNumber(from: line), n > 50 && n < 10000 {
                return n
            }
            // Try the next line (MND sometimes puts the value on the next line)
            if i + 1 < lines.count, let n = extractLargestNumber(from: lines[i + 1]), n > 50 && n < 10000 {
                return n
            }
        }

        // Fallback: look for "Total" line which often has the calorie total
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.hasPrefix("total") || lower == "total" {
                if let n = extractLargestNumber(from: line), n > 100 && n < 8000 { return n }
                if i + 1 < lines.count, let n = extractLargestNumber(from: lines[i + 1]), n > 100 && n < 8000 { return n }
            }
        }
        return nil
    }

    static func parseProtein(from lines: [String]) -> Int? {
        let proteinKeywords = ["protein"]

        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard proteinKeywords.contains(where: { lower.contains($0) }) else { continue }

            // Try number in same line
            if let n = extractLargestNumber(from: line), n >= 0 && n < 500 { return n }
            // Try next line
            if i + 1 < lines.count, let n = extractLargestNumber(from: lines[i + 1]), n >= 0 && n < 500 { return n }
        }
        return nil
    }

    /// Extracts the largest integer from a string, handling commas (e.g. "1,847" → 1847)
    private static func extractLargestNumber(from text: String) -> Int? {
        // Replace commas inside numbers: "1,847" → "1847"
        let cleaned = text.replacingOccurrences(of: #"(\d),(\d)"#, with: "$1$2", options: .regularExpression)
        // Find all digit sequences
        let pattern = try? NSRegularExpression(pattern: #"\d+"#)
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        let matches = pattern?.matches(in: cleaned, range: range) ?? []
        let numbers = matches.compactMap { match -> Int? in
            guard let r = Range(match.range, in: cleaned) else { return nil }
            return Int(cleaned[r])
        }
        return numbers.max()
    }
}
