import Foundation

// MARK: - Deterministic IDs for Chapter 3

enum Chapter3IDs {
    static let dataset = UUID(uuidString: "C3000000-0000-0000-0000-000000000001")!
    static let dsPortX = UUID(uuidString: "C3000000-0000-0000-0000-000000000002")!
    static let dsPortY = UUID(uuidString: "C3000000-0000-0000-0000-000000000003")!
}

// MARK: - Deterministic IDs for Chapter 2

enum Chapter2IDs {
    static let dataset    = UUID(uuidString: "C2000000-0000-0000-0000-000000000001")!
    static let inputX1    = UUID(uuidString: "C2000000-0000-0000-0000-000000000002")!
    static let bias1      = UUID(uuidString: "C2000000-0000-0000-0000-000000000003")!
    static let neuronOut  = UUID(uuidString: "C2000000-0000-0000-0000-000000000004")!
    static let weightW    = UUID(uuidString: "C2000000-0000-0000-0000-000000000005")!
    static let weightB    = UUID(uuidString: "C2000000-0000-0000-0000-000000000006")!
    static let loss1      = UUID(uuidString: "C2000000-0000-0000-0000-000000000007")!
    static let viz1       = UUID(uuidString: "C2000000-0000-0000-0000-000000000008")!
    // Dataset column ports (linear: X, Y)
    static let dsPortX    = UUID(uuidString: "C2000000-0000-0000-0000-000000000009")!
    static let dsPortY    = UUID(uuidString: "C2000000-0000-0000-0000-00000000000A")!
    // Loss ports
    static let lossPred   = UUID(uuidString: "C2000000-0000-0000-0000-00000000000B")!
    static let lossTrue   = UUID(uuidString: "C2000000-0000-0000-0000-00000000000C")!
}

// MARK: - Deterministic IDs for Chapter 1

enum Chapter1IDs {
    static let inputX1   = UUID(uuidString: "C1000000-0000-0000-0000-000000000001")!
    static let bias1     = UUID(uuidString: "C1000000-0000-0000-0000-000000000002")!
    static let neuronOut = UUID(uuidString: "C1000000-0000-0000-0000-000000000003")!
    static let weightW   = UUID(uuidString: "C1000000-0000-0000-0000-000000000004")!
    static let weightB   = UUID(uuidString: "C1000000-0000-0000-0000-000000000005")!
    static let numberIn  = UUID(uuidString: "C1000000-0000-0000-0000-000000000006")!
}

// MARK: - Chapter Content

enum ChapterContent {

    // MARK: - Chapter 1 Cutscene

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

    // MARK: - Chapter 1 Tour

