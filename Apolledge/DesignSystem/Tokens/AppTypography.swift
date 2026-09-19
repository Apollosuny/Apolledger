//
//  AppTypography.swift
//  Apolledge
//
//  Created by Trung Trần on 1/9/26.
//

import SwiftUI

/// Font names are PostScript names, not file names — `Font.custom` silently falls back to the system font on a mismatch.
enum AppTypography {
    static let balance = Font.custom("Newsreader36pt-Light", size: 50)

    static let display = Font.custom("Newsreader36pt-Light", size: 36)

    static let month = Font.custom("Newsreader24pt-Regular", size: 23)

    static let brand = Font.custom("Newsreader24pt-Regular", size: 30)

    static let title = Font.custom("Geist-SemiBold", size: 22)

    static let row = Font.custom("Geist-Medium", size: 15)

    static let button = Font.custom("Geist-Medium", size: 15.5)

    static let body = Font.custom("Geist-Regular", size: 15)

    static let subtitle = Font.custom("Geist-Regular", size: 14)

    static let caption = Font.custom("Geist-Regular", size: 13.5)

    static let captionStrong = Font.custom("Geist-SemiBold", size: 13.5)

    static let link = Font.custom("Geist-Medium", size: 13.5)

    static let meta = Font.custom("Geist-Regular", size: 12)

    static let label = Font.custom("GeistMono-Regular", size: 10)

    static let amount = Font.custom("GeistMono-Medium", size: 14.5)
}
