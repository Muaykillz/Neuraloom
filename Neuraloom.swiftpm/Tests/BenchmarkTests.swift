import Foundation
import Accelerate

func runBenchmarkTests() {
    print("\n--- Running Task 5: Benchmark Tests (Utilizing Model) ---")
    
    // MARK: - Test 4: Accelerate Benchmark
    print("[Test 4] SGDOptimizer Performance (vDSP vs Manual Loop)")
    
    let weightCount = 100_000
    let iterations = 100
    let learningRate = 0.01
    
    // สร้าง Dummy Neurons เพื่อสร้าง Weight
    let n1 = Neuron(activation: .linear)
    let n2 = Neuron(activation: .linear)
    
    // 1. เตรียมข้อมูลสำหรับ Benchmark โดยใช้ Weight objects จริงๆ จาก Model
    var modelWeights: [Weight] = []
    for _ in 0..<weightCount {
        let w = Weight(from: n1, to: n2, initialValue: 0.5)
        w.gradient = 0.1 // จำลอง gradient
        modelWeights.append(w)
    }
    
    // สร้าง Optimizer จาก Model ของเราจริงๆ
    let optimizer = SGDOptimizer(learningRate: learningRate)
    
    // --- Measure SGDOptimizer.step (Uses Accelerate) ---
    let startModel = CFAbsoluteTimeGetCurrent()
    for _ in 0..<iterations {
        // นี่คือการเรียกใช้ Logic ใน Model ของเราจริงๆ
        optimizer.step(weights: modelWeights, batchSize: 1)
    }
    let endModel = CFAbsoluteTimeGetCurrent()
    let timeModel = endModel - startModel
    
    // --- Measure Manual Loop (No Accelerate) ---
    // Reset values
    for w in modelWeights { w.value = 0.5 }
    
    let startManual = CFAbsoluteTimeGetCurrent()
    for _ in 0..<iterations {
        // จำลองการอัปเดตแบบวน Loop ทีละตัว (Naive)
        let stepSize = -learningRate / 1.0
        for w in modelWeights {
            w.value += w.gradient * stepSize
        }
    }
    let endManual = CFAbsoluteTimeGetCurrent()
    let timeManual = endManual - startManual
    
    print("Manual Loop Time: \(String(format: "%.4f", timeManual))s")
    print("SGDOptimizer (vDSP) Time: \(String(format: "%.4f", timeModel))s")
    
    let speedup = timeManual / timeModel
    print("Actual Speedup in Model: \(String(format: "%.2fx", speedup))")
    
    if speedup > 1.0 {
        print("✅ Test 4 Passed: Your SGDOptimizer is significantly faster!")
    } else {
        print("⚠️ Test 4: Speedup was minimal. (Check if weightCount is large enough for vDSP overhead)")
    }
}