    static let chapter1Tour: [TourStep] = {
        let ids = Chapter1IDs.self
        return [
            // STEP 1 — Orient
            TourStep(
                title: "Welcome to the Playground",
                body: [
                    [TourSpan(text: "This is your space to build and experiment.")],
                    [TourSpan(text: "Don't worry — "),
                     TourSpan(text: "everything can be reset.", bold: true)],
                    [TourSpan(text: "Let's look at what's on the canvas.")]
                ],
                onEnter: { vm in
                    vm.storyHideExitInference = true
                    vm.storyHideInferencePanel = true
                    vm.inferenceAnimationScale = 2.5
                }
            ),

            // STEP 2 — Introduce the neuron (transition from Perceptron)
            TourStep(
                title: "Meet the Neuron",
                body: [
                    [TourSpan(text: "This "),
                     TourSpan(text: "orange circle", bold: true, accent: true),
                     TourSpan(text: " is a "),
                     TourSpan(text: "Perceptron", bold: true, italic: true, accent: true),
                     TourSpan(text: " — more commonly called a "),
                     TourSpan(text: "Neuron.", bold: true, accent: true)],
                    [TourSpan(text: "It takes numbers in, computes, and sends a number out.")]
                ],
                highlightTarget: .node(id: ids.neuronOut)
            ),

            // STEP 3 — Introduce input
            TourStep(
                title: "Inputs Feed the Neuron",
                body: [
                    [TourSpan(text: "The Neuron on the left is an "),
                     TourSpan(text: "input", bold: true, accent: true),
                     TourSpan(text: " — it holds a number you control.")],
                    [TourSpan(text: "The line going "),
                     TourSpan(text: "right", bold: true),
                     TourSpan(text: " to the Neuron is a "),
                     TourSpan(text: "weight", bold: true, accent: true),
                     TourSpan(text: " — it decides how important this input is.")]
                ],
                highlightTarget: .node(id: ids.inputX1)
            ),

            // STEP 4 — Acknowledge bias
            TourStep(
                title: "And This One...",
                body: [
                    [TourSpan(text: "This other Neuron is called "),
                     TourSpan(text: "bias", bold: true, accent: true),
                     TourSpan(text: " — it always outputs "),
                     TourSpan(text: "1.0", mono: true)],
                    [TourSpan(text: "We'll explain why it's here later. For now, just know it exists.")]
                ],
                highlightTarget: .node(id: ids.bias1)
            ),

            // STEP 5 — Press Predict (reveals inference panel)
            TourStep(
                title: "Try Pressing Predict",
                body: [
                    [TourSpan(text: "Press "),
                     TourSpan(text: "Predict", bold: true, accent: true),
                     TourSpan(text: " to send numbers through the Neuron.")],
                    [TourSpan(text: "Watch the signal flow layer by layer.")]
                ],
                completionCondition: .custom(id: "predicted"),
                onEnter: { vm in
                    vm.storyHideInferencePanel = false
                }
            ),

            // STEP 6 — How Neuron predicts a number
            TourStep(
                title: "How the Neuron Predicts",
                body: [
                    [TourSpan(text: "What just happened is called a "),
                     TourSpan(text: "Forward Pass", bold: true, accent: true),
                     TourSpan(text: " — sending data through the Neuron to get a result.")],
                    [TourSpan(text: "The formula is "),
                     TourSpan(text: "z = w·x + b", bold: true, mono: true),
                     TourSpan(text: " — multiply each input by its weight, then add them up.")],
                    [TourSpan(text: "Try tapping the boxed values on the canvas to see where each number comes from.", italic: true)]
                ],
                highlightTarget: .node(id: ids.neuronOut)
            ),

            // STEP 7 — Change weight with auto-predict
            TourStep(
                title: "Change a Weight",
                body: [
                    [TourSpan(text: "Tap the weight line and drag the slider.")],
                    [TourSpan(text: "Change the value — the output updates "),
                     TourSpan(text: "instantly.", bold: true, accent: true)]
                ],
                completionCondition: .weightChanged(connectionId: ids.weightW),
                highlightTarget: .weight(id: ids.weightW),
                onEnter: { vm in
                    vm.autoPredict = true
                }
            ),

            // STEP 8 — Congratulate & tee up next chapter
            TourStep(
                title: "You Just Understood Forward Pass!",
                body: [
                    [TourSpan(text: "Amazing! ", bold: true, accent: true),
                     TourSpan(text: "Now you know how a Neuron computes its output.")],
                    [TourSpan(text: "But we're still adjusting the weights by hand...")],
                    [TourSpan(text: "Next up: teach the Neuron to "),
                     TourSpan(text: "find the right weights on its own.", bold: true)]
                ],
                buttonLabel: "On to Chapter 2 →"
            ),
        ]
    }()

    // MARK: - Chapter 2 Cutscene

    static let chapter2Cutscene: [CutscenePage] = [

        // 1. The Problem with Guessing
        CutscenePage(
            sfSymbol: "questionmark.circle",
            lines: [
                [CutsceneSpan(text: "A good Weight ")],
                [CutsceneSpan(text: "produces a ", italic: true),
                 CutsceneSpan(text: "good result.", bold: true)],
                [CutsceneSpan(text: "But how do we know")],
                [CutsceneSpan(text: "which Weight ", bold: true, accent: true),
                 CutsceneSpan(text: "is \"good\"?")],
            ]
        ),

        // 2. Learning from Mistakes
        CutscenePage(
            sfSymbol: "arrow.triangle.2.circlepath",
            lines: [
                [CutsceneSpan(text: "Humans learn from ")],
                [CutsceneSpan(text: "mistakes.", bold: true, accent: true)],
                [CutsceneSpan(text: "Neural Networks ")],
                [CutsceneSpan(text: "do the same.")],
            ]
        ),

        // 3. Less Error, More Skill
        CutscenePage(
            sfSymbol: "chart.line.downtrend.xyaxis",
            lines: [
                [CutsceneSpan(text: "The less "),
                 CutsceneSpan(text: "error", bold: true, accent: true),
                 CutsceneSpan(text: " it makes,")],
                [CutsceneSpan(text: "the "),
                 CutsceneSpan(text: "smarter", bold: true),
                 CutsceneSpan(text: " it gets.")],
                [CutsceneSpan(text: "We will teach the Neuron to adjust itself")],
                [CutsceneSpan(text: "until the error is "),
                 CutsceneSpan(text: "minimized.", bold: true)],
            ],
            buttonLabel: "Start"
        ),
    ]

