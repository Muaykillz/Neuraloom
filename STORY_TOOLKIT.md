# Neuraloom Story Toolkit

Reference document for designing educational content in Neuraloom.

---

## Content Structure

```
Example:
Chapter
  └── Beat 1  →  Beat 2  →  Beat 3  →  ...
        │          │          │
     cutscene   playground  cutscene   ...
```

- **Chapter**: A self-contained lesson (e.g. "Hello, Neuron").
- **Beat**: One step in the chapter. Each beat is either a **Cutscene** or a **Playground**.
- Beats play sequentially. On completion, the chapter is marked done.

---

## Beat Type: Cutscene

A passive, cinematic sequence of pages. No interaction beyond tapping "Continue".

### Page Elements

| Element | Description | Example |
|---------|-------------|---------|
| `imageName` | Asset image displayed large at top | `"apple-face-id-icon"` |
| `sfSymbol` | SF Symbol displayed large at top (alternative to image) | `"brain.head.profile"` |
| `lines` | Rich text body, array of lines, each line is array of styled spans | see below |
| `typewriterLine` | Monospaced text that types out character-by-character | `"y = wx + b"` |
| `buttonLabel` | Custom button text (default: "Continue") | `"Let's go!"` |

### Text Styling (CutsceneSpan)

Each line is composed of spans with independent styling:

```
[CutsceneSpan(text: "A machine "),
 CutsceneSpan(text: "learned", bold: true, accent: true),
 CutsceneSpan(text: " to see.")]
```

| Property | Effect |
|----------|--------|
| `bold` | Bold weight |
| `italic` | Italic style |
| `accent` | Orange color (for emphasis keywords) |

Default: 40pt serif, centered, white.

### Animations

- Page fade-in on appear
- Button slides up with delay
- Typewriter: 0.04s per character, cursor while typing, sparkle when done

### Capabilities & Limits

- No branching or user choices.
- No interactive elements.
- Best for: narrative framing, historical context, concept introduction, "aha moment" reveals.

---

## Beat Type: Playground

An interactive sandbox with the full Neuraloom canvas + a guided tour overlay.

### Tour Steps

Sequential message boxes that guide the user through the playground.

```swift
TourStep(title: "Meet the Neuron", body: "This orange circle is a neuron...")
```

| Property | Description |
|----------|-------------|
| `title` | Bold heading |
| `body` | Explanatory paragraph |

- User navigates with Previous / Next / Done.
- Tour can be dismissed (X button).
- "Done" on the last step triggers beat completion.

### Rich Text (TourSpan)

Tour steps support styled text, same pattern as cutscenes but at 15pt rounded:

```swift
TourStep(
    title: "Weights Matter",
    body: [
        [TourSpan(text: "Each connection has a "),
         TourSpan(text: "weight", bold: true, accent: true),
         TourSpan(text: " that controls signal strength.")]
    ]
)
```

| Property | Effect |
|----------|--------|
| `bold` | Bold weight |
| `italic` | Italic style |
| `accent` | Orange color |
| `mono` | Monospaced font |

Plain-string convenience still works: `TourStep(title:body:String)`.

### Completion Conditions

Lock the "Next" button until the user performs a specific action:

```swift
TourStep(
    title: "Try It",
    body: [[TourSpan(text: "Tap any connection to see its weight.")]],
    completionCondition: .weightTapped
)
```

| Condition | Triggered when |
|-----------|---------------|
| `.inspectModeOpened` | User switches to Inspect mode |
| `.weightChanged` | User edits a weight value |
| `.weightTapped` | User taps any connection |
| `.trainingStepRun` | One training step completes |
| `.trainStarted` | User presses Train |
| `.nodeAdded` | User adds any node |
| `.connectionMade` | User wires a connection |
| `.custom(id:)` | Manual trigger via `fulfillTourCondition` |

When locked, the Next button shows a gray lock icon and is disabled.

### Highlight Targets

Automatically focus the user's attention on a canvas element:

```swift
TourStep(
    title: "This Neuron",
    body: [[TourSpan(text: "Look at the highlighted neuron.")]],
    highlightTarget: .node(id: someNeuronId)
)
```

| Target | Effect |
|--------|--------|
| `.node(id:)` | Selects the node (opens its popover) |
| `.connection(id:)` | Selects the connection (opens weight popover) |
| `.glowNodes(ids:)` | Pulse-glows a set of neurons |

Highlights auto-clear when navigating to the next step.

### Pre-built Canvas

The playground loads with a pre-configured network via a setup function (e.g. `setupMVPScenario()`). You can define:

- Which nodes exist and where they are positioned
- Which connections are pre-wired
- Initial weight values
- Dataset preset

### Two Modes: Train vs Inference

|  | **Train Mode** | **Inference Mode** |
|--|----------------|-------------------|
| **Purpose** | Teach the network by running many samples through it and updating weights via gradient descent | Feed a single input and watch how the network computes its output |
| **What runs** | Full training loop (forward + backward + weight update) across all dataset rows | A single forward pass for one input |
| **Sidebar panel** | Training controls: LR, step granularity, epoch count, Train/Step/Reset buttons | Inference controls: input source (manual sliders / dataset row), Predict / Predict All, Auto Predict toggle |
| **Visible nodes** | All nodes (dataset, neurons, loss, viz) | Neurons + auto-created Result nodes; loss & viz are hidden |
| **Key animation** | Loss curve updating in real-time on Visualization node | Layer-by-layer glow propagating from input → output |
| **Weight changes** | Weights update automatically via optimizer after each step | Weights stay fixed (but user can drag sliders to tweak manually) |
| **Inspect sub-mode** | Shows forward values, error signals (delta), gradient derivation, update formula (w_new = w_old - lr * grad) | Shows forward values and computation breakdown only (no gradients — no backward pass ran) |
| **Best for teaching** | Gradient descent, backpropagation, loss functions, learning rate effects, overfitting | Forward pass, what a neuron computes, effect of weights/bias, predictions, decision boundaries |

### Teaching Tip: Forward Pass → Use Inference Mode

If you want to teach **what a neuron does** or **how a forward pass works**, prefer Inference mode over Train mode:

- In Inference, the user controls **one input at a time** (via sliders or dataset row picker), making it easy to see cause → effect.
- The **layer-by-layer glow** animation visually traces the signal from input to output — perfect for "watch the data flow" moments.
- **Weight sliders** let the user manually adjust `w` and `b` and instantly see how the output changes, without the complexity of a training loop.
- **Inspect sub-mode** shows the computation breakdown (`z = w·x + b`) without the noise of gradients and update formulas.
- Train mode runs all samples at once and updates weights automatically — too much happening to isolate "what does one neuron do?"

In short: **Inference = magnifying glass** (zoom in on one computation), **Train = time-lapse** (watch the network learn over many steps).

### Two Sub-modes

| Sub-mode | Purpose |
|----------|---------|
| **Dev** | Edit network structure, configure nodes |
| **Inspect** | See all computed values, gradients, formulas |

---

## Canvas Elements Reference

### Nodes

#### Neuron
- **Visual**: Orange circle (50px)
- **Roles**: Input (I), Output (O), Hidden (N), Bias (1)
- **Activations**: Linear, ReLU, Sigmoid
- **Ports**: 1 output (right)
- **Inspect mode**: Shows output value, forward computation breakdown (w*x terms), error signal (delta), gradient derivation
- **Bias behavior**: Always outputs 1.0, cannot receive connections

#### Dataset
- **Visual**: Blue card (200px wide)
- **Presets**: XOR (4 rows, 2in/1out), Linear (20 rows, 1in/1out), Circle (50 rows, 2in/1out), Spiral (100 rows, 2in/1out)
- **Ports**: 1 output per column (right side), labeled with column names
- **Inference manual mode**: Shows sliders per input column
- **Inference dataset mode**: Shows scrollable row picker

#### Loss
- **Visual**: Red card (120x72px)
- **Functions**: MSE, Cross-Entropy
- **Ports**: 2 inputs (left: y-hat, y-true), 1 output (right)
- **Display**: Current loss value, color-coded (green < 0.05, orange < 0.15, red)
- **Inspect mode**: Formula breakdown with interactive concept boxes

#### Visualization (Loss Curve)
- **Visual**: Purple card (210x148px)
- **Port**: 1 input (left), receives loss signal
- **Display**: Real-time line chart of loss over training steps
- **Train-mode only**: Hidden during inference

#### Scatter Plot (Scatter 2D)
- **Visual**: Teal card (240x200px)
- **Ports**: 4 inputs (left: x1, y1, x2, y2)
- **Series A** (blue dots): wired to x1, y1 (typically ground truth)
- **Series B** (orange dots): wired to x2, y2 (typically predictions)
- **Behavior**: Each inference run appends points. "Predict All" clears then re-plots all.
- **Config**: Optional locked axis ranges (code-only)
- **Clear button**: Resets accumulated points
- **Inference-mode only**: Available in inference sidebar

