// SPDX-License-Identifier: MIT

import SwiftUI
import AppUI
import LLMCore

/// Hardware-fit badge (DESIGN §2.5 / §4). A colored dot + one-line verdict, reusing `Theme.fit*`
/// colors + `DotLabelStyle`. The label text *is* the VoiceOver label (DESIGN §4), so no model of the
/// world is hidden behind an icon.
struct LLMFitBadge: View {
    let presentation: ModelManager.FitPresentation

    private var color: Color {
        switch presentation {
        case .comfortable: Theme.fitGreen
        case .tight, .experimental: Theme.fitAmber
        case .unsupported: Theme.fitGray
        }
    }

    private var text: String {
        switch presentation {
        case .comfortable: String(localized: "Runs great", bundle: .main)
        case let .tight(maxContext): String(localized: "Tight · up to \(Format.shortCount(maxContext)) ctx", bundle: .main)
        case .experimental: String(localized: "Experimental · may be interrupted", bundle: .main)
        case .unsupported: String(localized: "High memory · may fail", bundle: .main)
        }
    }

    var body: some View {
        Label {
            Text(text).font(.caption2.weight(.medium)).foregroundStyle(color)
        } icon: {
            // A Circle() shape ignores DotLabelStyle's font-based sizing (which only sizes SF Symbols),
            // so pin it to a small dot explicitly — otherwise it expands to fill the row.
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .labelStyle(DotLabelStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

#if DEBUG
#Preview("Fit badges") {
    VStack(alignment: .leading, spacing: 12) {
        LLMFitBadge(presentation: .comfortable)
        LLMFitBadge(presentation: .tight(maxContext: 4096))
        LLMFitBadge(presentation: .experimental)
        LLMFitBadge(presentation: .unsupported)
    }
    .padding()
    .background(Theme.bg)
}
#endif
