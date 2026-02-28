import SwiftUI

struct StoryChapter: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let isLocked: Bool

    init(id: Int, title: String, subtitle: String, icon: String, isLocked: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isLocked = isLocked
    }

    static let all: [StoryChapter] = [
        StoryChapter(id: 1, title: "Hello, Neuron", subtitle: "Play with the basic building block that makes AI work.", icon: "hand.wave.fill"),
        StoryChapter(id: 2, title: "The Art of Learning", subtitle: "Teach your neuron to spot errors and fix them, one step at a time.", icon: "lightbulb.fill"),
        StoryChapter(id: 3, title: "Your First AI", subtitle: "Make real predictions, draw the line, and see what happens next!", icon: "sparkles"),
        StoryChapter(id: 4, title: "Coming Soon...", subtitle: "Win Swift Student Challenge 2026 to unlock!", icon: "lock.fill", isLocked: true),
    ]
}

class StoryProgressManager: ObservableObject {
    @Published var completedChapters: Set<Int> {
        didSet { save() }
    }

    private let storageKey = "completedStoryChapters"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            completedChapters = decoded
        } else {
            completedChapters = []
        }
    }

    func toggleCompleted(_ chapterID: Int) {
        if completedChapters.contains(chapterID) {
            completedChapters.remove(chapterID)
        } else {
            completedChapters.insert(chapterID)
        }
    }

    func isCompleted(_ chapterID: Int) -> Bool {
        completedChapters.contains(chapterID)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(completedChapters) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
