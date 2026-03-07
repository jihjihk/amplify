import CoreText
import Foundation
import SwiftUI

// MARK: - AmplifyFonts

/// Registers bundled Instrument Serif fonts and provides SwiftUI Font helpers.
public enum AmplifyFonts {
    nonisolated(unsafe) private static var registered = false

    /// Register bundled fonts. Safe to call multiple times (from any thread).
    public static func registerIfNeeded() {
        guard !registered else { return }
        registered = true

        for name in ["InstrumentSerif-Regular", "InstrumentSerif-Italic"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else {
                print("[AmplifyFonts] font not found: \(name).ttf")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // MARK: - Font Constructors

    public static func instrumentSerif(size: CGFloat) -> Font {
        .custom("Instrument Serif", size: size)
    }

    public static func instrumentSerifItalic(size: CGFloat) -> Font {
        .custom("Instrument Serif", size: size).italic()
    }

    // MARK: - Semantic Scale

    /// 42pt — hero/onboarding display
    public static var display: Font    { instrumentSerif(size: 42) }
    /// 34pt — window-level titles
    public static var largeTitle: Font { instrumentSerif(size: 34) }
    /// 28pt — section titles
    public static var title: Font      { instrumentSerif(size: 28) }
    /// 22pt — panel headings
    public static var title2: Font     { instrumentSerif(size: 22) }
    /// 20pt — card headings
    public static var title3: Font     { instrumentSerif(size: 20) }
    /// 17pt — sidebar headers, emphasized labels
    public static var headline: Font   { instrumentSerif(size: 17) }
}

// MARK: - AmplifyColors

/// The Amplify color palette — warm parchment tones in three depth layers.
///
/// Light: warm beige family anchored by #F2EDE4 (parchment).
/// Dark:  deep walnut family anchored by #1A1713.
/// Accent: walnut ink in light / aged gold in dark.
public enum AmplifyColors {

    // MARK: - Background Layers (light → dark across the UI)

    /// Main app background — warm parchment beige
    public static let parchment = adaptive(
        light: NSColor(r: 242, g: 237, b: 228),
        dark:  NSColor(r: 26,  g: 23,  b: 19)
    )

    /// Editor writing surface — slightly lighter for reading focus
    public static let surface = adaptive(
        light: NSColor(r: 247, g: 244, b: 239),
        dark:  NSColor(r: 32,  g: 29,  b: 25)
    )

    /// Sidebar panel — one shade darker than parchment, grounded
    public static let sidebarBg = adaptive(
        light: NSColor(r: 234, g: 229, b: 220),
        dark:  NSColor(r: 20,  g: 18,  b: 16)
    )

    /// Headers, toolbars, status bars
    public static let barBg = adaptive(
        light: NSColor(r: 237, g: 232, b: 223),
        dark:  NSColor(r: 26,  g: 23,  b: 19)
    )

    // MARK: - Ink Scale

    /// Primary text — warm near-black / warm off-white
    public static let inkPrimary = adaptive(
        light: NSColor(r: 26,  g: 23,  b: 19),
        dark:  NSColor(r: 237, g: 232, b: 223)
    )

    /// Secondary text — warm mid-brown / warm mid-gray
    public static let inkSecondary = adaptive(
        light: NSColor(r: 107, g: 97,  b: 87),
        dark:  NSColor(r: 156, g: 145, b: 136)
    )

    /// Tertiary text — for captions, placeholders
    public static let inkTertiary = adaptive(
        light: NSColor(r: 156, g: 145, b: 136),
        dark:  NSColor(r: 107, g: 97,  b: 87)
    )

    // MARK: - Accent

    /// Interactive accent — walnut ink in light, aged gold in dark
    public static let accent = adaptive(
        light: NSColor(r: 92,  g: 61,  b: 46),
        dark:  NSColor(r: 196, g: 154, b: 108)
    )

    /// Warm row selection tint
    public static var selectionTint: Color { accent.opacity(0.12) }

    // MARK: - Terminal Colors (AppKit, always warm-dark)

    /// Terminal background — deep walnut, always dark
    public static let terminalBg = NSColor(r: 26, g: 23, b: 19)
    /// Terminal foreground — warm off-white
    public static let terminalFg = NSColor(r: 213, g: 208, b: 200)

    // MARK: - Helpers

    public static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }))
    }

    public static func adaptiveNS(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

// MARK: - NSColor Convenience

private extension NSColor {
    convenience init(r: Int, g: Int, b: Int, a: CGFloat = 1) {
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
    }
}
