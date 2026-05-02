//
//  TimeRulerView.swift
//  Feature
//
//  Tick marks at every 1s with second-count labels every 5s. Drawn
//  with `Canvas` so we get one draw call regardless of timeline
//  length — `ForEach` of 60+ tick views was bogging down ScrollView
//  recycling at long durations.
//

import SwiftUI
import Core

struct TimeRulerView: View {
    let totalSeconds: Double
    let pixelsPerSecond: CGFloat

    var body: some View {
        Canvas { context, size in
            let secondCount = Int(ceil(totalSeconds))
            for second in 0...secondCount {
                let x = CGFloat(second) * pixelsPerSecond
                let isLabelTick = second.isMultiple(of: 5)
                let tickHeight: CGFloat = isLabelTick ? 12 : 6
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: tickHeight))
                }
                context.stroke(
                    path,
                    with: .color(isLabelTick ? VRollTheme.textSecondary : VRollTheme.textTertiary),
                    lineWidth: 1
                )

                if isLabelTick {
                    let label = Text("\(second)s")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(VRollTheme.textSecondary)
                    context.draw(label, at: CGPoint(x: x, y: 18), anchor: .center)
                }
            }
        }
        .frame(width: CGFloat(totalSeconds) * pixelsPerSecond, height: 26)
    }
}
