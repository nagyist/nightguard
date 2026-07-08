//
//  LiveActivityManager.swift
//  nightguard
//
//  Created by Gemini CLI.
//

import Foundation
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

class LiveActivityManager {
    static let shared = LiveActivityManager()

    struct UpdateResult {
        let activityCount: Int
        let updatedActivityCount: Int
        let endedExpiredActivityCount: Int
        let startedActivityCount: Int
        let message: String

        var didUpdateAnyActivity: Bool {
            updatedActivityCount > 0
        }

        var didChangeAnyActivity: Bool {
            updatedActivityCount > 0 || endedExpiredActivityCount > 0 || startedActivityCount > 0
        }
    }

    private let maximumLiveActivityDuration: TimeInterval = 8 * 60 * 60
    
    private init() {}
    
    func startOrUpdateActivity(sgv: String, delta: String, trendArrow: String, date: Date, bgDelta: Double, sgvColor: UIColor, iob: String, cob: String) {
        #if canImport(ActivityKit)
        // Live Activities are only available on iOS 16.1+
        guard #available(iOS 16.1, *) else { return }
        
        let contentState = makeContentState(
            sgv: sgv,
            delta: delta,
            trendArrow: trendArrow,
            date: date,
            bgDelta: bgDelta,
            sgvColor: sgvColor,
            iob: iob,
            cob: cob
        )

        Task {
            let result = await refreshActivities(with: contentState, allowStartingNewActivity: true)
            if !result.didChangeAnyActivity {
                AppLogger.singleton.warning("Foreground Live Activity update result: \(result.message)", category: .backgroundUpdates)
            }
        }
        #endif
    }

    @available(iOS 16.1, *)
    func refreshActivitiesForBackgroundUpdate(with nightscoutData: NightscoutData) async -> UpdateResult {
        #if canImport(ActivityKit)
        let contentState = makeContentState(from: NightguardDisplaySnapshot.make(from: nightscoutData))
        return await refreshActivities(with: contentState, allowStartingNewActivity: true)
        #else
        return UpdateResult(
            activityCount: 0,
            updatedActivityCount: 0,
            endedExpiredActivityCount: 0,
            startedActivityCount: 0,
            message: "ActivityKit unavailable"
        )
        #endif
    }

    @available(iOS 16.1, *)
    func updateExistingActivities(with nightscoutData: NightscoutData) async -> UpdateResult {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return UpdateResult(
                activityCount: 0,
                updatedActivityCount: 0,
                endedExpiredActivityCount: 0,
                startedActivityCount: 0,
                message: "Live Activities are disabled in system settings"
            )
        }

        guard PurchaseManager.shared.hasProFeatureAccess else {
            return UpdateResult(
                activityCount: Activity<NightguardActivityAttributes>.activities.count,
                updatedActivityCount: 0,
                endedExpiredActivityCount: 0,
                startedActivityCount: 0,
                message: "Pro access unavailable; skipped background Live Activity update"
            )
        }

        let activities = Activity<NightguardActivityAttributes>.activities
        guard !activities.isEmpty else {
            return UpdateResult(
                activityCount: 0,
                updatedActivityCount: 0,
                endedExpiredActivityCount: 0,
                startedActivityCount: 0,
                message: "No existing Live Activities found"
            )
        }

