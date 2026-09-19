//
//  AppColors.swift
//  Apolledge
//
//  Created by Trung Trần on 1/9/26.
//

import SwiftUI

enum AppColors {
    static let paper = Color("Paper")
    static let paperSecondary = Color("PaperSecondary")

    static let hairline = Color("Hairline")
    static let hairlineStrong = Color("HairlineStrong")

    static let ink = Color("Ink")
    static let inkSecondary = Color("InkSecondary")
    static let inkTertiary = Color("InkTertiary")

    static let income = Color("Income")
    static let expense = Color("Expense")

    /// Splash is always "paper on ink" regardless of color scheme, so these are fixed, non-adaptive values.
    enum Splash {
        static let background = Color("SplashBackground")
        static let foreground = Color("SplashForeground")
        static let accent = Color("SplashAccent")
        static let textSecondary = Color("SplashTextSecondary")
        static let textTertiary = Color("SplashTextTertiary")
        static let track = Color("SplashTrack")
    }
}
