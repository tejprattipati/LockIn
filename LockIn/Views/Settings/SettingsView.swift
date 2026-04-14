// SettingsView.swift
// Configure user profile, notifications, HealthKit, and MND integration.

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query private var reminderRules: [ReminderRule]
    @Query private var integrationStatuses: [ExternalIntegrationStatus]

    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared

    @State private var showProfileEditor = false
    @State private var showReminderEditor = false
    @State private var notificationAuthRequested = false

    private var userProfile: UserProfile? { userProfiles.first }
    private var integrationStatus: ExternalIntegrationStatus? { integrationStatuses.first }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                List {
                    profileSection
                    notificationsSection
                    healthKitSection
                    mndSection
                    appInfoSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(LockInTheme.Font.mono(14, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .tracking(3)
                        .glowAccent(radius: 8)
                }
            }
            .sheet(isPresented: $showProfileEditor) {
                if let profile = userProfile {
                    ProfileEditorSheet(profile: profile, isPresented: $showProfileEditor)
                }
            }
            .sheet(isPresented: $showReminderEditor) {
                ReminderEditorView(rules: reminderRules, isPresented: $showReminderEditor)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await notificationManager.checkStatus()
            await healthKitManager.checkPermissions()
        }
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        Section {
            if let profile = userProfile {
                HStack {
                    Text("Height")
                    Spacer()
                    Text(profile.heightFeetInches)
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                HStack {
                    Text("Current Weight")
                    Spacer()
                    Text(String(format: "%.1f lb", profile.currentWeight))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                HStack {
                    Text("Est. Body Fat")
                    Spacer()
                    Text(String(format: "%.1f%%", profile.estimatedBodyFatPercent))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                HStack {
                    Text("Activity Level")
                    Spacer()
                    Text(profile.activityLevel.shortLabel)
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                        .font(.system(size: 13))
                }
                Button("Edit Profile") {
                    showProfileEditor = true
                }
                .foregroundColor(LockInTheme.Colors.accent)
            }
        } header: {
            Text("MY PROFILE")
                .sectionHeaderStyle()
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        Section {
            HStack {
                Text("Authorization")
                Spacer()
                Text(authStatusLabel)
                    .font(.system(size: 12))
                    .foregroundColor(authStatusColor)
            }

            if notificationManager.authorizationStatus != .authorized {
                Button("Request Notification Permission") {
                    Task {
                        let granted = await notificationManager.requestAuthorization()
                        notificationAuthRequested = true
                        if granted {
                            await notificationManager.scheduleAll(from: reminderRules)
                        }
                    }
                }
                .foregroundColor(LockInTheme.Colors.accent)
            }

            Button("Edit Reminder Schedule") {
                showReminderEditor = true
            }
            .foregroundColor(LockInTheme.Colors.accent)
        } header: {
            Text("NOTIFICATIONS")
                .sectionHeaderStyle()
        } footer: {
            Text("LockIn uses daily local notifications. No data leaves your device.")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - HealthKit Section
    private var healthKitSection: some View {
        Section {
            if healthKitManager.isAvailable {
                HStack {
                    Text("Weight Read")
                    Spacer()
                    permissionBadge(healthKitManager.weightPermissionGranted)
                }
                HStack {
                    Text("Steps Read")
                    Spacer()
                    permissionBadge(healthKitManager.stepsPermissionGranted)
                }
                HStack {
                    Text("Workouts Read")
                    Spacer()
                    permissionBadge(healthKitManager.workoutsPermissionGranted)
                }
                if let sync = healthKitManager.lastSyncDate {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(timeAgo(sync))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                            .font(.system(size: 12))
                    }
                }
                Button("Request HealthKit Access") {
                    Task { await healthKitManager.requestAuthorization(writeWeight: false) }
                }
                .foregroundColor(LockInTheme.Colors.accent)
                Button("Sync Now") {
                    Task { await healthKitManager.sync() }
                }
                .foregroundColor(LockInTheme.Colors.textSecondary)
            } else {
                Text("HealthKit not available on this device.")
                    .foregroundColor(LockInTheme.Colors.textTertiary)
                    .font(.system(size: 13))
            }
        } header: {
            Text("APPLE HEALTH")
                .sectionHeaderStyle()
        } footer: {
            Text("Weight and steps are read-only. LockIn does not write to HealthKit unless you explicitly enable it.")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - MND Section
    private var mndSection: some View {
        Section {
            HStack {
                Text("Deep Link")
                Spacer()
                Text("mynetdiary://")
                    .font(LockInTheme.Font.mono(12))
                    .foregroundColor(LockInTheme.Colors.textTertiary)
            }
            Button("Test Open MyNetDiary") {
                Task { await MyNetDiaryManager.shared.open(.openApp) }
            }
            .foregroundColor(LockInTheme.Colors.accent)
        } header: {
            Text("MYNETDIARY INTEGRATION")
                .sectionHeaderStyle()
        } footer: {
            Text("The deep link 'mynetdiary://' is not officially documented. LockIn will try it and fall back to manual instructions if it fails.")
                .font(.system(size: 11))
                .foregroundColor(LockInTheme.Colors.textTertiary)
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - App Info Section
    private var appInfoSection: some View {
        Section {
            HStack {
                Text("App")
                Spacer()
                Text("LockIn")
                    .foregroundColor(LockInTheme.Colors.textSecondary)
            }
            HStack {
                Text("Purpose")
                Spacer()
                Text("Personal cut discipline system")
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .font(.system(size: 12))
            }
            HStack {
                Text("Data Storage")
                Spacer()
                Text("100% local (SwiftData)")
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .font(.system(size: 12))
            }
        } header: {
            Text("ABOUT")
                .sectionHeaderStyle()
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }

    // MARK: - Helpers
    private var authStatusLabel: String {
        switch notificationManager.authorizationStatus {
        case .authorized: return "Authorized"
        case .denied:     return "Denied — enable in Settings app"
        case .notDetermined: return "Not requested yet"
        case .provisional: return "Provisional"
        case .ephemeral:  return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var authStatusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized: return LockInTheme.Colors.accentGreen
        case .denied:     return LockInTheme.Colors.accentRed
        default:          return LockInTheme.Colors.accentOrange
        }
    }

    @ViewBuilder
    private func permissionBadge(_ granted: Bool) -> some View {
        Text(granted ? "Granted" : "Not Granted")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(granted ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.textTertiary)
    }

    private func timeAgo(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        return "\(diff / 3600)h ago"
    }
}

// MARK: - Profile Editor Sheet
struct ProfileEditorSheet: View {
    @Bindable var profile: UserProfile
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var weightText: String = ""
    @State private var bfText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                Form {
                    Section("PHYSICAL STATS") {
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("170.0", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.accent)
                            Text("lb")
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                        HStack {
                            Text("Body Fat %")
                            Spacer()
                            TextField("25.5", text: $bfText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(LockInTheme.Font.mono(14))
                                .foregroundColor(LockInTheme.Colors.accent)
                            Text("%")
                                .foregroundColor(LockInTheme.Colors.textSecondary)
                        }
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    Section("ACTIVITY") {
                        Picker("Activity Level", selection: $profile.activityLevel) {
                            ForEach(ActivityLevel.allCases) { level in
                                Text(level.shortLabel).tag(level)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                    .listRowBackground(LockInTheme.Colors.surface)

                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(LockInTheme.Colors.accent)
                            Text("Activity multiplier is applied conservatively (×\(String(format: "%.2f", profile.activityLevel.multiplier)) × 0.95).")
                                .font(.system(size: 12))
                                .foregroundColor(LockInTheme.Colors.textTertiary)
                        }
                    }
                    .listRowBackground(LockInTheme.Colors.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let w = Double(weightText) { profile.currentWeight = w }
                        if let bf = Double(bfText) { profile.estimatedBodyFatPercent = bf }
                        profile.updatedAt = .now
                        try? modelContext.save()
                        isPresented = false
                    }
                    .foregroundColor(LockInTheme.Colors.accent)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                weightText = String(format: "%.1f", profile.currentWeight)
                bfText = String(format: "%.1f", profile.estimatedBodyFatPercent)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Reminder Editor View
struct ReminderEditorView: View {
    let rules: [ReminderRule]
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                List {
                    ForEach(rules.sorted { $0.hour < $1.hour }) { rule in
                        ReminderRuleRow(rule: rule, onChange: {
                            rescheduleAll()
                        })
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func rescheduleAll() {
        Task {
            await NotificationManager.shared.scheduleAll(from: rules)
        }
    }
}

struct ReminderRuleRow: View {
    @Bindable var rule: ReminderRule
    var onChange: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.type.rawValue)
                    .font(LockInTheme.Font.label(13))
                    .foregroundColor(LockInTheme.Colors.textPrimary)
                Text(rule.timeString)
                    .font(LockInTheme.Font.mono(12))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $rule.isEnabled)
                .tint(LockInTheme.Colors.accent)
                .labelsHidden()
                .onChange(of: rule.isEnabled) { _, _ in
                    rule.updatedAt = .now
                    try? modelContext.save()
                    onChange()
                }
        }
        .listRowBackground(LockInTheme.Colors.surface)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserProfile.self, ReminderRule.self,
                               ExternalIntegrationStatus.self], inMemory: true)
}
