import Foundation

enum ChapterContent {
    static let chapter1Cutscene: [CutscenePage] = [
        // 1. Face ID
        CutscenePage(
            imageName: "apple-face-id-icon",
            lines: [
                [CutsceneSpan(text: "Your phone")],
                [CutsceneSpan(text: "knows ", italic: true),
                 CutsceneSpan(text: "your face.", bold: true)],
            ]
        ),
        // 2. AlphaGo
        CutscenePage(
            imageName: "alphago-intro",
            lines: [
                [CutsceneSpan(text: "A computer beat")],
                [CutsceneSpan(text: "the world's best")],
                [CutsceneSpan(text: "Go ", bold: true, accent: true),
                 CutsceneSpan(text: "player.")],
            ]
        ),
        // 3. AI wrote this — typewriter effect
        CutscenePage(
            sfSymbol: "text.cursor",
            lines: [
                [CutsceneSpan(text: "A machine")],
                [CutsceneSpan(text: "wrote ", italic: true),
                 CutsceneSpan(text: "this sentence.")],
            ],
            typewriterLine: "Hello, I am an artificial mind."
        ),
        // 4. Behind all of this?
        CutscenePage(
            lines: [
                [CutsceneSpan(text: "Behind")],
                [CutsceneSpan(text: "all ", bold: true),
                 CutsceneSpan(text: "of this?")],
            ]
        ),
        // 5. Mimicking human neurons
        CutscenePage(
            sfSymbol: "brain.head.profile",
            lines: [
                [CutsceneSpan(text: "The foundation")],
                [CutsceneSpan(text: "behind everything")],
                [CutsceneSpan(text: "is the mimicking of")],
                [CutsceneSpan(text: "human ", bold: true, accent: true),
                 CutsceneSpan(text: "neurons.", bold: true)],
            ]
        ),
        // 6. The Perceptron
        CutscenePage(
            imageName: "NN2ANN",
            lines: [
                [CutsceneSpan(text: "Which we call")],
                [CutsceneSpan(text: "the "),
                 CutsceneSpan(text: "\"Perceptron\"", bold: true, italic: true, accent: true)],
            ],
            buttonLabel: "Let's explore"
        ),
    ]

    // MARK: - Tour Steps

    static let chapter1Tour: [TourStep] = [
        TourStep(
            title: "Welcome to the Playground",
            body: "This is where you'll build and experiment with neurons. Let's start by exploring what's on the canvas."
        ),
        TourStep(
            title: "Meet the Neuron",
            body: "The circle in the center is a neuron — the basic building block of every neural network. It takes inputs, processes them, and produces an output."
        ),
        TourStep(
            title: "Your Turn!",
            body: "Try tapping on the neuron to see its properties. When you're ready, press Done to continue."
        ),
    ]
}
