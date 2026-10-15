import XCTest
import CoreMedia
@testable import SplitClip

final class SegmentPlannerTests: XCTestCase {
    private func seconds(_ value: Double) -> CMTime {
        CMTime(seconds: value, preferredTimescale: 600)
    }

    func testShortVideoIsSingleSegment() {
        let ranges = SegmentPlanner.plan(duration: seconds(100), maxLength: seconds(115))
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].start, .zero)
        XCTAssertEqual(ranges[0].end, seconds(100))
    }

    func testSplitsEvenlyAndStaysUnderLimit() {
        let duration = seconds(300)
        let limit = seconds(115)
        let ranges = SegmentPlanner.plan(duration: duration, maxLength: limit)

        XCTAssertEqual(ranges.count, 3)
        for range in ranges {
            XCTAssertLessThanOrEqual(range.duration.seconds, limit.seconds)
            XCTAssertEqual(range.duration.seconds, 100, accuracy: 0.01)
        }
    }

    func testSegmentsAreContiguousAndCoverWholeVideo() {
        // 30fps系でよくある端数のある長さ（timescale も 600 ではない）
        let duration = CMTime(value: 7_654_321, timescale: 30_000)
        let ranges = SegmentPlanner.plan(duration: duration, maxLength: seconds(115))

        XCTAssertEqual(ranges.count, 3)
        XCTAssertEqual(ranges.first?.start, .zero)
        XCTAssertEqual(ranges.last?.end, duration)
        for (a, b) in zip(ranges, ranges.dropFirst()) {
            XCTAssertEqual(a.end, b.start)
        }
    }

    func testExactMultipleOfLimit() {
        let ranges = SegmentPlanner.plan(duration: seconds(230), maxLength: seconds(115))
        XCTAssertEqual(ranges.count, 2)
    }

    func testInvalidInputReturnsEmpty() {
        XCTAssertTrue(SegmentPlanner.plan(duration: .zero, maxLength: seconds(115)).isEmpty)
        XCTAssertTrue(SegmentPlanner.plan(duration: .invalid, maxLength: seconds(115)).isEmpty)
        XCTAssertTrue(SegmentPlanner.plan(duration: seconds(10), maxLength: .zero).isEmpty)
    }

    func testTimeFormat() {
        XCTAssertEqual(TimeFormat.japanese(seconds: 115), "1分55秒")
        XCTAssertEqual(TimeFormat.japanese(seconds: 120), "2分")
        XCTAssertEqual(TimeFormat.japanese(seconds: 45), "45秒")
    }
}
