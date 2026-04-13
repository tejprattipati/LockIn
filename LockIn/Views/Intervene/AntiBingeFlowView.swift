// AntiBingeFlowView.swift
// The core intervention sequence. Walks through a structured decision flow
// designed to interrupt the ordering impulse and redirect to planned food.

import SwiftUI
import SwiftData

struct AntiBingeFlowView: View {
    @Binding var isPresented: Bool
    var log: DailyLog?

    @Environment(\.modelContext) private var modelContext
    @Query private var goalProfiles: [GoalProfile]

    @State private var currentStep: InterveneStep = .askAboutNightMeal
    @State private var hasNightMeal: Bool? = nil
    @State private var hasHitProtein: Bool? = nil
    @State private var hasLoggedMND: Bool? = nil
    @State private var timerSeconds: Int = 900  // 15 minutes
    @State private var timerActive = false
    @State private var timerComplete = false
    @State private var didResist: Bool? = nil
    @State private var showingReplacementFood = false

    private var goalProfile: GoalProfile? { goalProfiles.first }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                LockInTheme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    progressBar
                    ScrollView {
                        VStack(spacing: LockInTheme.Spacing.lg) {
                            stepContent
                        }
                        .padding(LockInTheme.Spacing.md)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("STOP + THINK")
                        .font(LockInTheme.Font.mono(13, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accentRed)
                        .tracking(2)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Exit") { isPresented = false }
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
            .onReceive(timer) { _ in
                guard timerActive && !timerComplete else { return }
                if timerSeconds > 0 {
                    timerSeconds -= 1
                } else {
                    timerComplete = true
                    timerActive = false
                    currentStep = .finalDecision
                }
            }
            .onDisappear {
                timerActive = false
                // Log intervention session
                if let log = log {
                    log.interveneSessionCount += 1
                    log.lastInterveneAt = .now
                    try? modelContext.save()
                }
                // Cancel follow-up notification if user exits
                Task { NotificationManager.shared.cancelInterveneFollowUp() }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        let total = InterveneStep.allCases.count
        let current = currentStep.rawValue + 1
        let progress = Double(current) / Double(total)

        return VStack(spacing: 0) {
            LockInProgressBar(value: progress, color: LockInTheme.Colors.accentRed, height: 3)
                .padding(.horizontal, LockInTheme.Spacing.md)
                .padding(.vertical, LockInTheme.Spacing.sm)
            Divider().background(LockInTheme.Colors.border)
        }
    }

    // MARK: - Step Content Router
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .askAboutNightMeal:     step_AskNightMeal
        case .askAboutProtein:       step_AskProtein
        case .askAboutMNDLogging:    step_AskMND
        case .showProgress:          step_ShowProgress
        case .showDamageComparison:  step_DamageComparison
        case .showReplacementFlow:   step_ReplacementFlow
        case .timer:                 step_Timer
        case .finalDecision:         step_FinalDecision
        case .outcome:               step_Outcome
        }
    }

    // MARK: - Step 0: Did you eat your night meal?
    private var step_AskNightMeal: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            StepHeader(
                number: "01",
                question: "Did you already eat your planned night meal?",
                context: "This is the first line of defense. If you haven't eaten it yet, eat it before anything else."
            )

            if let meal = log?.nightMeal {
                VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                    Text("YOUR PLANNED NIGHT MEAL:")
                        .sectionHeaderStyle()
                    Text(meal.name)
                        .font(LockInTheme.Font.title(18))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("\(meal.plannedCalories) kcal · \(meal.plannedProtein)g protein")
                        .font(LockInTheme.Font.mono(13))
                        .foregroundColor(LockInTheme.Colors.accent)
                    ForEach(meal.foods.prefix(4), id: \.self) { food in
                        Text("• \(food)")
                            .font(LockInTheme.Font.label(13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                }
                .padding(LockInTheme.Spacing.md)
                .cardStyle()
            } else {
                Text("⚠️ No night meal was pre-planned. Go to Plan → set one up now. This is your failure point.")
                    .font(LockInTheme.Font.label(13))
                    .foregroundColor(LockInTheme.Colors.accentOrange)
                    .padding(LockInTheme.Spacing.md)
                    .background(LockInTheme.Colors.accentOrange.opacity(0.1))
                    .cornerRadius(LockInTheme.Radius.md)
            }

            YesNoButtons(
                yesLabel: "Yes, I ate it",
                noLabel: "No, not yet",
                onYes: {
                    hasNightMeal = true
                    // Mark night meal done
                    log?.nightMeal?.completedAt = .now
                    log?.checklist(for: .loggedNightMeal)?.isCompleted = true
                    try? modelContext.save()
                    advance()
                },
                onNo: {
                    hasNightMeal = false
                    advance()
                }
            )
        }
    }

