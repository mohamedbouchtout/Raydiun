import FoundationModels
import SwiftUI

struct CoachMark: View {
    let size: CGFloat

    var body: some View {
        Image("CoachMark").renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct CoachView: View {
    let store: PhoneWorkoutStore
    let openProgress: () -> Void
    @State private var archive = CoachArchive()
    @State private var chatID: UUID?

    private var report: String {
        if let error = store.loadError { return error }
        let calendar = Calendar.current
        let thisWeek = store.completed.filter {
            guard let end = $0.session.endedAt else { return false }
            return calendar.isDate(end, equalTo: .now, toGranularity: .weekOfYear)
        }
        let sets = thisWeek.flatMap(\.confirmedSets)
        return "This week you logged \(thisWeek.count) completed workouts, \(sets.count) confirmed sets, and \(sets.reduce(0) { $0 + $1.reps }) reps."
    }

    var body: some View {
        List {
            Section {
                Text(report)
                Button("View detailed progress", action: openProgress)
            } header: { Text("Training status").textCase(nil) }
            Section {
                Button("New chat", systemImage: "square.and.pencil") { chatID = UUID() }
                    .disabled(archive.loadFailed)
                if archive.loadFailed {
                    Text("Saved chats could not be loaded.")
                    Button("Retry loading chats") { archive.load() }
                }
                ForEach(archive.chats) { chat in
                    Button { chatID = chat.id } label: {
                        VStack(alignment: .leading) {
                            Text(chat.messages.first?.text ?? "Workout chat").lineLimit(2)
                            Text(chat.updated.formatted()).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("coach.chat.\(chat.id)")
                }
            } header: { Text("Conversations") }
        }
        .navigationTitle("Coach")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { CoachMark(size: 32) }
        }
        .onAppear { archive.load() }
        .navigationDestination(item: $chatID) { id in
            CoachConversation(id: id, archive: archive, report: report)
        }
    }
}

private struct CoachMessage: Identifiable, Codable {
    var id = UUID()
    let isQuestion: Bool
    let text: String
}

private struct CoachChat: Identifiable, Codable {
    let id: UUID
    var updated = Date()
    var messages: [CoachMessage] = []
}

@MainActor @Observable private final class CoachArchive {
    private let file = RaydiunStorage.directory.appending(path: "coach-chats-v1.json")
    private(set) var chats: [CoachChat] = []
    private(set) var loadFailed = false
    var busy = Set<UUID>()

    func load() {
        do {
            chats = try JSONDecoder().decode([CoachChat].self, from: Data(contentsOf: file))
            loadFailed = false
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            chats = []
            loadFailed = false
        } catch { loadFailed = true }
    }

    func append(_ messages: [CoachMessage], to id: UUID) throws {
        guard !loadFailed else { throw CocoaError(.fileReadUnknown) }
        var chat = chats.first { $0.id == id } ?? CoachChat(id: id)
        chat.messages.append(contentsOf: messages)
        chat.updated = Date()
        let updated = [chat] + chats.filter { $0.id != id }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: file, options: .atomic)
        chats = updated
    }
}

private struct CoachConversation: View {
    let id: UUID
    let archive: CoachArchive
    let report: String
    @State private var draft = ""
    @State private var failure: String?
    private var messages: [CoachMessage] { archive.chats.first { $0.id == id }?.messages ?? [] }

    private var available: Bool {
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        return false
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(messages) { message in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(message.isQuestion ? "You" : "Coach").font(.caption.bold())
                        Text(message.text).textSelection(.enabled)
                    }
                    .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).id(message.id)
                }
                if messages.isEmpty {
                    Button("Show my weekly report") {
                        do {
                            try archive.append([
                                CoachMessage(isQuestion: true, text: "Show my weekly report"),
                                CoachMessage(isQuestion: false, text: report)
                            ], to: id)
                        } catch { failure = "Couldn’t save the plan report. Try again." }
                    }
                    .buttonStyle(.bordered)
                }
                if archive.busy.contains(id) { ProgressView("Thinking…") }
                if let failure { Text(failure) }
                if !available {
                    Text("AI replies require an available Apple Intelligence model on this iPhone. Your saved conversations are available offline.")
                }
                if available, messages.last?.isQuestion == true, !archive.busy.contains(id) {
                    Button("Retry reply") { Task { await respond() } }
                }
            }.padding()
        }
        .defaultScrollAnchor(.bottom)
        .safeAreaInset(edge: .bottom) {
            HStack {
                TextField("Ask about your workout", text: $draft, axis: .vertical).lineLimit(1...4)
                Button("Send", systemImage: "arrow.up.circle.fill") {
                    let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    do {
                        try archive.append([CoachMessage(isQuestion: true, text: question)], to: id)
                        draft = ""
                        Task { await respond() }
                    } catch { failure = "Couldn’t save your question. Try again." }
                }
                .labelStyle(.iconOnly)
                .disabled(!available || archive.busy.contains(id) || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding().background(.bar)
        }
        .navigationTitle("Workout chat").navigationBarTitleDisplayMode(.inline)
    }

    @MainActor private func respond() async {
        guard #available(iOS 26.0, *), available, archive.busy.insert(id).inserted else { return }
        defer { archive.busy.remove(id) }
        failure = nil
        let conversation = messages.suffix(8).map { ($0.isQuestion ? "User: " : "Coach: ") + String($0.text.prefix(1400)) }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: "Answer workout-specific questions concisely. Treat plans as targets. Only use the supplied weekly totals for personal statistics. Never infer personal performance, muscle growth, or recovery from a plan.")
        do {
            let reply = try await session.respond(to: String(report.prefix(1800)) + "\n" + conversation)
            try archive.append([CoachMessage(isQuestion: false, text: reply.content)], to: id)
        } catch { failure = "Couldn’t finish or save this reply. Your question is saved." }
    }
}