#### Output Display (Result)
- **Visual**: Green card (140px wide)
- **Port**: 1 input (left)
- **Display**: Single numeric value (4 decimals, green)
- **Auto-created**: One per output neuron when entering inference mode

#### Number
- **Visual**: Teal card (100px wide)
- **Port**: 1 output (right)
- **Display**: Editable constant value
- **Use case**: Feed a fixed number into the network

#### Annotation (Note)
- **Visual**: Minimal gray text box
- **No ports**
- **Double-tap to edit** text content
- **Use case**: Label or explain parts of the canvas

### Connections (Edges)

| Type | Color | Style | Value |
|------|-------|-------|-------|
| Neuron → Neuron | Orange | Solid, thickness = weight magnitude | Learnable weight (-inf to +inf) |
| Dataset port → Neuron | Blue | Dashed | Data passthrough |
| Neuron → Loss port | Blue | Dashed | Data passthrough |
| Loss → Visualization | Blue | Dashed | Loss passthrough |
| Any → Scatter port | Blue | Dashed | Data passthrough |

- **Weight popover (dev)**: Editable value, gradient display, update formula breakdown
- **Weight popover (inference)**: Value slider (-3 to +3), live re-prediction on change
- **Cycle prevention**: Feedforward only, connections that create cycles are rejected

---

## Training Controls

| Control | Description |
|---------|-------------|
| Learning Rate | Text input (typical: 0.001 - 1.0) |
| Step Granularity | Epoch (all samples) or Sample (one at a time) |
| Step Count | How many epochs/steps to run |
| Step Button | Execute one step (hold for auto-repeat) |
| Train Button | Start/stop continuous training |
| Reset Button | Re-randomize all weights |
| Dev / Inspect | Toggle between editing and viewing computations |

### Training Visualization

- **Loss curve**: Updates in real-time on Visualization node
- **Sample highlight**: In sample-step mode, shows which data row is active
- **Phase indicator**: Shows "Forward" or "Backward" during step-through
- **Node values**: In inspect mode, all neurons show their current computed value
- **Connection glow**: Active connections glow during step animation

---

## Inference Controls

| Control | Description |
|---------|-------------|
| Input Source | Manual (sliders) or Dataset (row picker) |
| Predict | Single forward pass with layer-by-layer glow animation |
| Predict All | Run all dataset rows silently, plot results |
| Auto Predict | Toggle: re-run on any input/weight change |

### Inference Visualization

- **Layer-by-layer glow**: Animated signal propagation from input to output
- **Result nodes**: Auto-created, show output neuron values
- **Scatter plot**: Accumulates predicted vs true data points
- **Weight sliders**: Adjust weights live, see prediction change instantly

---

## What Each Element Can Teach

| Concept | Best Elements |
|---------|---------------|
| What is a neuron | Neuron node + inspect mode (see w*x + b) |
| Activation functions | Neuron activation selector + inspect (see f(x) applied) |
| Weights & bias | Connection weight popover + bias neuron |
| Forward pass | Inspect mode step-through (value propagation) |
| Loss function | Loss node + visualization (see error quantified) |
| Gradient descent | Training step + weight popover (see w_new = w_old - lr * grad) |
| Backpropagation | Inspect mode backward phase (see gradients flow back) |
| Learning rate | LR slider + loss curve (too high = diverge, too low = slow) |
| Overfitting | Compare train vs test on scatter plot |
| Linear regression | 1-neuron network + linear dataset + scatter plot |
| XOR problem | 2-layer network + XOR dataset (linear can't solve it) |
| Network depth | Add hidden layers, compare learning |
| Decision boundary | Scatter plot with ground truth vs predictions |

---

## Typical Wiring Patterns

### Linear Regression (1 neuron)
```
Dataset[X] → Input → Output → Loss[y-hat]
Dataset[Y] ──────────────────→ Loss[y-true]
Bias ────────→ Output
Loss → Viz
```

### XOR (2-layer MLP)
```
Dataset[X1] → Input1 → Hidden1 → Output → Loss[y-hat]
Dataset[X2] → Input2 → Hidden2 ↗         Loss[y-true] ← Dataset[Y]
              Input1 → Hidden2            Loss → Viz
              Input2 → Hidden1
```

### Scatter Plot (inference)
```
Dataset[X] ──→ Scatter[x1]    (ground truth X)
Dataset[Y] ──→ Scatter[y1]    (ground truth Y)
Dataset[X] ──→ Scatter[x2]    (prediction X = same input)
Output     ──→ Scatter[y2]    (prediction Y = network output)
```