    // MARK: - Step 1: Did you hit protein?
    private var step_AskProtein: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            StepHeader(
                number: "02",
                question: "Have you hit your protein target today?",
                context: "If you haven't hit protein, hunger tonight is expected. That's not an emergency — it's a signal to eat your planned protein source."
            )

            VStack(spacing: LockInTheme.Spacing.sm) {
                let prot = log?.actualProtein ?? 0
                let target = goalProfile?.dailyProteinTarget ?? 145
                StatRow(label: "Protein logged today", value: "\(prot)g")
                StatRow(label: "Daily target", value: "\(target)g")
                StatRow(
                    label: "Gap",
                    value: "\(max(0, target - prot))g remaining",
                    valueColor: prot >= target ? LockInTheme.Colors.accentGreen : LockInTheme.Colors.accentOrange
                )
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()

            YesNoButtons(
                yesLabel: "Yes, hit it",
                noLabel: "No, I'm short",
                onYes: {
                    hasHitProtein = true
                    log?.checklist(for: .hitProteinTarget)?.isCompleted = true
                    try? modelContext.save()
                    advance()
                },
                onNo: {
                    hasHitProtein = false
                    advance()
                }
            )
        }
    }

    // MARK: - Step 2: MyNetDiary logged?
    private var step_AskMND: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            StepHeader(
                number: "03",
                question: "Have you logged everything in MyNetDiary today?",
                context: "Not logging is how the day disappears. If you haven't logged, do it now before making any food decisions."
            )

            Button {
                Task { await MyNetDiaryManager.shared.open(.logDiary) }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open MyNetDiary")
                }
                .font(LockInTheme.Font.label(14, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LockInTheme.Colors.accent)
                .cornerRadius(LockInTheme.Radius.md)
            }

            YesNoButtons(
                yesLabel: "Yes, fully logged",
                noLabel: "No / partially logged",
                onYes: {
                    hasLoggedMND = true
                    log?.loggedInMyNetDiary = true
                    log?.checklist(for: .loggedInMND)?.isCompleted = true
                    try? modelContext.save()
                    advance()
                },
                onNo: {
                    hasLoggedMND = false
                    advance()
                }
            )
        }
    }

    // MARK: - Step 3: Show Progress
    private var step_ShowProgress: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            StepHeader(
                number: "04",
                question: "This is what you're protecting.",
                context: "Every decision tonight either moves you closer or sets you back. Look at what you've already built."
            )

            if let goal = goalProfile {
                VStack(spacing: LockInTheme.Spacing.sm) {
                    StatRow(label: "Goal date", value: goalDateString(goal.goalDate))
                    StatRow(label: "Days remaining", value: "\(goal.daysUntilGoal) days")
                    StatRow(label: "Target weight", value: "\(String(format: "%.0f", goal.targetWeight)) lb")
                    StatRow(label: "Target body fat", value: "\(String(format: "%.0f", goal.targetBodyFatPercent))%")
                    Divider().background(LockInTheme.Colors.border)
                    Text(goal.motivationStatement)
                        .font(LockInTheme.Font.mono(13))
                        .foregroundColor(LockInTheme.Colors.accent)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(LockInTheme.Spacing.md)
                .cardStyle()

                if let intermediate = goal.daysUntilIntermediate {
                    HStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(LockInTheme.Colors.accent)
                        Text("May 17 check-in: \(intermediate) days away")
                            .font(LockInTheme.Font.label(13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                    .padding(LockInTheme.Spacing.sm + 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LockInTheme.Colors.accent.opacity(0.1))
                    .cornerRadius(LockInTheme.Radius.sm)
                }

                ForEach(goal.whyICantFailStatements.prefix(3), id: \.self) { statement in
                    HStack(alignment: .top, spacing: LockInTheme.Spacing.sm) {
                        Text("→")
                            .font(LockInTheme.Font.mono(13))
                            .foregroundColor(LockInTheme.Colors.accent)
                        Text(statement)
                            .font(LockInTheme.Font.label(13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                }
            }

            ContinueButton(label: "I understand. Continue.") { advance() }
        }
    }

    // MARK: - Step 4: Damage Comparison
    private var step_DamageComparison: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            StepHeader(
                number: "05",
                question: "The cost of ordering right now:",
                context: "This is what a typical late-night order costs you vs. your plan."
            )

            VStack(spacing: LockInTheme.Spacing.sm) {
                HStack {
                    Spacer()
                    Text("ORDERING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accentRed)
                        .tracking(1.5)
                        .frame(width: 120)
                    Text("YOUR PLAN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.accentGreen)
                        .tracking(1.5)
                        .frame(width: 120)
                }

                DamageRow(label: "Calories",    orderVal: "~1,200–1,800", planVal: "~500")
                DamageRow(label: "Protein",     orderVal: "~30–50g",      planVal: "~45g")
                DamageRow(label: "Deficit",     orderVal: "BLOWN",        planVal: "Maintained")
                DamageRow(label: "Streak",      orderVal: "RESET",        planVal: "Continues")
                DamageRow(label: "Goal date",   orderVal: "Slides back",  planVal: "On track")
                DamageRow(label: "Tomorrow",    orderVal: "Guilt spiral", planVal: "Clean start")
            }
            .padding(LockInTheme.Spacing.md)
            .cardStyle()

            if let goalProfile {
                Text(goalProfile.penaltyText)
                    .font(LockInTheme.Font.label(13))
                    .foregroundColor(LockInTheme.Colors.accentRed)
                    .multilineTextAlignment(.center)
                    .padding(LockInTheme.Spacing.md)
                    .background(LockInTheme.Colors.accentRed.opacity(0.08))
                    .cornerRadius(LockInTheme.Radius.md)
            }

            ContinueButton(label: "I see the cost. Show me the replacement.") { advance() }
        }
    }

    // MARK: - Step 5: Replacement Flow
    private var step_ReplacementFlow: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            StepHeader(
                number: "06",
                question: "Here's what you eat instead.",
                context: "In this order. First the night meal. Then, only if still hungry, the emergency snack."
            )

            // Night meal
            if let nightMeal = log?.nightMeal {
                VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                    HStack {
                        Text("STEP 1: EAT THIS FIRST")
                            .sectionHeaderStyle()
                        Spacer()
                        if nightMeal.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(LockInTheme.Colors.accentGreen)
                        }
                    }
                    Text(nightMeal.name)
                        .font(LockInTheme.Font.title(17))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("\(nightMeal.plannedCalories) kcal · \(nightMeal.plannedProtein)g protein")
                        .font(LockInTheme.Font.mono(12))
                        .foregroundColor(LockInTheme.Colors.accent)
                    ForEach(nightMeal.foods, id: \.self) { food in
                        Text("• \(food)")
                            .font(LockInTheme.Font.label(13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                }
                .padding(LockInTheme.Spacing.md)
                .cardStyle()
            }

            // Emergency snack
            if let snack = log?.emergencySnack {
                VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                    Text("STEP 2: ONLY IF STILL HUNGRY AFTER STEP 1")
                        .sectionHeaderStyle()
                    Text(snack.name)
                        .font(LockInTheme.Font.title(17))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("\(snack.plannedCalories) kcal · \(snack.plannedProtein)g protein")
                        .font(LockInTheme.Font.mono(12))
                        .foregroundColor(LockInTheme.Colors.accent)
                    ForEach(snack.foods, id: \.self) { food in
                        Text("• \(food)")
                            .font(LockInTheme.Font.label(13))
                            .foregroundColor(LockInTheme.Colors.textSecondary)
                    }
                    Text("One item only. Not a buffet.")
                        .font(.system(size: 11))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                        .italic()
                }
                .padding(LockInTheme.Spacing.md)
                .cardStyle()
            }

            ContinueButton(label: "I've eaten the plan. Start the 15-minute timer.") {
                advance()
                startTimer()
            }
        }
    }

    // MARK: - Step 6: Timer
    private var step_Timer: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            StepHeader(
                number: "07",
                question: "Wait 15 minutes.",
                context: "Hunger signals peak and pass. You are not starving. The craving will decrease. Drink water. Do something else."
            )

            ZStack {
                Circle()
                    .stroke(LockInTheme.Colors.border, lineWidth: 6)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerProgress)
                VStack(spacing: 4) {
                    Text(timerDisplayString)
                        .font(LockInTheme.Font.mono(36, weight: .bold))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("remaining")
                        .font(.system(size: 12))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LockInTheme.Spacing.lg)

            VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
                Text("WHILE YOU WAIT:")
                    .sectionHeaderStyle()
                Text("• Drink a full glass of water")
                Text("• Go to a different room")
                Text("• Open something to study or read")
                Text("• Remember: this feeling passes")
            }
            .font(LockInTheme.Font.label(13))
            .foregroundColor(LockInTheme.Colors.textSecondary)
            .padding(LockInTheme.Spacing.md)
            .cardStyle()

            if timerComplete {
                ContinueButton(label: "Timer done. Make my decision.") { advance() }
            }
        }
    }

    // MARK: - Step 7: Final Decision
    private var step_FinalDecision: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            StepHeader(
                number: "08",
                question: "Do you still want to order food?",
                context: "You've waited 15 minutes. You've seen the cost. You've eaten or have a plan. Make your honest choice."
            )

            VStack(spacing: LockInTheme.Spacing.sm) {
                Button {
                    didResist = true
                    log?.resistedLateNightOrder = true
                    try? modelContext.save()
                    advance()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I RESISTED. I'M STAYING ON PLAN.")
                                .font(.system(size: 14, weight: .bold))
                            Text("Logging this as a win.")
                                .font(.system(size: 12))
                        }
                        Spacer()
                    }
                    .foregroundColor(.black)
                    .padding(LockInTheme.Spacing.md)
                    .background(LockInTheme.Colors.accentGreen)
                    .cornerRadius(LockInTheme.Radius.md)
                }
                .buttonStyle(.plain)

                Button {
                    didResist = false
                    log?.hadRestaurantFood = true
                    log?.resistedLateNightOrder = false
                    try? modelContext.save()
                    advance()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I ORDERED. LOG THE FAILURE.")
                                .font(.system(size: 14, weight: .bold))
                            Text("At least track it honestly.")
                                .font(.system(size: 12))
                        }
                        Spacer()
                    }
                    .foregroundColor(LockInTheme.Colors.textPrimary)
                    .padding(LockInTheme.Spacing.md)
                    .background(LockInTheme.Colors.accentRed.opacity(0.15))
                    .cornerRadius(LockInTheme.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: LockInTheme.Radius.md)
                            .stroke(LockInTheme.Colors.accentRed.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Step 8: Outcome
    private var step_Outcome: some View {
        VStack(spacing: LockInTheme.Spacing.lg) {
            if didResist == true {
                VStack(spacing: LockInTheme.Spacing.md) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundColor(LockInTheme.Colors.accentGreen)
                    Text("You stayed on plan.")
                        .font(LockInTheme.Font.title(26))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("This is exactly what the cut requires. One win at a time.")
                        .font(LockInTheme.Font.label(14))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: LockInTheme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(LockInTheme.Colors.accentRed)
                    Text("You ordered.")
                        .font(LockInTheme.Font.title(26))
                        .foregroundColor(LockInTheme.Colors.textPrimary)
                    Text("Logged. Move on. Don't spiral. Tomorrow starts clean.")
                        .font(LockInTheme.Font.label(14))
                        .foregroundColor(LockInTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Text("Log it in MyNetDiary now. Honest tracking matters more than perfect eating.")
                        .font(.system(size: 12))
                        .foregroundColor(LockInTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await MyNetDiaryManager.shared.open(.logFood) }
                    } label: {
                        Text("Log in MyNetDiary")
                            .font(LockInTheme.Font.label(14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LockInTheme.Colors.accent)
                            .cornerRadius(LockInTheme.Radius.md)
                    }
                }
            }

            Button {
                isPresented = false
            } label: {
                Text("Done")
                    .font(LockInTheme.Font.label(15))
                    .foregroundColor(LockInTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LockInTheme.Colors.surface)
                    .cornerRadius(LockInTheme.Radius.md)
            }
        }
    }

    // MARK: - Navigation
    private func advance() {
        let all = InterveneStep.allCases
        guard let idx = all.firstIndex(of: currentStep), idx + 1 < all.count else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = all[idx + 1]
        }
    }

    // MARK: - Timer
    private func startTimer() {
        timerSeconds = 900
        timerActive = true
        timerComplete = false
        Task {
            await NotificationManager.shared.scheduleInterveneFollowUp(inMinutes: 15)
        }
    }

    private var timerProgress: Double {
        1.0 - Double(timerSeconds) / 900.0
    }

    private var timerColor: Color {
        let p = timerProgress
        if p < 0.5 { return LockInTheme.Colors.accentRed }
        if p < 0.75 { return LockInTheme.Colors.accentOrange }
        return LockInTheme.Colors.accentGreen
    }

    private var timerDisplayString: String {
        let m = timerSeconds / 60
        let s = timerSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func goalDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

// MARK: - Helper Views
struct StepHeader: View {
    let number: String
    let question: String
    let context: String

    var body: some View {
        VStack(alignment: .leading, spacing: LockInTheme.Spacing.sm) {
            Text("STEP \(number)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(LockInTheme.Colors.textTertiary)
                .tracking(2)
            Text(question)
                .font(LockInTheme.Font.title(22))
                .foregroundColor(LockInTheme.Colors.textPrimary)
            Text(context)
                .font(.system(size: 13))
                .foregroundColor(LockInTheme.Colors.textSecondary)
                .lineSpacing(4)
        }
    }
}

struct YesNoButtons: View {
    let yesLabel: String
    let noLabel: String
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        HStack(spacing: LockInTheme.Spacing.sm) {
            Button(action: onYes) {
                Text(yesLabel)
                    .font(LockInTheme.Font.label(14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LockInTheme.Colors.accentGreen)
                    .cornerRadius(LockInTheme.Radius.md)
            }
            Button(action: onNo) {
                Text(noLabel)
                    .font(LockInTheme.Font.label(14, weight: .semibold))
                    .foregroundColor(LockInTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LockInTheme.Colors.surface)
                    .cornerRadius(LockInTheme.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: LockInTheme.Radius.md)
                            .stroke(LockInTheme.Colors.border, lineWidth: 1)
                    )
            }
        }
    }
}

struct ContinueButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(LockInTheme.Font.label(14, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LockInTheme.Colors.accent)
                .cornerRadius(LockInTheme.Radius.md)
        }
    }
}

struct DamageRow: View {
    let label: String
    let orderVal: String
    let planVal: String

    var body: some View {
        HStack {
            Text(label)
                .font(LockInTheme.Font.label(12))
                .foregroundColor(LockInTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(orderVal)
                .font(LockInTheme.Font.mono(11, weight: .semibold))
                .foregroundColor(LockInTheme.Colors.accentRed)
                .frame(width: 120)
            Text(planVal)
                .font(LockInTheme.Font.mono(11, weight: .semibold))
                .foregroundColor(LockInTheme.Colors.accentGreen)
                .frame(width: 120)
        }
    }
}

#Preview {
    AntiBingeFlowView(isPresented: .constant(true), log: DataSeeder.sampleDailyLog())
        .modelContainer(for: [GoalProfile.self], inMemory: true)
}
