import SwiftUI
import UIKit

/// Visual language ported from mockups/v4/screens.html.
/// Font note: the mockups use Quicksand + Nunito (Google Fonts). No font files
/// are bundled yet, so this substitutes SF Rounded (native, no asset needed) as
/// a close-enough stand-in. Swap in real Quicksand/Nunito .ttf + Info.plist
/// UIAppFonts registration later if the system rounded face isn't warm enough.
///
/// Every token here is light/dark adaptive (see `Color.adaptive`) — the
/// mockups only ever specified a light palette, so the dark pairings below
/// are new, chosen to keep the same warm/rounded feel rather than switching
/// to a cold neutral gray dark mode.
enum Theme {
    enum Color {
        static let background = SwiftUI.Color.adaptive(light: "FBF7F2", dark: "1B1A17")
        static let card = SwiftUI.Color.adaptive(light: "FFFFFF", dark: "26241F")
        static let ink = SwiftUI.Color.adaptive(light: "3A352E", dark: "F2EDE3")
        static let sub = SwiftUI.Color.adaptive(light: "8B8377", dark: "A69C8C")
        static let line = SwiftUI.Color.adaptive(light: "EEE7DB", dark: "3A372F")
        static let accent = SwiftUI.Color.adaptive(light: "5FA88C", dark: "6FBFA0")
        static let accentInk = SwiftUI.Color.adaptive(light: "3E7D66", dark: "8FD9BC")
        static let accentSoftBackground = SwiftUI.Color.adaptive(light: "E7F2ED", dark: "1E2E29")
        /// Muted green borders (quick-pick chips, editable chip fields) —
        /// previously an ad-hoc "CFE6DB" hex repeated at each call site.
        static let accentBorder = SwiftUI.Color.adaptive(light: "CFE6DB", dark: "3A5147")
        static let warnBackground = SwiftUI.Color.adaptive(light: "FDF1E3", dark: "332A1C")
        static let warnLine = SwiftUI.Color.adaptive(light: "F3D9B3", dark: "5C4A2E")
        static let warnInk = SwiftUI.Color.adaptive(light: "97672C", dark: "E0B978")
        /// Neutral tag-pill background (e.g. concept type tags) — previously
        /// an ad-hoc "F1ECE1" hex.
        static let tagBackground = SwiftUI.Color.adaptive(light: "F1ECE1", dark: "302D27")
        /// Dashed "add another item" borders — previously an ad-hoc
        /// "C9BFAD" hex repeated at each call site.
        static let dashedBorder = SwiftUI.Color.adaptive(light: "C9BFAD", dark: "4A4438")

        static let badgeDueBackground = SwiftUI.Color.adaptive(light: "FCE7E0", dark: "3A241E")
        static let badgeDueInk = SwiftUI.Color.adaptive(light: "B5583B", dark: "E8917A")
        static let badgeNewBackground = SwiftUI.Color.adaptive(light: "E7EEF9", dark: "1E2733")
        static let badgeNewInk = SwiftUI.Color.adaptive(light: "4C6E9C", dark: "8FB0DE")
        static let badgePracticeBackground = SwiftUI.Color.adaptive(light: "E6F3E9", dark: "1C2E22")
        static let badgePracticeInk = SwiftUI.Color.adaptive(light: "3F8158", dark: "7FC494")
        static let badgeCoreBackground = SwiftUI.Color.adaptive(light: "FBF0DC", dark: "332B1A")
        static let badgeCoreInk = SwiftUI.Color.adaptive(light: "A57C2E", dark: "D9AE5C")
    }

    enum Font {
        static func heading(_ size: CGFloat, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }

    enum Radius {
        static let card: CGFloat = 20
        static let button: CGFloat = 18
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// A color that resolves to `light` or `dark` at render time based on
    /// the current system appearance — not fixed at creation time, so one
    /// Theme.Color token correctly follows the device switching in/out of
    /// Dark Mode without every screen needing its own `colorScheme` check.
    static func adaptive(light: String, dark: String) -> SwiftUI.Color {
        SwiftUI.Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

/// Simple wrapping layout for chip rows (specialty picker, category browse, tags).
/// SwiftUI has no built-in flow layout; this is a minimal Layout-protocol implementation.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: maxWidth.isFinite ? maxWidth : totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
