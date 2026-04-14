// ProgressPhotoView.swift
// Progress photo timeline with Gemini AI analysis of body composition changes.
// Photos stored locally in Documents/ProgressPhotos/ — no cloud, no database.

import SwiftUI
import SwiftData
import PhotosUI

struct ProgressPhotoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]

    @State private var showSourcePicker = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedDetail: ProgressPhoto?
    @State private var weightInput: String = ""
    @State private var pendingImage: UIImage?
    @State private var showSaveSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                if photos.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: LockInTheme.Spacing.sm
                        ) {
                            ForEach(photos) { photo in
                                PhotoThumbnailCard(photo: photo)
                                    .onTapGesture { selectedDetail = photo }
                            }
                        }
                        .padding(LockInTheme.Spacing.md)
                    }
                }
            }
            .navigationTitle("Progress Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSourcePicker = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(LockInTheme.Colors.accent)
                    }
                }
            }
            .confirmationDialog("Add Progress Photo", isPresented: $showSourcePicker, titleVisibility: .visible) {
                Button("Take Photo") { showCamera = true }
                Button("Choose from Library") { showPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let item, let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pendingImage = image
                        showSaveSheet = true
                    }
                    selectedPhoto = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    pendingImage = image
                    showSaveSheet = true
                }
            }
            .sheet(isPresented: $showSaveSheet) {
                if let img = pendingImage {
                    SavePhotoSheet(image: img, isPresented: $showSaveSheet) { weight, notes in
                        savePhoto(img, bodyWeight: weight, notes: notes)
                    }
                }
            }
            .sheet(item: $selectedDetail) { photo in
                PhotoDetailView(photo: photo, allPhotos: photos)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(LockInTheme.Colors.textTertiary)
            Text("No Progress Photos")
                .font(LockInTheme.Font.title(20))
                .foregroundColor(LockInTheme.Colors.textPrimary)
            Text("Add your first photo to track visible body composition changes over time. AI analysis compares each new photo to the previous one.")
                .font(LockInTheme.Font.label(13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LockInTheme.Spacing.lg)
            Button {
                showSourcePicker = true
            } label: {
                Text("Add First Photo")
                    .font(LockInTheme.Font.label(14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, LockInTheme.Spacing.xl)
                    .padding(.vertical, LockInTheme.Spacing.sm + 4)
                    .background(LockInTheme.Colors.accent)
                    .cornerRadius(LockInTheme.Radius.md)
            }
        }
        .padding(LockInTheme.Spacing.xl)
    }

    // MARK: - Save
    private func savePhoto(_ image: UIImage, bodyWeight: Double?, notes: String) {
        guard let filename = ProgressPhotoStorage.save(image) else { return }
        let photo = ProgressPhoto(
            date: .now,
            filename: filename,
            bodyWeight: bodyWeight,
            notes: notes
        )
        modelContext.insert(photo)
        try? modelContext.save()
    }
}

// MARK: - Thumbnail Card
struct PhotoThumbnailCard: View {
    let photo: ProgressPhoto

    private var image: UIImage? { ProgressPhotoStorage.load(filename: photo.filename) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(3/4, contentMode: .fill)
                    .clipped()
                    .cornerRadius(LockInTheme.Radius.md)
            } else {
                Rectangle()
                    .fill(LockInTheme.Colors.surface)
                    .aspectRatio(3/4, contentMode: .fit)
                    .cornerRadius(LockInTheme.Radius.md)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(shortDate(photo.date))
                    .font(LockInTheme.Font.mono(11, weight: .semibold))
                    .foregroundColor(.white)
                if let w = photo.bodyWeight {
                    Text(String(format: "%.1f lb", w))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(6)
            .background(Color.black.opacity(0.55))
            .cornerRadius(LockInTheme.Radius.sm)
            .padding(6)
        }
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }
}

