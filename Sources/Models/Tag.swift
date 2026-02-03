import SwiftUI
import AppKit

struct DefaultTagDefinition: Identifiable {
    let id = UUID()
    let name: String
    let isSystem: Bool
    let colorHex: String
}

enum TagDefaults {
    static let idleName = "Idle / Off"
    static let definitions: [DefaultTagDefinition] = [
        DefaultTagDefinition(name: "School", isSystem: false, colorHex: "#0A84FF"),
        DefaultTagDefinition(name: "Work", isSystem: false, colorHex: "#64D2FF"),
        DefaultTagDefinition(name: "Training", isSystem: false, colorHex: "#30D158"),
        DefaultTagDefinition(name: "Food", isSystem: false, colorHex: "#FF9F0A"),
        DefaultTagDefinition(name: "Personal Care", isSystem: false, colorHex: "#FF375F"),
        DefaultTagDefinition(name: "Recovery / Mind", isSystem: false, colorHex: "#BF5AF2"),
        DefaultTagDefinition(name: "Social / Admin", isSystem: false, colorHex: "#5E5CE6"),
        DefaultTagDefinition(name: idleName, isSystem: true, colorHex: "#8E8E93")
    ]
}

func defaultTagColorHex(for tagName: String) -> String? {
    TagDefaults.definitions.first(where: { $0.name == tagName })?.colorHex
}

func tagColor(_ tag: TagItem) -> Color {
    if let hex = tag.colorHex, let color = Color(hex: hex) {
        return color
    }
    return tagColor(tag.name)
}

func tagColor(_ tagName: String) -> Color {
    if let hex = defaultTagColorHex(for: tagName), let color = Color(hex: hex) {
        return color
    }
    return .accentColor
}

extension Color {
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let length = sanitized.count
        guard length == 6 || length == 8 else { return nil }
        guard let value = UInt64(sanitized, radix: 16) else { return nil }

        let r, g, b, a: Double
        if length == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        }

        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toHexString(includeAlpha: Bool = false) -> String? {
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        let a = Int(round(rgb.alphaComponent * 255))
        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

func formattedDuration(_ duration: TimeInterval) -> String {
    if duration < 60 {
        return "<1m"
    }
    let totalMinutes = Int(duration / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

func formatPercent(_ value: Double) -> String {
    let clamped = max(0, min(1, value))
    let percent = Int((clamped * 100).rounded())
    return "\(percent)%"
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

func formattedTime(_ date: Date) -> String {
    timeFormatter.string(from: date)
}

func formattedTimeRange(start: Date, end: Date) -> String {
    "\(formattedTime(start))–\(formattedTime(end))"
}
