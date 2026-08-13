import SwiftUI

/// Swipeable pages between the two watch modes: Capture (build a note for
/// later phone review) and Ask (a single spoken term, answered immediately).
/// They're deliberately separate flows, not tabs within one screen — see
/// WatchAskView's header comment for why.
struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchCaptureView()
            WatchAskView()
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    WatchRootView()
}
