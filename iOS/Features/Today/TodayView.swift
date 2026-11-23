import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var weekMinimumWidth = 38.0
    @AppStorage(PhoneSchedule.storageKey) private var scheduleData = Data()
    @State private var library = ExerciseLibrary()
    @State private var templates: [WorkoutTemplate]?
    @State private var loadFailed = false
    @Binding var selectedDate: Date
    @State private var showingCalendar = false
    @State private var showingTemplates = false
    @State private var scheduleSaveFailed = false

    let openTrain: () -> Void
    let openLog: () -> Void
    let openSettings: () -> Void

    private var week: [Date] {
        PhoneSchedule.week(containing: selectedDate, calendar: calendar)
    }

    private var schedule: [String: UUID]? {
        PhoneSchedule.decode(scheduleData)
    }

    private var selectedTemplate: WorkoutTemplate? { template(on: selectedDate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                weekStrip
                workoutSection
                weekSummary
                logCard
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGroupedBackground),
                    colorScheme == .dark ? PhonePalette.ink : PhonePalette.mint
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Calendar", systemImage: "calendar") { showingCalendar = true }
                Button("Settings", systemImage: "person.crop.circle", action: openSettings)
                    .accessibilityIdentifier("today.settings")
            }
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingCalendar) {
            NavigationStack {
                Form {
                    DatePicker("Workout date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    Button("Go to Today") {
                        selectedDate = Date()
                        showingCalendar = false
                    }
                }
                .navigationTitle("Calendar")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingCalendar = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTemplates) {
            NavigationStack {
                List {
                    ForEach(templates ?? []) { template in
                        Button {
                            updateSchedule(with: template.id)
                            showingTemplates = false
                        } label: {
                            Label(template.name, systemImage: "dumbbell")
                        }
                    }
                    if schedule?[dateKey(selectedDate)] != nil {
                        Button("Remove Scheduled Workout", role: .destructive) {
                            updateSchedule(with: nil)
                            showingTemplates = false
                        }
                    }
                }
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
    }

    private var weekStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(week, id: \.self) { day in
                    let selected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let planned = template(on: day) != nil
                    Button {
                        selectedDate = day
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption2)
                            Text(day.formatted(.dateTime.day()))
                                .font(.subheadline.weight(.semibold))
                            Capsule()
                                .fill(planned ? Color.accentColor : Color.clear)
                                .frame(width: 5, height: 3)
                        }
                        .frame(minWidth: weekMinimumWidth, minHeight: 48)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? PhonePalette.forest : PhonePalette.mint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                    .accessibilityValue(planned ? "Workout planned" : "No workout planned")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

        }
        .scrollIndicators(.hidden)
        .padding(6)
        .accessibilityIdentifier("today.weekStrip")
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your workout")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                if loadFailed || schedule == nil {
                    Text("Your plan couldn’t load").font(.title2.bold())
                    if loadFailed {
                        Button("Try Again", action: reload)
                            .buttonStyle(.bordered)
                    }
                } else if let template = selectedTemplate {
                    Text(template.goal.rawValue.uppercased())
                        .font(.caption.weight(.semibold))
                    Text(template.name)
                        .font(.title2.bold())

                    ForEach(template.exercises.sorted { $0.position < $1.position }) { entry in
                        LabeledContent {
                            Text("\(entry.targetSets) sets")
                                .font(.subheadline.monospacedDigit())
                        } label: {
                            Text(library.name(for: entry.exerciseId))
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    Button("Change Plan", systemImage: "calendar") { showingTemplates = true }
                        .buttonStyle(.borderedProminent)
                        .tint(PhonePalette.forest)
                        .foregroundStyle(.white)
                } else if let templates {
                    let removed = schedule?[dateKey(selectedDate)] != nil
                    Text(removed ? "Template unavailable" :
                        templates.isEmpty ? "Your first workout" : "No workout planned")
                        .font(.title2.bold())
                    Text(removed ? "Choose another template for this day." :
                        templates.isEmpty ? "Build a workout around your goals and choose the exercises you want to train." :
                        "Pick a saved template for this day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(templates.isEmpty ? "Set Up My Plan" : "Plan a Workout",
                           systemImage: "chevron.right") {
                        if templates.isEmpty { openTrain() } else { showingTemplates = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PhonePalette.forest)
                    .foregroundStyle(.white)

                    if removed && templates.isEmpty {
                        Button("Remove Scheduled Workout", role: .destructive) {
                            updateSchedule(with: nil)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ProgressView("Loading your plan")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: PhonePalette.cardColors(for: colorScheme),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }

            if let templates, !templates.isEmpty {
                Button(action: openTrain) {
                    Label("Workout Templates", systemImage: "list.bullet.clipboard")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .background {
                    if reduceTransparency {
                        Capsule().fill(Color(uiColor: .secondarySystemGroupedBackground))
                    } else if #available(iOS 26, *) {
                        Capsule().fill(.clear)
                    } else {
                        Capsule().fill(.regularMaterial)
                    }
                }
                .modifier(PhoneGlassControl(enabled: !reduceTransparency))
            }
        }
    }

    private var weekSummary: some View {
        let planned = week.filter { template(on: $0) != nil }.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("This week").font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                Text("\(planned) planned workouts")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    ForEach(week, id: \.self) { day in
                        Capsule()
                            .fill(template(on: day) == nil ? Color.secondary.opacity(0.25) : Color.accentColor)
                            .frame(height: 4)
                    }
                }
                .accessibilityHidden(true)

                if let first = week.first, let last = week.last {
                    Text("\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .accessibilityElement(children: .combine)
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your training log").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("Your first saved workout will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("View Training Log", action: openLog)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func template(on day: Date) -> WorkoutTemplate? {
        guard let id = schedule?[dateKey(day)] else { return nil }
        return templates?.first { $0.id == id }
    }

    private func dateKey(_ date: Date) -> String {
        PhoneSchedule.key(for: date, calendar: calendar)
    }

    private func updateSchedule(with id: UUID?) {
        guard var updated = schedule else {
            scheduleSaveFailed = true
            return
        }
        updated[dateKey(selectedDate)] = id
        do {
            scheduleData = try JSONEncoder().encode(updated)
        } catch {
            scheduleSaveFailed = true
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

private struct PhoneGlassControl: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *), enabled {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
        }
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

enum PhonePalette {
    static let forest = Color(red: 0.07, green: 0.23, blue: 0.20)
    static let ink = Color(red: 0.09, green: 0.14, blue: 0.12)
    static let mint = Color(red: 0.89, green: 0.93, blue: 0.90)
    static let mintAccent = Color(red: 0.68, green: 0.80, blue: 0.73)

    static func cardColors(for colorScheme: ColorScheme) -> [Color] {
        colorScheme == .dark ? [ink, forest] : [mint, mintAccent]
    }
}
