//
//  NightguardLiveActivity.swift
//  nightguard Widget Extension
//
//  Created by Gemini CLI.
//

import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct NightguardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightguardActivityAttributes.self) { context in
            // Lock screen/banner UI
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(context.state.sgv)
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text(context.state.trendArrow)
                                .font(.title)
                            Text(context.state.delta)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        Text(context.state.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !context.state.glucoseSamples.isEmpty {
                    GlucoseSparkline(
                        samples: context.state.glucoseSamples,
                        lowerTarget: context.state.lowerTarget,
                        upperTarget: context.state.upperTarget,
                        lineColor: glucoseColor(for: context.state)
                    )
                    .frame(minWidth: 100, maxWidth: .infinity)
                    .frame(height: 64)
                }
            }
            .padding()
            .activityBackgroundTint(nil)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .center) {
                        Text(context.state.sgv)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
                    }
                    .padding(.leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 2) {
                            Text(context.state.delta)
                                .font(.headline)
                                .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
                            Text(context.state.trendArrow)
                                .font(.title2)
                        }
                        if !context.state.glucoseSamples.isEmpty {
                            GlucoseSparkline(
                                samples: context.state.glucoseSamples,
                                lowerTarget: context.state.lowerTarget,
                                upperTarget: context.state.upperTarget,
                                lineColor: glucoseColor(for: context.state)
                            )
                            .frame(width: 110, height: 40)
                        }
                    }
                    .padding(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 0) {
                        HStack {
                            if !context.state.iob.isEmpty {
                                Text("IOB: \(context.state.iob)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !context.state.cob.isEmpty {
                                if !context.state.iob.isEmpty {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                }
                                Text("COB: \(context.state.cob)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Spacer()
                            Text(context.state.date, style: .relative)
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                            Text(" ago")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            } compactLeading: {
                Text(context.state.sgv)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text(context.state.trendArrow)
                    Text(context.state.delta)
                }
                .font(.caption)
                .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
            } minimal: {
                Text(context.state.sgv)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
            }
            .widgetURL(URL(string: "nightguard://open"))
            .keylineTint(Color(red: context.state.sgvColorRed, green: context.state.sgvColorGreen, blue: context.state.sgvColorBlue))
        }
    }

    private func glucoseColor(for state: NightguardActivityAttributes.ContentState) -> Color {
        Color(
            red: state.sgvColorRed,
            green: state.sgvColorGreen,
            blue: state.sgvColorBlue
        )
    }
}

@available(iOS 16.1, *)
private struct GlucoseSparkline: View {
    private let displayedDuration: TimeInterval = 60 * 60 * 1000
    private let maximumContinuousGap: TimeInterval = 15 * 60 * 1000

    let samples: [NightguardActivityAttributes.GlucoseSample]
    let lowerTarget: Double
    let upperTarget: Double
    let lineColor: Color

    var body: some View {
        GeometryReader { geometry in
            let yAxisWidth: CGFloat = 24
            let plotRect = CGRect(
                x: yAxisWidth + 4,
                y: 3,
                width: max(geometry.size.width - yAxisWidth - 4, 1),
                height: max(geometry.size.height - 6, 1)
            )

            ZStack {
                targetBandPath(in: plotRect)
                    .fill(Color.primary.opacity(0.08))

                glucosePath(in: plotRect)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                ForEach(orderedSamples.indices, id: \.self) { index in
                    let sample = orderedSamples[index]
                    Circle()
                        .fill(lineColor)
                        .frame(width: 6, height: 6)
                        .position(point(for: sample, in: plotRect))
                }

                if let sampleValueBounds {
                    Text(axisLabel(for: sampleValueBounds.upperBound))
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .position(
                            x: yAxisWidth / 2,
                            y: yPosition(for: sampleValueBounds.upperBound, in: plotRect)
                        )

                    Text(axisLabel(for: sampleValueBounds.lowerBound))
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .position(
                            x: yAxisWidth / 2,
                            y: yPosition(for: sampleValueBounds.lowerBound, in: plotRect)
                        )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var orderedSamples: [NightguardActivityAttributes.GlucoseSample] {
        samples.sorted { $0.timestamp < $1.timestamp }
    }

    private var valueRange: ClosedRange<Double> {
        guard let minimum = orderedSamples.map(\.value).min(),
              let maximum = orderedSamples.map(\.value).max() else {
            let normalizedLowerTarget = min(lowerTarget, upperTarget)
            let normalizedUpperTarget = max(lowerTarget, upperTarget)
            return normalizedLowerTarget...normalizedUpperTarget
        }

        return minimum...maximum
    }

    private var sampleValueBounds: ClosedRange<Double>? {
        guard let minimum = orderedSamples.map(\.value).min(),
              let maximum = orderedSamples.map(\.value).max() else {
            return nil
        }
        return minimum...maximum
    }

    private var timeRange: ClosedRange<TimeInterval> {
        let latestTimestamp = orderedSamples.last?.timestamp ?? 0
        return (latestTimestamp - displayedDuration)...latestTimestamp
    }

    private func point(
        for sample: NightguardActivityAttributes.GlucoseSample,
        in rect: CGRect
    ) -> CGPoint {
        let timeSpan = max(timeRange.upperBound - timeRange.lowerBound, 1)
        let valueSpan = max(valueRange.upperBound - valueRange.lowerBound, 1)
        let relativeX = ((sample.timestamp - timeRange.lowerBound) / timeSpan).clamped(to: 0...1)
        let relativeY = ((sample.value - valueRange.lowerBound) / valueSpan).clamped(to: 0...1)

        return CGPoint(
            x: rect.minX + rect.width * relativeX,
            y: rect.maxY - rect.height * relativeY
        )
    }

    private func yPosition(for value: Double, in rect: CGRect) -> CGFloat {
        let valueSpan = max(valueRange.upperBound - valueRange.lowerBound, 1)
        let relativeY = ((value - valueRange.lowerBound) / valueSpan).clamped(to: 0...1)
        return rect.maxY - rect.height * relativeY
    }

    private func axisLabel(for value: Double) -> String {
        String(Int(value.rounded()))
    }

    private func glucosePath(in rect: CGRect) -> Path {
        Path { path in
            var previousSample: NightguardActivityAttributes.GlucoseSample?

            for sample in orderedSamples {
                let samplePoint = point(for: sample, in: rect)
                if let previousSample,
                   sample.timestamp - previousSample.timestamp <= maximumContinuousGap {
                    path.addLine(to: samplePoint)
                } else {
                    path.move(to: samplePoint)
                }
                previousSample = sample
            }
        }
    }

    private func targetBandPath(in rect: CGRect) -> Path {
        let normalizedLowerTarget = min(lowerTarget, upperTarget)
        let normalizedUpperTarget = max(lowerTarget, upperTarget)
        let lowerPoint = point(
            for: NightguardActivityAttributes.GlucoseSample(
                value: normalizedLowerTarget,
                timestamp: timeRange.lowerBound
            ),
            in: rect
        )
        let upperPoint = point(
            for: NightguardActivityAttributes.GlucoseSample(
                value: normalizedUpperTarget,
                timestamp: timeRange.lowerBound
            ),
            in: rect
        )

        return Path(
            CGRect(
                x: rect.minX,
                y: upperPoint.y,
                width: rect.width,
                height: max(lowerPoint.y - upperPoint.y, 0)
            )
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#endif