    // MARK: - Chapter 2 Tour

    static let chapter2Tour: [TourStep] = {
        let ids = Chapter2IDs.self
        return [

            // STEP 1 — Introduce dataset
            TourStep(
                title: "Data to Learn From",
                body: [
                    [TourSpan(text: "This blue box is the "),
                     TourSpan(text: "Dataset", bold: true, color: .blue),
                     TourSpan(text: " — sample data we'll use to teach the Neuron.")],
                    [TourSpan(text: "Each row has an "),
                     TourSpan(text: "input X", bold: true),
                     TourSpan(text: " and the correct "),
                     TourSpan(text: "output Y", bold: true),
                     TourSpan(text: ".")],
                    [TourSpan(text: "Goal: Make the Neuron accurately predict Y from an unseen X.", italic: true)]
                ],
                highlightTarget: .node(id: ids.dataset),
                onEnter: { vm in
                    vm.storyExpandTrainingPanel = true
                    vm.storyHideExitInference = true
                    vm.zoomToNode(id: ids.dataset, zoomScale: 1.4, verticalBias: 80)
                }
            ),

            // STEP 2 — Introduce Loss node (outline only, no popover)
            TourStep(
                title: "Measuring Error with Loss",
                body: [
                    [TourSpan(text: "If the Neuron predicts "),
                     TourSpan(text: "3.0", mono: true),
                     TourSpan(text: " but the real answer is "),
                     TourSpan(text: "7.0", mono: true),
                     TourSpan(text: " — how wrong is it?")],
                    [TourSpan(text: "This red node is "),
                     TourSpan(text: "Loss", bold: true, color: .red),
                     TourSpan(text: " — it takes both the "),
                     TourSpan(text: "predicted value", bold: true),
                     TourSpan(text: " and the "),
                     TourSpan(text: "actual answer", bold: true),
                     TourSpan(text: ", and calculates the error as a number.")],
                    [TourSpan(text: "Higher Loss means more error. Lower Loss means higher accuracy.", italic: true)]
                ],
                highlightTarget: .glowNodes(ids: [ids.loss1]),
                onEnter: { vm in
                    vm.fitToScreenStored()
                }
            ),

            // STEP 3 — Open popover to see Loss formula
            TourStep(
                title: "How is Loss calculated?",
                body: [
                    [TourSpan(text: "We use "),
                     TourSpan(text: "MSE", bold: true, mono: true),
                     TourSpan(text: " (Mean Squared Error):")],
                    [TourSpan(text: "Loss = (Predicted − Actual)²", bold: true, mono: true)],
                    [TourSpan(text: "Squared to ensure the error is always positive and to penalize larger errors more.")]
                ],
                highlightTarget: .node(id: ids.loss1)
            ),

            // STEP 4 — Introduce Viz node
            TourStep(
                title: "Tracking Loss During Training",
                body: [
                    [TourSpan(text: "This purple node is the "),
                     TourSpan(text: "Loss Curve", bold: true, color: .purple),
                     TourSpan(text: " — it shows how the Loss changes throughout training.")],
                    [TourSpan(text: "If the Neuron is learning well, the curve will "),
                     TourSpan(text: "keep going down.", bold: true, accent: true)]
                ],
                highlightTarget: .node(id: ids.viz1)
            ),

            // STEP 5 — Press Step for the first time (Forward Pass)
            TourStep(
                title: "First Step: Forward Pass",
                body: [
                    [TourSpan(text: "Press the "),
                     TourSpan(text: "Step ", bold: true, accent: true),
                     TourSpan(text: "|\u{25B6}", bold: true, mono: true),
                     TourSpan(text: " button once.")],
                    [TourSpan(text: "The Neuron will take one data sample, pass it through the weight, and "),
                     TourSpan(text: "predict the output", bold: true),
                     TourSpan(text: ".")],
                    [TourSpan(text: "Notice the Training Panel shows "),
                     TourSpan(text: "(Forward)", bold: true, color: .blue),
                     TourSpan(text: " — meaning the data flows forward.")]
                ],
                completionCondition: .trainingStepRun,
                onEnter: { vm in
                    vm.storyExpandTrainingPanel = true
                    vm.stepGranularity = .sample
                }
            ),

            // STEP 6 — View Forward result (ŷ vs y) — popover opens automatically from highlight
            TourStep(
                title: "How wrong is the Neuron?",
                body: [
                    [TourSpan(text: "Look at the popover of "),
                     TourSpan(text: "Loss", bold: true, color: .red),
                     TourSpan(text: " — you will see "),
                     TourSpan(text: "ŷ", bold: true, mono: true),
                     TourSpan(text: " (Neuron's prediction) compared to "),
                     TourSpan(text: "y", bold: true, mono: true),
                     TourSpan(text: " (actual answer).")],
                    [TourSpan(text: "The value "),
                     TourSpan(text: "L", bold: true, mono: true),
                     TourSpan(text: " is (ŷ − y)² — the higher it is, the more incorrect the prediction.")],
                    [TourSpan(text: "The weight hasn't been adjusted yet — the Neuron just made a \"guess\" for now.", italic: true)]
                ],
                highlightTarget: .node(id: ids.loss1)
            ),

            // STEP 7 — Press Step again (Backward Pass)
            TourStep(
                title: "Backward Pass: Learning from Mistakes",
                body: [
                    [TourSpan(text: "Press "),
                     TourSpan(text: "Step ", bold: true, accent: true),
                     TourSpan(text: "|\u{25B6}", bold: true, mono: true),
                     TourSpan(text: " again.")],
                    [TourSpan(text: "This time the Panel shows "),
                     TourSpan(text: "(Backward)", bold: true, color: .orange),
                     TourSpan(text: " — the system calculates backward to see how much each weight contributed to the error.")],
                    [TourSpan(text: "Then, the weight will be "),
                     TourSpan(text: "adjusted", bold: true, accent: true),
                     TourSpan(text: " so it makes fewer mistakes next time.")]
                ],
                completionCondition: .custom(id: "stepped2Times")
            ),

            // STEP 8 — View Gradient at weight
            TourStep(
                title: "How does the Weight change?",
                body: [
                    [TourSpan(text: "Look at the weight's popover — the number "),
                     TourSpan(text: "dL/dw", bold: true, mono: true),
                     TourSpan(text: " is the "),
                     TourSpan(text: "Gradient", bold: true, accent: true),
                     TourSpan(text: ".")],
                    [TourSpan(text: "It tells us: if the weight increases a bit, it changes the Loss in which "),
                     TourSpan(text: "direction", bold: true),
                     TourSpan(text: " and by "),
                     TourSpan(text: "how much", bold: true),
                     TourSpan(text: ".")],
                    [TourSpan(text: "w_new = w_old − lr × dL/dw", bold: true, mono: true)],
                    [TourSpan(text: "lr", mono: true),
                     TourSpan(text: " is the "),
                     TourSpan(text: "Learning Rate", bold: true, accent: true),
                     TourSpan(text: " — the step size for each adjustment.")]
                ],
                completionCondition: .weightTapped(connectionId: ids.weightW),
                highlightTarget: .weight(id: ids.weightW)
            ),

            // STEP 9 — Explain Epoch + Switch to epoch mode + Press step again
            TourStep(
                title: "What is an Epoch?",
                body: [
                    [TourSpan(text: "Stepping one sample at a time is very slow — the dataset has dozens of samples.")],
                    [TourSpan(text: "When the Neuron has seen "),
                     TourSpan(text: "all the data samples", bold: true),
                     TourSpan(text: " = "),
                     TourSpan(text: "1 Epoch", bold: true, mono: true),
                     TourSpan(text: ".")],
                    [TourSpan(text: "Let's change it to step by "),
                     TourSpan(text: "Epoch", bold: true, accent: true),
                     TourSpan(text: " instead — press "),
                     TourSpan(text: "Step", bold: true, accent: true),
                     TourSpan(text: "|\u{25B6}", bold: true, mono: true),
                     TourSpan(text: " and watch the "),
                     TourSpan(text: "Loss Curve", bold: true, color: .purple),
                     TourSpan(text: " change.")]
                ],
                completionCondition: .custom(id: "stepped6Times"),
                onEnter: { vm in
                    vm.stepGranularity = .epoch
                }
            ),

            // STEP 10 — Full Training
            TourStep(
                title: "Train to the Fullest",
                body: [
                    [TourSpan(text: "Pressing Step one by one is too slow.")],
                    [TourSpan(text: "Try pressing "),
                     TourSpan(text: "Train ", bold: true, accent: true),
                     TourSpan(text: "\u{25B6}\u{25B6}", bold: true, mono: true),
                     TourSpan(text: " and watch the Loss Curve plunge toward zero!")],
                ],
                completionCondition: .trainStarted
            ),

            // STEP 11 — Play with Learning Rate
            TourStep(
                title: "How important is the Learning Rate?",
                body: [
                    [TourSpan(text: "Press "),
                     TourSpan(text: "Reset ↺", bold: true),
                     TourSpan(text: " and try changing the "),
                     TourSpan(text: "LR", bold: true, accent: true),
                     TourSpan(text: " before pressing Train again.")],
                    [TourSpan(text: "Too high → weight jumps too far, Loss shoots up instead of down.", italic: true)],
                    [TourSpan(text: "Too low → learns very slowly, training takes a long time.", italic: true)],
                    [TourSpan(text: "Try values like "),
                     TourSpan(text: "0.01", mono: true),
                     TourSpan(text: ", "),
                     TourSpan(text: "0.1", mono: true),
                     TourSpan(text: ", or "),
                     TourSpan(text: "1.0", mono: true),
                     TourSpan(text: " and compare the results.")]
                ],
                completionCondition: .custom(id: "lrChanged")
            ),

            // STEP 12 — Conclusion: Gradient Descent
            TourStep(
                title: "Gradient Descent",
                body: [
                    [TourSpan(text: "What we just did is called "),
                     TourSpan(text: "Gradient Descent", bold: true, accent: true),
                     TourSpan(text: " — the heart of learning in all AIs.")],
                    [TourSpan(text: "Loop: "),
                     TourSpan(text: "Forward", bold: true, color: .blue),
                     TourSpan(text: " → Measure Loss → "),
                     TourSpan(text: "Backward", bold: true, color: .orange),
                     TourSpan(text: " → Adjust Weight → Repeat.")],
                    [TourSpan(text: "Next up: What happens if one Neuron isn't enough?", italic: true)]
                ],
                buttonLabel: "Go to Chapter 3 →"
            ),
        ]
    }()

