import SwiftUI

/// Visual language ported from mockups/v4/screens.html.
/// Font note: the mockups use Quicksand + Nunito (Google Fonts). No font files
/// are bundled yet, so this substitutes SF Rounded (native, no asset needed) as
/// a close-enough stand-in. Swap in real Quicksand/Nunito .ttf + Info.plist
/// UIAppFonts registration later if the system rounded face isn't warm enough.
enum Theme {
    enum Color {
        static let background = SwiftUI.Color(hex: "FBF7F2")
        static let card = SwiftUI.Color.white
        static let ink = SwiftUI.Color(hex: "3A352E")
        static let sub = SwiftUI.Color(hex: "8B8377")
        static let line = SwiftUI.Color(hex: "EEE7DB")
        static let accent = SwiftUI.Color(hex: "5FA88C")
        static let accentInk = SwiftUI.Color(hex: "3E7D66")
        static let accentSoftBackground = SwiftUI.Color(hex: "E7F2ED")
        static let warnBackground = SwiftUI.Color(hex: "FDF1E3")
        static let warnLine = SwiftUI.Color(hex: "F3D9B3")
        static let warnInk = SwiftUI.Color(hex: "97672C")

        static let badgeDueBackground = SwiftUI.Color(hex: "FCE7E0")
        static let badgeDueInk = SwiftUI.Color(hex: "B5583B")
        static let badgeNewBackground = SwiftUI.Color(hex: "E7EEF9")
        static let badgeNewInk = SwiftUI.Color(hex: "4C6E9C")
        static let badgePracticeBackground = SwiftUI.Color(hex: "E6F3E9")
        static let badgePracticeInk = SwiftUI.Color(hex: "3F8158")
        static let badgeCoreBackground = SwiftUI.Color(hex: "FBF0DC")
        static let badgeCoreInk = SwiftUI.Color(hex: "A57C2E")
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
