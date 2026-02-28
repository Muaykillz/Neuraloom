import UIKit

// MARK: - Playground Project

struct PlaygroundProject: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    var lastModifiedAt: Date
    var isDemo: Bool

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date(),
        isDemo: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.isDemo = isDemo
    }

    static let xorDemo = PlaygroundProject(
        name: "XOR Demo",
        isDemo: true
    )

    // MARK: - Preview Image Persistence

    private static var previewsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("playground_previews", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var previewImageURL: URL {
        Self.previewsDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }

    func loadPreviewImage() -> UIImage? {
        guard let data = try? Data(contentsOf: previewImageURL) else { return nil }
        return UIImage(data: data)
    }

    func savePreviewImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.6) else { return }
        try? data.write(to: previewImageURL)
    }

    func deletePreviewImage() {
        try? FileManager.default.removeItem(at: previewImageURL)
    }
}

// MARK: - Screen Capture

@MainActor
enum ScreenCapture {
    static func captureWindow() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else { return nil }

        // Scale down keeping original aspect ratio
        let scale: CGFloat = 0.5
        let thumbSize = CGSize(width: window.bounds.width * scale, height: window.bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: thumbSize)
        return renderer.image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: thumbSize), afterScreenUpdates: true)
        }
    }
}

// MARK: - Playground Store

class PlaygroundStore: ObservableObject {
    @Published var projects: [PlaygroundProject] = []

    private static let storageKey = "neuraloom_playgrounds"

    init() {
        load()
        seedDemoIfNeeded()
    }

    // MARK: - CRUD

    @discardableResult
    func create(name: String) -> PlaygroundProject {
        let project = PlaygroundProject(name: name)
        let insertIndex = projects.firstIndex(where: { !$0.isDemo }) ?? projects.count
        projects.insert(project, at: insertIndex)
        save()
        return project
    }

    func delete(id: UUID) {
        guard let project = projects.first(where: { $0.id == id }), !project.isDemo else { return }
        project.deletePreviewImage()
        projects.removeAll { $0.id == id }
        save()
    }

    func rename(id: UUID, to newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = newName
        projects[index].lastModifiedAt = Date()
        save()
    }

    func touch(id: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].lastModifiedAt = Date()
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([PlaygroundProject].self, from: data)
        else { return }
        projects = decoded
    }

    private func seedDemoIfNeeded() {
        if !projects.contains(where: { $0.isDemo }) {
            projects.insert(.xorDemo, at: 0)
            save()
        }
    }
}