    // MARK: - Chapter 3 Tour

    static let chapter3Tour: [TourStep] = {
        return [

            // STEP 1 — Open sidebar, drag a neuron
            TourStep(
                title: "Build Your Own AI",
                body: [
                    [TourSpan(text: "The Dataset is ready — it has "),
                     TourSpan(text: "X", bold: true, mono: true),
                     TourSpan(text: " and "),
                     TourSpan(text: "Y", bold: true, mono: true),
                     TourSpan(text: " data waiting for you.")],
                    [TourSpan(text: "Tap "),
                     TourSpan(text: "Neuron", bold: true, accent: true),
                     TourSpan(text: " in the sidebar on the left to place one on the canvas.")]
                ],
                completionCondition: .custom(id: "NeuronAdded"),
                onEnter: { vm in
                    vm.storySidebarOpen = true
                }
            ),

            // STEP 2 — Connect Dataset X → Neuron
            TourStep(
                title: "Connect the Data",
                body: [
                    [TourSpan(text: "Drag a line from the "),
                     TourSpan(text: "X", bold: true, mono: true),
                     TourSpan(text: " port of the Dataset to the Neuron you just placed.")]
                ],
                completionCondition: .connectionMade
            ),

            // STEP 3 — Set neuron role
            TourStep(
                title: "Tell the Neuron Its Role",
                body: [
                    [TourSpan(text: "Tap the Neuron connected to the Dataset to open its popover.")],
                    [TourSpan(text: "Turn on "),
                     TourSpan(text: "Input", bold: true, accent: true),
                     TourSpan(text: " — this tells the system this Neuron receives data.")],
                    [TourSpan(text: "Without a role, the system won't know where data starts.", italic: true)]
                ]
            ),

            // STEP 4 — Add output neuron + bias
            TourStep(
                title: "Add an Output Neuron",
                body: [
                    [TourSpan(text: "Add another "),
                     TourSpan(text: "Neuron", bold: true, accent: true),
                     TourSpan(text: " and drag a line from the Input Neuron to it.")],
                    [TourSpan(text: "Tap the new Neuron → turn on "),
                     TourSpan(text: "Output", bold: true, accent: true),
                     TourSpan(text: ".")],
                    [TourSpan(text: "Don't forget to add a "),
                     TourSpan(text: "Bias", bold: true),
                     TourSpan(text: " from the sidebar and connect it to the Output Neuron.")]
                ],
                completionCondition: .custom(id: "NeuronAdded"),
                onEnter: { vm in
                    vm.clearTourCondition(.custom(id: "NeuronAdded"))
                }
            ),

            // STEP 5 — Add Loss node + connect
            TourStep(
                title: "Measure the Error",
                body: [
                    [TourSpan(text: "Add a "),
                     TourSpan(text: "Loss", bold: true, color: .red),
                     TourSpan(text: " node from the sidebar and connect:")],
                    [TourSpan(text: "• Output Neuron → Loss (ŷ port)")],
                    [TourSpan(text: "• Dataset Y → Loss (y port)")]
                ],
                completionCondition: .custom(id: "LossAdded")
            ),

            // STEP 6 — Train
            TourStep(
                title: "Train It!",
                body: [
                    [TourSpan(text: "Press "),
                     TourSpan(text: "Train", bold: true, accent: true),
                     TourSpan(text: " and watch the Loss go down.")],
                    [TourSpan(text: "If you see a graph validation error, check that:")],
                    [TourSpan(text: "• Input/Output roles are set correctly", italic: true)],
                    [TourSpan(text: "• Bias is connected to the Output Neuron", italic: true)]
                ],
                completionCondition: .trainStarted,
                onEnter: { vm in
                    vm.storyExpandTrainingPanel = true
                }
            ),

            // STEP 7 — Add Scatter Plot (inference mode)
            TourStep(
                title: "See What the Neuron Learned",
                body: [
                    [TourSpan(text: "Switch to "),
                     TourSpan(text: "Inference mode", bold: true, accent: true),
                     TourSpan(text: " (top-right button).")],
                    [TourSpan(text: "Open the sidebar → add a "),
                     TourSpan(text: "Scatter Plot", bold: true, accent: true),
                     TourSpan(text: ".")],
                    [TourSpan(text: "Change input node to Dataset")],
                    [TourSpan(text: "Connect: Dataset X→x₁, Dataset Y→y₁ (ground truth)")],
                    [TourSpan(text: "Then: Dataset X→x₂, Output Neuron→y₂ (predictions)")]
                ],
                completionCondition: .custom(id: "ScatterAdded")
            ),

            // STEP 8 — Predict All + close sidebar
            TourStep(
                title: "The Line the Neuron Drew",
                body: [
                    [TourSpan(text: "Select "),
                     TourSpan(text: "Predict All", bold: true, accent: true),
                     TourSpan(text: " mode, then press the Predict button.")],
                    [TourSpan(text: "Blue dots are the real data. Orange dots are the Neuron's predictions.")],
                    [TourSpan(text: "One Neuron + Linear activation = a straight line.", italic: true)]
                ],
                completionCondition: .custom(id: "predictedAll"),
                onEnter: { vm in
                    vm.storySidebarOpen = false
                }
            ),

            // STEP 9 — Conclusion + tease next chapter
            TourStep(
                title: "You Built Your First AI!",
                body: [
                    [TourSpan(text: "A single Neuron can "),
                     TourSpan(text: "learn a straight line", bold: true, accent: true),
                     TourSpan(text: ".")],
                    [TourSpan(text: "But real-world data isn't always linear...")],
                    [TourSpan(text: "Next: We'll test the limits of a single Neuron.", italic: true)]
                ],
                buttonLabel: "Go to Chapter 4 →"
            ),
        ]
    }()
}
