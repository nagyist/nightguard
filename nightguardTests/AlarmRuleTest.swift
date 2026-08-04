//
//  AlarmRuleTest.swift
//  nightguardTests
//
//  Created by Codex on 10.04.26.
//

import XCTest
class AlarmRuleTest: XCTestCase {

    private let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)

    override func setUp() {
        super.setUp()
        clearAlarmSettings()
        AlarmRule.disableTransientLocalAudioSuppression()
        AlarmRule.resetProtectedDataFallbackStateForTesting()
    }

    override func tearDown() {
        clearAlarmSettings()
        AlarmRule.disableTransientLocalAudioSuppression()
        AlarmRule.resetProtectedDataFallbackStateForTesting()
        super.tearDown()
    }

    func testDetermineAlarmActivationByUsesCachedMinutesWhenProtectedDataUnavailable() {
        defaults?.set(true, forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.set(45, forKey: AlarmRule.minutesWithoutValues.key)
        AlarmRule.initializeSyncValues()

        defaults?.removeObject(forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.removeObject(forKey: AlarmRule.minutesWithoutValues.key)
        AlarmRule.protectedDataAvailabilityOverride = false

        let activation = AlarmRule.determineAlarmActivationBy(makeNightscoutData(minutesAgo: 35))

        XCTAssertNil(activation)
    }

    func testDetermineAlarmActivationByUsesCachedDisabledNoDataSettingWhenProtectedDataUnavailable() {
        defaults?.set(false, forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.set(20, forKey: AlarmRule.minutesWithoutValues.key)
        AlarmRule.initializeSyncValues()

        defaults?.removeObject(forKey: AlarmRule.noDataAlarmEnabled.key)
        defaults?.removeObject(forKey: AlarmRule.minutesWithoutValues.key)
        AlarmRule.protectedDataAvailabilityOverride = false

        let activation = AlarmRule.determineAlarmActivationBy(makeNightscoutData(minutesAgo: 40))

        XCTAssertNil(activation)
    }

    func testDetermineAlarmActivationByFallsBackToDefaultsWithoutCache() {
        AlarmRule.protectedDataAvailabilityOverride = false

        let activation = AlarmRule.determineAlarmActivationBy(makeNightscoutData(minutesAgo: 35))

        XCTAssertEqual(activation?.kind, .missedReadings)
    }

    func testDetermineAlarmActivationByIgnoresTransientLocalAudioSuppression() {
        AlarmRule.suppressTransientLocalAudio(seconds: 10)

        let activation = AlarmRule.determineAlarmActivationBy(makeNightscoutData(minutesAgo: 35))

        XCTAssertEqual(activation?.kind, .missedReadings)
    }

    func testTransientLocalAudioSuppressionCountsAsLocalSnoozeOnly() {
        AlarmRule.suppressTransientLocalAudio(seconds: 10)

        XCTAssertTrue(AlarmRule.isSnoozed())
        XCTAssertFalse(AlarmRule.isSnoozed(ignoreTransientLocalAudioSuppression: true))
        XCTAssertGreaterThan(AlarmRule.getRemainingTransientLocalAudioSnoozeSeconds(), 0)
        XCTAssertLessThanOrEqual(AlarmRule.getRemainingTransientLocalAudioSnoozeSeconds(), 10)
    }

    func testLocalAlarmSoundPlaybackRequiresActiveApplication() {
        XCTAssertTrue(AlarmSound.shouldAllowPlayback(applicationState: .active))
        XCTAssertFalse(AlarmSound.shouldAllowPlayback(applicationState: .inactive))
        XCTAssertFalse(AlarmSound.shouldAllowPlayback(applicationState: .background))
    }

    func testMainViewModelSuppressesLocalAlarmUntilForegroundRefreshCompletes() {
        XCTAssertFalse(
            MainViewModel.shouldPlayLocalAlarm(
                hasActiveAlarm: true,
                isAwaitingForegroundRefresh: true,
                applicationState: .active
            )
        )
    }

    func testMainViewModelAllowsConfirmedAlarmAfterForegroundRefresh() {
        XCTAssertTrue(
            MainViewModel.shouldPlayLocalAlarm(
                hasActiveAlarm: true,
                isAwaitingForegroundRefresh: false,
                applicationState: .active
            )
        )
    }

    func testMainViewModelRejectsLocalAlarmOutsideForeground() {
        XCTAssertFalse(
            MainViewModel.shouldPlayLocalAlarm(
                hasActiveAlarm: true,
                isAwaitingForegroundRefresh: false,
                applicationState: .background
            )
        )
    }

    private func makeNightscoutData(minutesAgo: Int) -> NightscoutData {
        let data = NightscoutData()
        data.sgv = "120"
        data.time = NSNumber(value: Date().addingTimeInterval(TimeInterval(-minutesAgo * 60)).timeIntervalSince1970 * 1000)
        return data
    }

    private func clearAlarmSettings() {
        let keys = [
            AlarmRule.noDataAlarmEnabled.key,
            AlarmRule.minutesWithoutValues.key,
            AlarmRule.snoozedUntilTimestamp.key
        ]

        for key in keys {
            defaults?.removeObject(forKey: key)
        }
    }
}
