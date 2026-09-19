//
//  BrandMark.swift
//  Apolledge
//

import SwiftUI

/// The Apolledge mark: three nested half-arcs on a baseline. Outer arc is always green.
struct BrandMark: View {
    var width: CGFloat = 56
    var lineWidth: CGFloat = 3
    var accent: Color = AppColors.income
    var foreground: Color = AppColors.ink

    /// Arc diameters relative to the outer arc, taken from the design (56 / 37 / 20).
    private static let innerRatios: [CGFloat] = [37.0 / 56.0, 20.0 / 56.0]

    var body: some View {
        ZStack(alignment: .bottom) {
            HalfArc(lineWidth: lineWidth)
                .stroke(accent, lineWidth: lineWidth)
                .frame(width: width, height: width / 2)

            ForEach(Self.innerRatios, id: \.self) { ratio in
                HalfArc(lineWidth: lineWidth)
                    .stroke(foreground, lineWidth: lineWidth)
                    .frame(width: width * ratio, height: width * ratio / 2)
            }

            Rectangle()
                .fill(foreground)
                .frame(width: width, height: lineWidth * 0.87)
        }
        .frame(width: width, height: width / 2, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// Upper half-circle whose stroke stays inside the frame, matching CSS `border` on a border-box.
private struct HalfArc: Shape {
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2 - lineWidth / 2
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}

#Preview {
    VStack(spacing: 32) {
        BrandMark()
        BrandMark(width: 30, lineWidth: 1.8)
    }
    .padding()
    .background(AppColors.paper)
}
