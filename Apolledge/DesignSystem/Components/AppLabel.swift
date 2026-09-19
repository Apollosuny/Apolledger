//
//  AppLabel.swift
//  Apolledge
//

import SwiftUI

extension View {
    /// Uppercase Geist Mono label (10pt, 0.14em tracking) used above fields and sections.
    func appLabelStyle() -> some View {
        font(AppTypography.label)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(AppColors.inkTertiary)
    }
}