        let contentState = makeContentState(from: NightguardDisplaySnapshot.make(from: nightscoutData))
        var updatedActivityCount = 0
        for activity in activities {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: contentState)
            }
            updatedActivityCount += 1
        }

        return UpdateResult(
            activityCount: activities.count,
            updatedActivityCount: updatedActivityCount,
            endedExpiredActivityCount: 0,
            startedActivityCount: 0,
            message: "Updated \(updatedActivityCount) of \(activities.count) Live Activities"
        )
        #else
        return UpdateResult(
            activityCount: 0,
            updatedActivityCount: 0,
            endedExpiredActivityCount: 0,
            startedActivityCount: 0,
            message: "ActivityKit unavailable"
        )
        #endif
    }

    func update(with nightscoutData: NightscoutData) {
        #if os(iOS)
        NightscoutDataRepository.singleton.storeLatestDisplaySnapshot(from: nightscoutData)
        let displayValues = makeDisplayValues(from: nightscoutData)

        startOrUpdateActivity(
            sgv: displayValues.sgv,
            delta: displayValues.delta,
            trendArrow: displayValues.trendArrow,
            date: displayValues.date,
            bgDelta: displayValues.bgDelta,
            sgvColor: displayValues.sgvColor,
            iob: displayValues.iob,
            cob: displayValues.cob
        )
        #endif
    }
    
    func endActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        
        Task {
            for activity in Activity<NightguardActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private func refreshActivities(
        with contentState: NightguardActivityAttributes.ContentState,
        allowStartingNewActivity: Bool
    ) async -> UpdateResult {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return UpdateResult(
                activityCount: 0,
                updatedActivityCount: 0,
                endedExpiredActivityCount: 0,
                startedActivityCount: 0,
                message: "Live Activities are disabled in system settings"
            )
        }

        guard PurchaseManager.shared.hasProFeatureAccess else {
            let activityCount = Activity<NightguardActivityAttributes>.activities.count
            for activity in Activity<NightguardActivityAttributes>.activities {
                await end(activity)
            }
            return UpdateResult(
                activityCount: activityCount,
                updatedActivityCount: 0,
                endedExpiredActivityCount: activityCount,
                startedActivityCount: 0,
                message: "Pro access unavailable; ended \(activityCount) Live Activities"
            )
        }

        let now = Date()
        let activities = Activity<NightguardActivityAttributes>.activities
        var endedExpiredActivityCount = 0
        var updatedActivityCount = 0

        for activity in activities {
            if isExpired(activity, now: now) {
                await end(activity)
                endedExpiredActivityCount += 1
            } else {
                await update(activity, with: contentState)
                updatedActivityCount += 1
            }
        }

        var startedActivityCount = 0
        if allowStartingNewActivity && updatedActivityCount == 0 {
            startedActivityCount = startActivity(with: contentState, startedAt: now) ? 1 : 0
        }

        let message = "activities=\(activities.count), endedExpired=\(endedExpiredActivityCount), updated=\(updatedActivityCount), started=\(startedActivityCount)"
        return UpdateResult(
            activityCount: activities.count,
            updatedActivityCount: updatedActivityCount,
            endedExpiredActivityCount: endedExpiredActivityCount,
            startedActivityCount: startedActivityCount,
            message: message
        )
    }

    @available(iOS 16.1, *)
    private func isExpired(_ activity: Activity<NightguardActivityAttributes>, now: Date) -> Bool {
        now.timeIntervalSince(activity.attributes.startedAt) >= maximumLiveActivityDuration
    }

    @available(iOS 16.1, *)
    private func update(
        _ activity: Activity<NightguardActivityAttributes>,
        with contentState: NightguardActivityAttributes.ContentState
    ) async {
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: contentState, staleDate: nil)
            await activity.update(content)
        } else {
            await activity.update(using: contentState)
        }
    }

    @available(iOS 16.1, *)
    private func end(_ activity: Activity<NightguardActivityAttributes>) async {
        if #available(iOS 16.2, *) {
            await activity.end(nil, dismissalPolicy: .immediate)
        } else {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    @available(iOS 16.1, *)
    private func startActivity(with contentState: NightguardActivityAttributes.ContentState, startedAt: Date) -> Bool {
        let attributes = NightguardActivityAttributes(startedAt: startedAt)
        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: nil)
                let _ = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } else {
                let _ = try Activity.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            }
            return true
        } catch {
            AppLogger.singleton.error("Error starting Live Activity: \(error.localizedDescription)", category: .backgroundUpdates)
            return false
        }
    }

    @available(iOS 16.1, *)
    private func makeContentState(from nightscoutData: NightscoutData) -> NightguardActivityAttributes.ContentState {
        makeContentState(from: NightguardDisplaySnapshot.make(from: nightscoutData))
    }

    @available(iOS 16.1, *)
    private func makeContentState(from snapshot: NightguardDisplaySnapshot) -> NightguardActivityAttributes.ContentState {
        NightguardActivityAttributes.ContentState(
            sgv: snapshot.sgv,
            delta: snapshot.bgdeltaString,
            trendArrow: snapshot.bgdeltaArrow,
            date: snapshot.date,
            bgDelta: snapshot.bgdelta,
            sgvColorRed: snapshot.sgvColorRed,
            sgvColorGreen: snapshot.sgvColorGreen,
            sgvColorBlue: snapshot.sgvColorBlue,
            iob: snapshot.iob,
            cob: snapshot.cob
        )
    }

    @available(iOS 16.1, *)
    private func makeContentState(
        sgv: String,
        delta: String,
        trendArrow: String,
        date: Date,
        bgDelta: Double,
        sgvColor: UIColor,
        iob: String,
        cob: String
    ) -> NightguardActivityAttributes.ContentState {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        sgvColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return NightguardActivityAttributes.ContentState(
            sgv: sgv,
            delta: delta,
            trendArrow: trendArrow,
            date: date,
            bgDelta: bgDelta,
            sgvColorRed: Double(red),
            sgvColorGreen: Double(green),
            sgvColorBlue: Double(blue),
            iob: iob,
            cob: cob
        )
    }
    #endif

    private func makeDisplayValues(from nightscoutData: NightscoutData) -> (
        sgv: String,
        delta: String,
        trendArrow: String,
        date: Date,
        bgDelta: Double,
        sgvColor: UIColor,
        iob: String,
        cob: String
    ) {
        let sgv = UnitsConverter.mgdlToDisplayUnits(nightscoutData.sgv)
        return (
            sgv: sgv,
            delta: UnitsConverter.mgdlToDisplayUnitsWithSign("\(nightscoutData.bgdelta)"),
            trendArrow: nightscoutData.bgdeltaArrow,
            date: Date(timeIntervalSince1970: Double(nightscoutData.time.int64Value / 1000)),
            bgDelta: Double(nightscoutData.bgdelta),
            sgvColor: UIColorChanger.getBgColor(sgv),
            iob: nightscoutData.iob,
            cob: nightscoutData.cob
        )
    }
}
