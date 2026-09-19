//
//  AppMotion.swift
//  Apolledge
//

import SwiftUI

enum AppMotion {
    /// Design system: transitions are 220ms cubic-bezier(.2, .8, .2, 1).
    static let standard = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.22)

    /// Design system: pressed controls shrink to 0.975.
    static let pressedScale: CGFloat = 0.975
}
