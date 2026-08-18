import SwiftUI
import UIKit

/// Device-shake detection, Instagram-style "shake to report". UIKit delivers
/// motion events (including shake) up the responder chain to the key window;
/// overriding `motionEnded` on UIWindow lets us catch a shake from anywhere in
/// the app and rebroadcast it as a Notification that SwiftUI can observe via
/// the `.onShake` modifier below.
extension Notification.Name {
    static let deviceDidShake = Notification.Name("com.nursify.deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

private struct ShakeDetectorModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            // A firm buzz confirms the shake registered before the drawer opens.
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            action()
        }
    }
}

extension View {
    /// Runs `action` whenever the device is shaken.
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetectorModifier(action: action))
    }
}
