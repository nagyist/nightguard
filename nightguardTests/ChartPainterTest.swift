//
//  ChartPainterTest.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 01.12.15.
//  Copyright © 2015 private. All rights reserved.
//

import XCTest

class ChartPainterTest: XCTestCase {

    let chartPainter : ChartPainter = ChartPainter(canvasWidth: 165, canvasHeight: 125)

    func testXMinAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 200, timestamp: 20000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 10000, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(chartPainter.minimumXValue, 10000)
    }
   
    func testMaxYDisplayValueGetsRecognized() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 200, timestamp: 20000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 150, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(chartPainter.maximumYValue, 150)
    }
    
    func testStretchedValueShouldBeStretchedToCanvasMinAndMaxWidth() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 200, timestamp: 20000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue : 20000, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)

        XCTAssertEqual(Int(chartPainter.stretchedXValue(10000)), 0)
        XCTAssertEqual(Int(chartPainter.stretchedXValue(20000)), chartPainter.canvasWidth)
    }
    
    func testXMaxAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 200, timestamp: 20000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 20000, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(chartPainter.maximumXValue, 20000)
    }
    
    func testYMaxAdjustementIsWorking() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 220, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 220, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(chartPainter.maximumYValue, 220)
    }
    
    func testYValue0IsDisplayedAtTheBottomOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 0, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 250, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(Int(chartPainter.calcYValue(0)), 171)
    }
    
    func testYValue200IsDisplayedAtTheTopOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 200, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 240, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(Int(chartPainter.calcYValue(200)), 0)
    }
    
    func testYValue300IsDisplayedAtTheTopOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 300, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-"), BloodSugar.init(value: 100, timestamp: 10000, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 350, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(Int(chartPainter.calcYValue(300)), 0)
    }
    
    func testYValue40IsDisplayedAtTheBottomOfTheCanvas() {
        chartPainter.adjustMinMaxXYCoordinates([[BloodSugar.init(value: 40, timestamp: 0, isMeteredBloodGlucoseValue: false, arrow: "-")]], maxYDisplayValue: 200, upperBoundNiceValue: 180, lowerBoundNiceValue: 80)
        XCTAssertEqual(Int(chartPainter.calcYValue(40)), chartPainter.canvasHeight - 30)
    }
    
    func testStretchedValue160ShouldBeStretchedToCanvasHeight() {
        XCTAssertEqual(Int(chartPainter.stretchedYValue(160 + chartPainter.minimumYValue)), chartPainter.canvasHeight - 30)
    }
    
    func testHalfHoursBetweenADayShiftAreCalculatedCorrectly() {

        let today = Date()
        let tomorrow = (Calendar.current as NSCalendar).date(
            byAdding: .day,
            value: 1,
            to: today,
            options: NSCalendar.Options(rawValue: 0))
            
        let minTimestamp : Double = today.timeIntervalSince1970 * 1000
        let maxTimestamp : Double = (tomorrow?.timeIntervalSince1970)! * 1000
        
        let hours = chartPainter.determineHoursBetween(minTimestamp, maxTimestamp: maxTimestamp)
        
        XCTAssertEqual(24, hours.count)
    }

    func testChartSelectionChoosesNearestBloodSugar() {
        let firstTimestamp = Date().addingTimeInterval(-600).timeIntervalSince1970 * 1000
        let secondTimestamp = Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000
        let first = BloodSugar(value: 100, timestamp: firstTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let second = BloodSugar(value: 140, timestamp: secondTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let scene = ChartScene(size: CGSize(width: 300, height: 200), newCanvasWidth: 600, useContrastfulColors: false, showYesterdaysBgs: false)

        scene.paintChart([[first, second], []], newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: false)
        scene.activateSelection(atSceneX: 0)

        XCTAssertEqual(scene.selectedBloodSugar?.timestamp, firstTimestamp)

        scene.moveSelection(toSceneX: 300)
        XCTAssertEqual(scene.selectedBloodSugar?.timestamp, secondTimestamp)
        scene.deactivateSelection()
    }

    func testChartSelectionIncludesTreatmentsNearSelectedBloodSugar() {
        let timestamp = Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000
        let glucose = BloodSugar(value: 120, timestamp: timestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let treatment = MealBolusTreatment(id: "selection-test", timestamp: timestamp + 60 * 1000, carbs: 30, insulin: 2)
        let previousTreatments = TreatmentsStream.singleton.treatments
        TreatmentsStream.singleton.treatments = [treatment]
        defer { TreatmentsStream.singleton.treatments = previousTreatments }

        let scene = ChartScene(size: CGSize(width: 300, height: 200), newCanvasWidth: 600, useContrastfulColors: false, showYesterdaysBgs: false)
        scene.paintChart([[glucose, BloodSugar(value: 130, timestamp: timestamp + 300 * 1000, isMeteredBloodGlucoseValue: false, arrow: "-")], []], newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: false)
        scene.activateSelection(atSceneX: 0)

        XCTAssertEqual(scene.selectedTreatments.count, 1)
        XCTAssertTrue(scene.selectedTreatments.first is MealBolusTreatment)
    }

    func testChartSelectionIgnoresPreviousDayValues() {
        let currentTimestamp = Date().addingTimeInterval(-300).timeIntervalSince1970 * 1000
        let previousDayTimestamp = Date().addingTimeInterval(-24 * 60 * 60).timeIntervalSince1970 * 1000
        let current = BloodSugar(value: 120, timestamp: currentTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let previousDay = BloodSugar(value: 220, timestamp: previousDayTimestamp, isMeteredBloodGlucoseValue: false, arrow: "-")
        let scene = ChartScene(size: CGSize(width: 300, height: 200), newCanvasWidth: 600, useContrastfulColors: false, showYesterdaysBgs: true)

        scene.paintChart([[current], [previousDay, BloodSugar(value: 230, timestamp: previousDayTimestamp + 300 * 1000, isMeteredBloodGlucoseValue: false, arrow: "-")]], newCanvasWidth: 600, maxYDisplayValue: 350, moveToLatestValue: false, displayDaysLegend: false, useConstrastfulColors: false, showYesterdaysBgs: true)
        scene.activateSelection(atSceneX: 0)

        XCTAssertEqual(scene.selectedBloodSugar?.timestamp, currentTimestamp)
    }
}
