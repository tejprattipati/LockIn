// LockInWidget.swift
// Home-screen widget: incomplete checklist items + today's nutrition status.
// Reads from App Group shared UserDefaults written by the main LockIn app.
// Supports small (count summary) and medium (task list) families.

import WidgetKit
import SwiftUI

// MARK: - Shared suite name (must match WidgetDataStore in main app)
private let appGroupSuite = "group.com.personal.LockIn"

// MARK: - Timeline Entry
struct LockInWidgetEntry: TimelineEntry {
    let date: Date
    let incompleteTasks: [String]
    let dayNumber: Int
    let caloriesToday: Int?
    let caloriesTarget: Int
    let proteinToday: Int?
    let proteinTarget: Int
}

// MARK: - Provider
struct LockInWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> LockInWidgetEntry {
        LockInWidgetEntry(
            date: .now,
            incompleteTasks: ["Morning weigh-in", "Log Meal 1", "Hit protein target"],
            dayNumber: 14,
            caloriesToday: 1320,
            caloriesTarget: 1900,
            proteinToday: 98,
            proteinTarget: 145
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LockInWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockInWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 30 minutes; main app also triggers reload on data changes
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> LockInWidgetEntry {
        let d = UserDefaults(suiteName: appGroupSuite)
        let tasks      = d?.stringArray(forKey: "incompleteTasks") ?? []
        let day        = d?.integer(forKey: "dayNumber") ?? 1
        let calToday   = d?.integer(forKey: "caloriesToday") ?? 0
        let calTarget  = d?.integer(forKey: "caloriesTarget") ?? 1900
        let protToday  = d?.integer(forKey: "proteinToday") ?? 0
        let protTarget = d?.integer(forKey: "proteinTarget") ?? 145
        return LockInWidgetEntry(
            date: .now,
            incompleteTasks: tasks,
            dayNumber: max(1, day),
            caloriesToday: calToday > 0 ? calToday : nil,
            caloriesTarget: calTarget,
            proteinToday: protToday > 0 ? protToday : nil,
            proteinTarget: protTarget
        )
    }
}

// MARK: - Widget Views

struct LockInWidgetEntryView: View {
    var entry: LockInWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        default:            mediumView
        }
    }

    // MARK: Small — remaining count + nutrition summary
    private var smallView: some View {
        ZStack {
            Color(hex: "0C0F1A")
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack {
                    Text("LOCKIN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "4F8EF7"))
                        .tracking(2)
                    Spacer()
                    Text("Day \(entry.dayNumber)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "7D8BA8"))
                }

                Spacer()

                // Remaining tasks count
                if entry.incompleteTasks.isEmpty {
                    Text("All done")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "30D158"))
                    Text("today ✓")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "7D8BA8"))
                } else {
                    Text("\(entry.incompleteTasks.count)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "4F8EF7"))
                    Text("task\(entry.incompleteTasks.count == 1 ? "" : "s") left")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "7D8BA8"))
                }

                Spacer()

                // Nutrition row
                HStack(spacing: 6) {
                    if let cal = entry.caloriesToday {
                        nutritionChip(
                            value: "\(cal)",
                            unit: "kcal",
                            color: cal <= entry.caloriesTarget ? Color(hex: "30D158") : Color(hex: "FF9F0A")
                        )
                    }
                    if let prot = entry.proteinToday {
                        nutritionChip(
                            value: "\(prot)g",
                            unit: "pro",
                            color: prot >= entry.proteinTarget ? Color(hex: "30D158") : Color(hex: "FF9F0A")
                        )
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: Medium — task list + nutrition
    private var mediumView: some View {
        ZStack {
            Color(hex: "0C0F1A")
            HStack(alignment: .top, spacing: 0) {
                // Left: task list
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("LOCKIN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "4F8EF7"))
                            .tracking(2)
                        Spacer()
                        Text("Day \(entry.dayNumber)")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "7D8BA8"))
                    }

                    if entry.incompleteTasks.isEmpty {
                        Spacer()
                        Text("All tasks complete")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "30D158"))
                        Spacer()
                    } else {
                        ForEach(Array(entry.incompleteTasks.prefix(5).enumerated()), id: \.offset) { _, task in
                            HStack(spacing: 5) {
                                Circle()
                                    .stroke(Color(hex: "28334E"), lineWidth: 1.5)
                                    .frame(width: 7, height: 7)
                                Text(task)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "F0F4FF"))
                                    .lineLimit(1)
                            }
                        }
                        if entry.incompleteTasks.count > 5 {
                            Text("+\(entry.incompleteTasks.count - 5) more")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "3D4860"))
                                .padding(.leading, 12)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .padding(.vertical, 12)

                // Divider
                Rectangle()
                    .fill(Color(hex: "28334E"))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                // Right: nutrition
                VStack(alignment: .leading, spacing: 8) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "3D4860"))
                        .tracking(1.5)

                    nutritionStat(
                        label: "CAL",
                        logged: entry.caloriesToday,
                        target: entry.caloriesTarget,
                        unit: "kcal",
                        aboveIsGood: false
                    )
                    nutritionStat(
                        label: "PRO",
                        logged: entry.proteinToday,
                        target: entry.proteinTarget,
                        unit: "g",
                        aboveIsGood: true
                    )

                    Spacer(minLength: 0)
                }
                .frame(width: 90)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Sub-components
    private func nutritionChip(value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: "7D8BA8"))
        }
    }

    private func nutritionStat(label: String, logged: Int?, target: Int, unit: String, aboveIsGood: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Color(hex: "3D4860"))
                .tracking(1)
            if let v = logged {
                let isGood = aboveIsGood ? v >= target : v <= target
                Text("\(v)\(unit)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isGood ? Color(hex: "30D158") : Color(hex: "FF9F0A"))
                Text("/ \(target)")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "7D8BA8"))
            } else {
                Text("—")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "3D4860"))
                Text("not logged")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "3D4860"))
            }
        }
    }
}

// MARK: - Color Hex (self-contained, no LockInTheme dependency)
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Widget Declaration
struct LockInWidget: Widget {
    let kind = "LockInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockInWidgetProvider()) { entry in
            LockInWidgetEntryView(entry: entry)
                .containerBackground(Color(hex: "0C0F1A"), for: .widget)
        }
        .configurationDisplayName("LockIn")
        .description("Today's incomplete tasks and nutrition status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct LockInWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockInWidget()
    }
}