// MARK: - Photo Detail View
struct PhotoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let photo: ProgressPhoto
    let allPhotos: [ProgressPhoto]

    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var localAnalysis: String?

    private var image: UIImage? { ProgressPhotoStorage.load(filename: photo.filename) }

    // The photo taken just before this one (for comparison)
    private var previousPhoto: ProgressPhoto? {
        let sorted = allPhotos.sorted { $0.date < $1.date }
        guard let idx = sorted.firstIndex(where: { $0.id == photo.id }), idx > 0 else { return nil }
        return sorted[idx - 1]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: LockInTheme.Spacing.md) {
                        if let img = image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(LockInTheme.Radius.md)
                                .padding(.horizontal, LockInTheme.Spacing.md)
                        }

                        // Metadata
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fullDate(photo.date))
                                    .font(LockInTheme.Font.label(14, weight: .semibold))
                                    .foregroundColor(LockInTheme.Colors.textPrimary)
                                if let w = photo.bodyWeight {
                                    Text(String(format: "%.1f lb", w))
                                        .font(LockInTheme.Font.mono(13))
                                        .foregroundColor(LockInTheme.Colors.accent)
                                }
                            }
                            Spacer()
                            if previousPhoto != nil {
                                Text("vs. prev photo")
                                    .font(.system(size: 11))
                                    .foregroundColor(LockInTheme.Colors.textTertiary)
                            }
                        }
                        .padding(.horizontal, LockInTheme.Spacing.md)

                        // AI Analysis
                        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                            HStack {
                                Text("AI ANALYSIS")
                                    .sectionHeaderStyle()
                                Spacer()
                                if isAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(LockInTheme.Colors.accent)
                                }
                            }

                            let displayAnalysis = localAnalysis ?? photo.aiAnalysis

                            if let analysis = displayAnalysis, !analysis.isEmpty {
                                Text(analysis)
                                    .font(LockInTheme.Font.label(13))
                                    .foregroundColor(LockInTheme.Colors.textSecondary)
                                    .padding(LockInTheme.Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .cardStyle()
                            } else if let err = analysisError {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundColor(LockInTheme.Colors.accentRed)
                                    .padding(LockInTheme.Spacing.md)
                                    .cardStyle()
                            } else {
                                Text("No analysis yet.")
                                    .font(.system(size: 12))
                                    .foregroundColor(LockInTheme.Colors.textTertiary)
                                    .padding(LockInTheme.Spacing.md)
                                    .cardStyle()
                            }

                            Button {
                                runAnalysis()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text(previousPhoto != nil ? "Analyze vs. Previous Photo" : "Analyze Photo")
                                }
                                .font(LockInTheme.Font.label(13, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isAnalyzing ? LockInTheme.Colors.accentDim : LockInTheme.Colors.accent)
                                .cornerRadius(LockInTheme.Radius.sm)
                            }
                            .disabled(isAnalyzing)
                        }
                        .padding(.horizontal, LockInTheme.Spacing.md)

                        if !photo.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NOTES")
                                    .sectionHeaderStyle()
                                Text(photo.notes)
                                    .font(LockInTheme.Font.label(13))
                                    .foregroundColor(LockInTheme.Colors.textSecondary)
                                    .padding(LockInTheme.Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .cardStyle()
                            }
                            .padding(.horizontal, LockInTheme.Spacing.md)
                        }

                        // Delete
                        Button(role: .destructive) {
                            ProgressPhotoStorage.delete(filename: photo.filename)
                            modelContext.delete(photo)
                            try? modelContext.save()
                            dismiss()
                        } label: {
                            Text("Delete Photo")
                                .font(LockInTheme.Font.label(13))
                                .foregroundColor(LockInTheme.Colors.accentRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(LockInTheme.Colors.accentRed.opacity(0.1))
                                .cornerRadius(LockInTheme.Radius.sm)
                        }
                        .padding(.horizontal, LockInTheme.Spacing.md)
                        .padding(.bottom, LockInTheme.Spacing.xl)
                    }
                    .padding(.top, LockInTheme.Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LockInTheme.Colors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func runAnalysis() {
        guard let current = image else { return }
        isAnalyzing = true
        analysisError = nil
        Task {
            do {
                let prevImg = previousPhoto.flatMap { ProgressPhotoStorage.load(filename: $0.filename) }
                let result = try await GeminiService.analyzeProgressPhoto(current: current, previous: prevImg)
                localAnalysis = result
                photo.aiAnalysis = result
                try? modelContext.save()
            } catch {
                analysisError = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    private func fullDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f.string(from: d)
    }
}

// MARK: - Save Photo Sheet
struct SavePhotoSheet: View {
    let image: UIImage
    @Binding var isPresented: Bool
    var onSave: (Double?, String) -> Void

    @State private var weightText = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                VStack(spacing: LockInTheme.Spacing.md) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(LockInTheme.Radius.md)
                        .padding(.horizontal)

                    VStack(spacing: LockInTheme.Spacing.sm) {
                        HStack {
                            Text("Weight (optional)")
                                .font(LockInTheme.Font.label(14))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                            Spacer()
                            TextField("170.0", text: $weightText)
                                .keyboardType(.decimalPad)
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.accent)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("lb")
                                .font(LockInTheme.Font.mono(13))
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        .padding(LockInTheme.Spacing.md)
                        .cardStyle()

                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Notes (optional)...")
                                    .font(LockInTheme.Font.label(13))
                                    .foregroundColor(LockInTheme.Colors.textTertiary)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 8)
                            }
                            TextEditor(text: $notes)
                                .font(LockInTheme.Font.label(13))
                                .foregroundColor(LockInTheme.Colors.textPrimary)
                                .frame(height: 80)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(LockInTheme.Spacing.sm)
                        .cardStyle()
                    }
                    .padding(.horizontal)

                    Button {
                        let w = Double(weightText)
                        onSave(w, notes)
                        isPresented = false
                    } label: {
                        Text("SAVE PHOTO")
                            .font(LockInTheme.Font.label(14, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LockInTheme.Colors.accent)
                            .cornerRadius(LockInTheme.Radius.md)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, LockInTheme.Spacing.md)
            }
            .navigationTitle("Save Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Camera Picker (UIImagePickerController wrapper)
struct CameraPickerView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ p: CameraPickerView) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onCapture(img)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
