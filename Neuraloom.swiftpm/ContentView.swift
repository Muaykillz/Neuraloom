import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .onAppear {
            Task {
                print("🚀 Starting Tests...")
                runTrainingTests()
//                runBenchmarkTests()
                print("🏁 All Tests Finished.")
            }
        }
    }
}
