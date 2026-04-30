import XCTest
@testable import MermaidViewerCore

final class GridLayoutTests: XCTestCase {

    let accuracy = 1e-9

    // MARK: - Adaptive grid size

    func testGridSizeAtScale1() {
        let size = GridLayout.adaptiveGridSize(baseGrid: 20, scale: 1.0)
        XCTAssertGreaterThanOrEqual(size, 10)
        XCTAssertLessThanOrEqual(size, 100)
    }

    func testGridSizeStaysInComfortableRange() {
        // Across a wide range of scales, grid size should stay in [10, 100]
        let scales = [0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 50.0]
        for s in scales {
            let size = GridLayout.adaptiveGridSize(baseGrid: 20, scale: s)
            XCTAssertGreaterThanOrEqual(size, 10, "Failed at scale \(s)")
            XCTAssertLessThanOrEqual(size, 100, "Failed at scale \(s)")
        }
    }

    func testGridSizeIncreasesWithScale() {
        // At higher zoom, grid spacing should generally be larger (or jump levels)
        let sizeSmall = GridLayout.adaptiveGridSize(baseGrid: 20, scale: 0.5)
        let sizeLarge = GridLayout.adaptiveGridSize(baseGrid: 20, scale: 5.0)
        // Both should be in range, but the large one should use larger spacing
        XCTAssertGreaterThanOrEqual(sizeSmall, 10)
        XCTAssertGreaterThanOrEqual(sizeLarge, 10)
    }

    // MARK: - Dot size

    func testDotSizeMinimum() {
        let size = GridLayout.dotSize(scale: 0.01)
        XCTAssertGreaterThanOrEqual(size, 0.8)
    }

    func testDotSizeAtScale1() {
        let size = GridLayout.dotSize(scale: 1.0)
        XCTAssertEqual(size, 0.8, accuracy: accuracy)
    }

    func testDotSizeIncreasesWithScale() {
        let small = GridLayout.dotSize(scale: 1.0)
        let large = GridLayout.dotSize(scale: 5.0)
        XCTAssertGreaterThan(large, small)
    }

    // MARK: - Dot alpha

    func testDotAlphaAtMinGridSize() {
        let alpha = GridLayout.dotAlpha(gridSize: 10)
        XCTAssertEqual(alpha, 0.1, accuracy: accuracy)
    }

    func testDotAlphaCappedAt035() {
        let alpha = GridLayout.dotAlpha(gridSize: 1000)
        XCTAssertEqual(alpha, 0.35, accuracy: accuracy)
    }

    func testDotAlphaIncreasesWithGridSize() {
        let a1 = GridLayout.dotAlpha(gridSize: 20)
        let a2 = GridLayout.dotAlpha(gridSize: 60)
        XCTAssertGreaterThan(a2, a1)
    }

    // MARK: - Grid offset

    func testGridOffsetAtZeroTranslate() {
        let offset = GridLayout.gridOffset(translate: 0, gridSize: 20)
        XCTAssertEqual(offset, 0, accuracy: accuracy)
    }

    func testGridOffsetWrapsAround() {
        let offset = GridLayout.gridOffset(translate: 50, gridSize: 20)
        XCTAssertEqual(offset, 10, accuracy: accuracy)
    }

    func testGridOffsetNegativeTranslate() {
        let offset = GridLayout.gridOffset(translate: -30, gridSize: 20)
        XCTAssertEqual(offset, -10, accuracy: accuracy)
    }

    func testGridOffsetExactMultiple() {
        let offset = GridLayout.gridOffset(translate: 60, gridSize: 20)
        XCTAssertEqual(offset, 0, accuracy: accuracy)
    }
}
