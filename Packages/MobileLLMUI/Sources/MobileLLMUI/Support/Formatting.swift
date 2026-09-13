// SPDX-License-Identifier: MIT

import Foundation
import LLMCore

/// Small display formatters shared across the chat + models surfaces.
enum Format {

    /// Recency bucket for the conversation list (DESIGN §4 — Pinned / Today / Yesterday / …).
    enum RecencyGroup: String, CaseIterable {
        case pinned = "Pinned"
        case today = "Today"
        case yesterday = "Yesterday"
        case thisWeek = "Previous 7 Days"
        case thisMonth = "Previous 30 Days"
        case older = "Older"

        /// Section header. The raw values are stable identifiers in their own right (grouping and
        /// persistence compare against them), so the localized text lives here instead.
        var label: String {
            switch self {
            case .pinned: String(localized: "Pinned", bundle: .main)
            case .today: String(localized: "Today", bundle: .main)
            case .yesterday: String(localized: "Yesterday", bundle: .main)
            case .thisWeek: String(localized: "Previous 7 Days", bundle: .main)
            case .thisMonth: String(localized: "Previous 30 Days", bundle: .main)
            case .older: String(localized: "Older", bundle: .main)
            }
        }
    }

    static func group(for entry: ConversationIndexEntry, now: Date = Date(),
                      calendar: Calendar = .current) -> RecencyGroup {
        if entry.pinned { return .pinned }
        return group(for: entry.updatedAt, now: now, calendar: calendar)
    }

    static func group(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> RecencyGroup {
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }
        guard let days = calendar.dateComponents([.day], from: date, to: now).day else { return .older }
        if days < 7 { return .thisWeek }
        if days < 30 { return .thisMonth }
        return .older
    }

    /// A relative timestamp for a list row ("2h", "Mon", "3 Jul").
    static func relative(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
        }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday", bundle: .main) }
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        let f = DateFormatter()
        f.dateFormat = days < 7 ? "EEE" : "d MMM"
        return f.string(from: date)
    }

    /// The quiet per-message stats footer (DESIGN §4): "Bonsai 8B · 41 tok · 23 tok/s · stop: eos".
    ///
    /// A zero count means "this engine doesn't report one", not "it generated nothing" — the Apple system
    /// engine has no token counters to read — so it's omitted rather than printed as a false `0 tok`. Same
    /// rule the rate has always followed.
    static func statsFooter(_ stats: Stats, modelName: String) -> String {
        var parts = [modelName]
        if stats.genTokens > 0 {
            parts.append("\(stats.genTokens) tok")
        }
        if stats.tokensPerSecond > 0 {
            if stats.tokensPerSecond < 0.1 {
                // A very slow but positive decode rate must not be rounded into a false zero.
                parts.append("<0.1 tok/s")
            } else if stats.tokensPerSecond < 1 {
                parts.append(String(format: "%.1f tok/s", stats.tokensPerSecond))
            } else {
                parts.append(String(format: "%.0f tok/s", stats.tokensPerSecond))
            }
        }
        parts.append("stop: \(stats.stopReason.rawValue)")
        return parts.joined(separator: " · ")
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    /// Compact context count ("1,240 / 8K").
    static func context(_ used: Int, _ cap: Int) -> String {
        String(localized: "\(used.formatted()) / \(shortCount(cap))", bundle: .main)
    }

    static func shortCount(_ n: Int) -> String {
        if n >= 1000 { return "\(n / 1000)K" }
        return "\(n)"
    }

    static func shortCount(_ n: Int64) -> String {
        shortCount(Int(clamping: n))
    }

    /// Compact elapsed time ("42s", "3m 12s", "1h 04m").
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        if minutes > 0 { return String(format: "%dm %02ds", minutes, secs) }
        return String(localized: "\(secs)s", bundle: .main)
    }
}

extension String {
    /// The text the UI shows for a value that arrived as a plain `String`.
    ///
    /// SwiftUI only localizes what it can see: `Text("Save")` builds a `LocalizedStringKey`, but
    /// `Text(someString)` renders verbatim. The shared rows in Settings — `section`, `row`,
    /// `sliderRow`, `stepperRow` — take their title as a `String` and are called with literals, so
    /// the lookup has to happen here instead. Anything that is not a key in the string table (a
    /// version number, a model name, a user's own words) comes back unchanged.
    var localizedLabel: String {
        Bundle.main.localizedString(forKey: self, value: self, table: nil)
    }
}

extension LLMModel {
    /// The text the UI shows for `summary`.
    ///
    /// The stored summary is catalog metadata: it describes the weights and is kept verbatim so
    /// the catalog stays canonical. The card reads this instead, which looks the summary up as a
    /// localization key and falls back to the stored value — what a community model gets, since
    /// its summary comes from the Hub rather than from us.
    var displaySummary: String {
        summary.localizedLabel
    }
}
