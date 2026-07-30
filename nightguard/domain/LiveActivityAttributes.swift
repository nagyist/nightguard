//
//  LiveActivityAttributes.swift
//  nightguard
//
//  Created by Gemini CLI.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct NightguardActivityAttributes: ActivityAttributes {
    struct GlucoseSample: Codable, Hashable {
        let value: Double
        let timestamp: TimeInterval
    }

    public struct ContentState: Codable, Hashable {
        var sgv: String
        var delta: String
        var trendArrow: String
        var date: Date
        var bgDelta: Double
        var sgvColorRed: Double
        var sgvColorGreen: Double
        var sgvColorBlue: Double
        var iob: String
        var cob: String
        var glucoseSamples: [GlucoseSample]
        var lowerTarget: Double
        var upperTarget: Double

        init(
            sgv: String,
            delta: String,
            trendArrow: String,
            date: Date,
            bgDelta: Double,
            sgvColorRed: Double,
            sgvColorGreen: Double,
            sgvColorBlue: Double,
            iob: String,
            cob: String,
            glucoseSamples: [GlucoseSample] = [],
            lowerTarget: Double = 80,
            upperTarget: Double = 180
        ) {
            self.sgv = sgv
            self.delta = delta
            self.trendArrow = trendArrow
            self.date = date
            self.bgDelta = bgDelta
            self.sgvColorRed = sgvColorRed
            self.sgvColorGreen = sgvColorGreen
            self.sgvColorBlue = sgvColorBlue
            self.iob = iob
            self.cob = cob
            self.glucoseSamples = glucoseSamples
            self.lowerTarget = lowerTarget
            self.upperTarget = upperTarget
        }

        private enum CodingKeys: String, CodingKey {
            case sgv
            case delta
            case trendArrow
            case date
            case bgDelta
            case sgvColorRed
            case sgvColorGreen
            case sgvColorBlue
            case iob
            case cob
            case glucoseSamples
            case lowerTarget
            case upperTarget
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sgv = try container.decode(String.self, forKey: .sgv)
            delta = try container.decode(String.self, forKey: .delta)
            trendArrow = try container.decode(String.self, forKey: .trendArrow)
            date = try container.decode(Date.self, forKey: .date)
            bgDelta = try container.decode(Double.self, forKey: .bgDelta)
            sgvColorRed = try container.decode(Double.self, forKey: .sgvColorRed)
            sgvColorGreen = try container.decode(Double.self, forKey: .sgvColorGreen)
            sgvColorBlue = try container.decode(Double.self, forKey: .sgvColorBlue)
            iob = try container.decode(String.self, forKey: .iob)
            cob = try container.decode(String.self, forKey: .cob)
            glucoseSamples = try container.decodeIfPresent([GlucoseSample].self, forKey: .glucoseSamples) ?? []
            lowerTarget = try container.decodeIfPresent(Double.self, forKey: .lowerTarget) ?? 80
            upperTarget = try container.decodeIfPresent(Double.self, forKey: .upperTarget) ?? 180
        }
    }

    var startedAt: Date

    init(startedAt: Date = Date()) {
        self.startedAt = startedAt
    }
}
#endif
