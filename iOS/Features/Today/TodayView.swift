import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 49.0
    @AppStorage(PhoneSchedule.storageKey) private var scheduleData = Data()
    @State private var library = ExerciseLibrary()
    @State private var templates: [WorkoutTemplate]?
    @State private var loadFailed = false
    @State private var showingTemplates = false
    @State private var scheduleSaveFailed = false
    @State private var showingWatchStatus = false
    @Binding var selectedDate: Date

    let isVisible: Bool
    let store: PhoneWorkoutStore
    let setup: TrainingSetupStore
    let dismissWalkthrough: () -> Void
    let openTrainingSetup: () -> Void
    let openWorkout: (UUID?) -> Void
    let openProfile: () -> Void

    private var schedule: [String: UUID]? { PhoneSchedule.decode(scheduleData) }
    private var week: [Date] { PhoneSchedule.week(containing: selectedDate, calendar: calendar) }
    private var selectedTemplate: WorkoutTemplate? { template(on: selectedDate) }
    private var history: HomeTrainingHistory { HomeTrainingHistory(store: store, calendar: calendar) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                    .padding(.bottom, 9)
                hero
                if [.start, .logSet, .finish, .viewLog].contains(setup.walkthrough) {
                    FirstWorkoutGuide(step: setup.walkthrough, onDismiss: dismissWalkthrough)
                }
                weekCard
                planCard
                TimelineView(.everyMinute) { _ in
                    stats(now: .now)
                }
                Button(store.active == nil ? "Start Workout" : "Resume Workout") {
                    openWorkout(selectedTemplate?.id)
                }
                .buttonStyle(RaydiunPrimaryButton())
                .accessibilityLabel(store.active == nil ? "Start Workout" : "Resume Workout")
                .accessibilityIdentifier("today.workout")
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
        }
        .background {
            ZStack(alignment: .topTrailing) {
                PhonePalette.canvas
                RadialGradient(colors: [PhonePalette.glow, PhonePalette.canvas.opacity(0)],
                               center: .init(x: 0.8, y: 0.12), startRadius: 0, endRadius: 260)
                    .frame(height: 340)
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { if isVisible { reload() } }
        .onChange(of: setup.revision) { _, _ in reload() }
        .onChange(of: isVisible) { _, visible in if visible { reload() } }
        .sheet(isPresented: $showingTemplates, onDismiss: reload) {
            NavigationStack {
                List {
                    ForEach(templates ?? []) { template in
                        Button(template.name) {
                            if updateSchedule(with: template.id) { showingTemplates = false }
                        }
                        .listRowBackground(PhonePalette.surface)
                    }
                    if plannedID(on: selectedDate) != nil {
                        Button("Skip This Date", role: .destructive) {
                            if updateSchedule(with: nil) { showingTemplates = false }
                        }
                        .listRowBackground(PhonePalette.surface)
                    }
                }
                .raydiunScreen()
                .navigationTitle("Plan Workout")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingTemplates = false }
                    }
                }
            }
        }
        .alert("Couldn’t update the schedule", isPresented: $scheduleSaveFailed) {
            Button("OK", role: .cancel) {}
        }
        .alert("Watch status unavailable", isPresented: $showingWatchStatus) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Raydiun currently logs workouts manually on iPhone. Watch connection status is unavailable.")
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack { wordmark; Spacer(minLength: 12); headerActions }
            VStack(alignment: .leading, spacing: 8) { wordmark; headerActions }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            watchButton
            Button(action: openProfile) {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
            .accessibilityIdentifier("today.profile")
        }
    }

    private var wordmark: some View {
        HStack(spacing: 10) {
            CoachMark(size: 27)
                .foregroundStyle(PhonePalette.brandMark)
            Text("raydiun").font(.title2.weight(.medium))
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var watchButton: some View {
        Button {
            showingWatchStatus = true
        } label: {
            HStack(spacing: 7) {
                Circle().fill(PhonePalette.muted).frame(width: 7, height: 7)
                Text("Watch").font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(PhonePalette.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(PhonePalette.line) }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Watch status")
        .accessibilityValue("Unavailable")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(selectedDate.formatted(.dateTime.weekday(.wide))) · \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))")
                .font(.caption.weight(.semibold))
                .tracking(1.7)
                .textCase(.uppercase)
                .foregroundStyle(PhonePalette.muted)
            Text(selectedTemplate?.name ?? emptyTitle)
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            if let selectedTemplate {
                let count = selectedTemplate.exercises.count
                ViewThatFits(in: .horizontal) {
                    HStack {
                        exerciseCount(count)
                        Spacer(minLength: 8)
                        changePlan
                    }
                    VStack(alignment: .leading) {
                        exerciseCount(count)
                        changePlan
                    }
                }
            }
        }
    }

    private func exerciseCount(_ count: Int) -> some View {
        Text(count == 1 ? "1 exercise" : "\(count) exercises")
            .font(.body)
            .foregroundStyle(PhonePalette.muted)
    }

    private var changePlan: some View {
        Button { showingTemplates = true } label: {
            Image(systemName: "calendar.badge.clock")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(PhonePalette.action)
        .accessibilityLabel("Change Plan")
    }

    private var emptyTitle: String {
        if loadFailed || schedule == nil { return "Your plan couldn’t load" }
        if templates == nil { return "Today" }
        if plannedID(on: selectedDate) != nil { return "Template unavailable" }
        return templates?.isEmpty == true ? "Your first workout" : "No workout planned"
    }

    private var weekCard: some View {
        let dates = week
        let scheduled = dates.filter { template(on: $0) != nil }
        let finished = history.finished(in: dates)
        let finishedPlans = scheduled.filter { day in
            history.finished(on: day).contains { $0.session.templateId == template(on: day)?.id }
        }.count
        return VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack { weekTitle; Spacer(minLength: 8); weekTotals(finished.count, scheduled.count, finishedPlans) }
                VStack(alignment: .leading, spacing: 4) {
                    weekTitle
                    weekTotals(finished.count, scheduled.count, finishedPlans)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) { dayButtons(dates) }
                ScrollView(.horizontal) {
                    HStack(spacing: 4) { dayButtons(dates) }
                }
                .scrollIndicators(.hidden)
            }
            .accessibilityIdentifier("today.weekStrip")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .raydiunCard()
    }

    private var weekTitle: some View {
        Text(calendar.isDate(selectedDate, equalTo: .now, toGranularity: .weekOfYear) ? "This week" : "Selected week")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private func weekTotals(_ finished: Int, _ planned: Int, _ fulfilled: Int) -> some View {
        Group {
            if store.loadError != nil {
                Text("History unavailable")
            } else if loadFailed || schedule == nil || templates == nil || planned == 0 {
                Text("\(finished) finished")
            } else if finished == fulfilled {
                Text("**\(fulfilled)** of \(planned) sessions")
            } else {
                Text("\(finished) finished · \(fulfilled) of \(planned) planned")
            }
        }
        .font(.subheadline)
        .foregroundStyle(PhonePalette.muted)
    }

    private func dayButtons(_ dates: [Date]) -> some View {
        ForEach(dates, id: \.self) { day in
            let selected = calendar.isDate(day, inSameDayAs: selectedDate)
            let completed = !history.finished(on: day).isEmpty
            let planned = template(on: day) != nil
            Button {
                selectedDate = day
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        if selected {
                            Circle().strokeBorder(PhonePalette.action, lineWidth: 2)
                        } else if completed {
                            Circle().fill(PhonePalette.action)
                        } else if planned {
                            Circle().strokeBorder(PhonePalette.muted, style: StrokeStyle(lineWidth: 1.4, dash: [3, 2]))
                        } else {
                            Circle().fill(PhonePalette.quietFill)
                        }
                        if completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(selected ? PhonePalette.action : PhonePalette.onAction)
                        } else if selected {
                            Circle().fill(PhonePalette.action).frame(width: 10, height: 10)
                        }
                    }
                    .frame(width: 34, height: 34)
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? PhonePalette.ink : PhonePalette.muted)
                }
                .frame(minWidth: 44, maxWidth: .infinity, minHeight: 51)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            .accessibilityValue(completed ? "Workout completed" : planned ? "Workout planned" : "No completed or planned workout")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    @ViewBuilder private var planCard: some View {
        if let template = selectedTemplate, !loadFailed {
            let rows = template.exercises.sorted { $0.position < $1.position }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Rectangle().fill(PhonePalette.line).frame(height: 1) }
                    exerciseRow(index + 1, entry)
                }
                if rows.isEmpty {
                    Text("This template has no exercises.").padding(14)
                }
            }
            .raydiunCard()
        } else {
            VStack(alignment: .leading, spacing: 7) {
                if loadFailed {
                    Button("Try Again", action: reload)
                } else if schedule == nil {
                    Text("The saved schedule couldn’t be read.").foregroundStyle(PhonePalette.muted)
                } else if let templates {
                    Text(templates.isEmpty ? "Build a workout around your goals." : "Choose a saved template for this day.")
                        .foregroundStyle(PhonePalette.muted)
                    Button(templates.isEmpty ? "Set Up My Plan" : "Plan a Workout") {
                        if templates.isEmpty { openTrainingSetup() } else { showingTemplates = true }
                    }
                    if templates.isEmpty && plannedID(on: selectedDate) != nil {
                        Button("Remove Scheduled Workout", role: .destructive) { updateSchedule(with: nil) }
                    }
                } else {
                    ProgressView("Loading your plan")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .raydiunCard()
        }
    }

    private func exerciseRow(_ number: Int, _ entry: TemplateExercise) -> some View {
        let reps = entry.repMin == entry.repMax ? "\(entry.repMin)" : "\(entry.repMin)–\(entry.repMax)"
        let load = history.lastLoad(for: entry.exerciseId)
        return HStack(alignment: .top, spacing: 12) {
            Text(number.formatted())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PhonePalette.action)
                .padding(8)
                .frame(minWidth: 40, minHeight: 40)
                .background(PhonePalette.badge, in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(library.name(for: entry.exerciseId)).font(.body.weight(.medium))
                Text("\(entry.targetSets) × \(reps) reps")
                    .font(.subheadline).foregroundStyle(PhonePalette.muted)
                if textSize.isAccessibilitySize, let load { loadLabel(load, unit: entry.preferredWeightUnit, alignment: .leading) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !textSize.isAccessibilitySize, let load { loadLabel(load, unit: entry.preferredWeightUnit, alignment: .trailing) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func loadLabel(_ load: WorkoutWeight, unit: WeightUnit, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text("\(load.value(in: unit).formatted(.number.precision(.fractionLength(0...2)))) \(unit.rawValue)")
                .font(.body.weight(.semibold))
            Text("Last load").font(.caption).foregroundStyle(PhonePalette.muted)
        }
    }

    private func stats(now: Date) -> some View {
        let totals = history.currentStats(now: now)
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            stat("Streak", totals.map { $0.streak.formatted() }, detail: totals.map { $0.streak == 1 ? "week" : "weeks" })
            stat("Reps this week", totals.map { $0.reps.formatted() },
                 detail: totals?.change.map { $0.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())) },
                 highlightDetail: true)
        }
    }

    private func stat(_ title: String, _ value: String?, detail: String?, highlightDetail: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(1.1).foregroundStyle(PhonePalette.muted)
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value).font(.title.weight(.semibold)).monospacedDigit()
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(highlightDetail ? PhonePalette.action : PhonePalette.muted)
                    }
                }
            } else {
                Text("Unavailable").font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .raydiunCard(radius: 18)
        .accessibilityElement(children: .combine)
    }

    private func template(on day: Date) -> WorkoutTemplate? {
        guard let id = plannedID(on: day) else { return nil }
        return templates?.first { $0.id == id }
    }

    private func plannedID(on day: Date) -> UUID? {
        guard let schedule else { return nil }
        return schedule[dateKey(day)] ?? setup.recurringTemplate(on: day, calendar: calendar)
    }

    private func dateKey(_ date: Date) -> String {
        PhoneSchedule.key(for: date, calendar: calendar)
    }

    @discardableResult
    private func updateSchedule(with id: UUID?) -> Bool {
        guard var updated = schedule else {
            scheduleSaveFailed = true
            return false
        }
        updated[dateKey(selectedDate)] = id
        do {
            let data = try JSONEncoder().encode(updated)
            if id == nil { try setup.skip(selectedDate, calendar: calendar) }
            scheduleData = data
            return true
        } catch {
            scheduleSaveFailed = true
            return false
        }
    }

    private func reload() {
        do {
            templates = try WorkoutTemplateStore.local.load()
            library.load()
            loadFailed = false
        } catch {
            templates = nil
            loadFailed = true
        }
    }
}


