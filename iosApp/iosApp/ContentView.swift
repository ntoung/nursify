import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Text("Capture")
                .tabItem {
                    Label("Capture", systemImage: "mic.fill")
                }

            Text("Learning Graph")
                .tabItem {
                    Label("Learn", systemImage: "point.3.connected.trianglepath.dotted")
                }

            Text("Chart Lookup")
                .tabItem {
                    Label("Chart", systemImage: "list.bullet.clipboard")
                }
        }
    }
}

#Preview {
    ContentView()
}