@MainActor
private struct HomeTrainingHistory {
    let store: PhoneWorkoutStore
    let calendar: Calendar

    private var completed: [PhoneWorkoutSummary] {
        store.completed.filter { !$0.confirmedSets.isEmpty }
    }

    func finished(in days: [Date]) -> [PhoneWorkoutSummary] {
        completed.filter { workout in
            guard let end = workout.session.endedAt else { return false }
            return days.contains { calendar.isDate(end, inSameDayAs: $0) }
        }
    }

    func finished(on date: Date) -> [PhoneWorkoutSummary] { finished(in: [date]) }

    func lastLoad(for exerciseID: UUID) -> WorkoutWeight? {
        completed
            .flatMap { workout in
                workout.exercises.filter { $0.performance.exerciseId == exerciseID }.flatMap { exercise in
                    exercise.sets.compactMap { set -> (date: Date, weight: WorkoutWeight)? in
                        guard set.confirmed, let weight = set.weight else { return nil }
                        return (set.endedAt ?? workout.session.endedAt ?? workout.session.startedAt, weight)
                    }
                }
            }
            .max { $0.date < $1.date }?.weight
    }

    func currentStats(now: Date) -> (streak: Int, reps: Int, change: Double?)? {
        guard store.loadError == nil,
              let week = calendar.dateInterval(of: .weekOfYear, for: now),
              let previousDay = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
              let previous = calendar.dateInterval(of: .weekOfYear, for: previousDay),
              let cutoff = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: previousDay))
        else { return nil }
        let workouts = completed
        let entries = workouts.compactMap { workout -> (end: Date, reps: Int)? in
            guard let end = workout.session.endedAt, end <= now else { return nil }
            return (end, workout.confirmedSets.reduce(0) { $0 + $1.reps })
        }
        let current = entries.filter { $0.end >= week.start }.reduce(0) { $0 + $1.reps }
        let baseline = entries.filter { $0.end >= previous.start && $0.end < cutoff }.reduce(0) { $0 + $1.reps }
        let activeWeeks = Set(entries.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.end)?.start })
        var streak = 0
        var cursor = activeWeeks.contains(week.start) ? week.start : previous.start
        while activeWeeks.contains(cursor) {
            streak += 1
            guard let prior = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor),
                  let start = calendar.dateInterval(of: .weekOfYear, for: prior)?.start
            else { break }
            cursor = start
        }
        return (streak, current, baseline > 0 ? Double(current - baseline) / Double(baseline) : nil)
    }
}

enum PhoneSchedule {
    static var storageKey: String {
        #if DEBUG && targetEnvironment(simulator)
        if let testID = ProcessInfo.processInfo.environment["RAYDIUN_UI_TEST_STORE"],
           let uuid = UUID(uuidString: testID) {
            return "raydiun.phone.schedule.v1.\(uuid.uuidString)"
        }
        #endif
        return "raydiun.phone.schedule.v1"
    }

    static func decode(_ data: Data) -> [String: UUID]? {
        if data.isEmpty { return [:] }
        return try? JSONDecoder().decode([String: UUID].self, from: data)
    }

    static func week(containing date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let day = gregorian.dateComponents([.year, .month, .day], from: date)
        return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }
}
