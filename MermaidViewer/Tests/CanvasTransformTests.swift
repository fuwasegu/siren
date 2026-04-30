import XCTest
@testable import MermaidViewerCore

final class CanvasTransformTests: XCTestCase {

    let accuracy = 1e-9

    // MARK: - Identity

    func testIdentity() {
        let t = CanvasTransform.identity
        XCTAssertEqual(t.translateX, 0)
        XCTAssertEqual(t.translateY, 0)
        XCTAssertEqual(t.scale, 1)
    }

    // MARK: - Scale clamping

    func testClampedScaleAtMinimum() {
        XCTAssertEqual(CanvasTransform.clampedScale(0.01), CanvasTransform.minScale)
    }

    func testClampedScaleAtMaximum() {
        XCTAssertEqual(CanvasTransform.clampedScale(100), CanvasTransform.maxScale)
    }

    func testClampedScalePassthrough() {
        XCTAssertEqual(CanvasTransform.clampedScale(1.5), 1.5)
    }

    func testClampedScaleNegativeBecomesMin() {
        XCTAssertEqual(CanvasTransform.clampedScale(-5), CanvasTransform.minScale)
    }

    // MARK: - Zoom at center: fixed-point invariant

    /// After zooming at point P, converting P from screen to content space
    /// must give the same content-space point before and after the zoom.
    func testZoomAtCenterKeepsPointFixed() {
        let initial = CanvasTransform(translateX: 100, translateY: 50, scale: 1.5)
        let cx = 400.0, cy = 300.0

        let before = initial.screenToContent(x: cx, y: cy)
        let zoomed = initial.zoomedAt(centerX: cx, centerY: cy, delta: -0.3)
        let after = zoomed.screenToContent(x: cx, y: cy)

        XCTAssertEqual(before.x, after.x, accuracy: accuracy)
        XCTAssertEqual(before.y, after.y, accuracy: accuracy)
    }

    func testZoomOutAtCenterKeepsPointFixed() {
        let initial = CanvasTransform(translateX: 200, translateY: 100, scale: 2.0)
        let cx = 500.0, cy = 400.0

        let before = initial.screenToContent(x: cx, y: cy)
        let zoomed = initial.zoomedAt(centerX: cx, centerY: cy, delta: 0.2)
        let after = zoomed.screenToContent(x: cx, y: cy)

        XCTAssertEqual(before.x, after.x, accuracy: accuracy)
        XCTAssertEqual(before.y, after.y, accuracy: accuracy)
    }

    /// Zooming at the origin (0,0) should not change translateX/Y
    /// because the origin is the transform-origin.
    func testZoomAtOriginDoesNotShift() {
        let initial = CanvasTransform(translateX: 0, translateY: 0, scale: 1.0)
        let zoomed = initial.zoomedAt(centerX: 0, centerY: 0, delta: -0.5)

        XCTAssertEqual(zoomed.translateX, 0, accuracy: accuracy)
        XCTAssertEqual(zoomed.translateY, 0, accuracy: accuracy)
        XCTAssertGreaterThan(zoomed.scale, 1.0)
    }

    func testZoomToAbsoluteScaleKeepsPointFixed() {
        let initial = CanvasTransform(translateX: 50, translateY: 30, scale: 1.0)
        let cx = 300.0, cy = 200.0

        let before = initial.screenToContent(x: cx, y: cy)
        let zoomed = initial.zoomedTo(centerX: cx, centerY: cy, newScale: 3.0)
        let after = zoomed.screenToContent(x: cx, y: cy)

        XCTAssertEqual(zoomed.scale, 3.0, accuracy: accuracy)
        XCTAssertEqual(before.x, after.x, accuracy: accuracy)
        XCTAssertEqual(before.y, after.y, accuracy: accuracy)
    }

    func testZoomInThenOutReturnsToOriginal() {
        let initial = CanvasTransform(translateX: 100, translateY: 80, scale: 1.0)
        let cx = 400.0, cy = 300.0

        let zoomed = initial.zoomedTo(centerX: cx, centerY: cy, newScale: 2.0)
        let restored = zoomed.zoomedTo(centerX: cx, centerY: cy, newScale: 1.0)

        XCTAssertEqual(restored.translateX, initial.translateX, accuracy: accuracy)
        XCTAssertEqual(restored.translateY, initial.translateY, accuracy: accuracy)
        XCTAssertEqual(restored.scale, initial.scale, accuracy: accuracy)
    }

    func testZoomDeltaZeroNoChange() {
        let initial = CanvasTransform(translateX: 100, translateY: 50, scale: 1.5)
        let zoomed = initial.zoomedAt(centerX: 200, centerY: 200, delta: 0)
        XCTAssertEqual(zoomed, initial)
    }

    func testZoomClampsToMinScale() {
        let initial = CanvasTransform(translateX: 0, translateY: 0, scale: 0.15)
        let zoomed = initial.zoomedAt(centerX: 100, centerY: 100, delta: 0.9)
        XCTAssertGreaterThanOrEqual(zoomed.scale, CanvasTransform.minScale)
    }

    func testZoomClampsToMaxScale() {
        let initial = CanvasTransform(translateX: 0, translateY: 0, scale: 9.5)
        let zoomed = initial.zoomedAt(centerX: 100, centerY: 100, delta: -0.9)
        XCTAssertLessThanOrEqual(zoomed.scale, CanvasTransform.maxScale)
    }

    // MARK: - Pan

    func testPanMovesTranslate() {
        let initial = CanvasTransform(translateX: 10, translateY: 20, scale: 1.0)
        let panned = initial.panned(dx: 30, dy: -10)

        XCTAssertEqual(panned.translateX, 40, accuracy: accuracy)
        XCTAssertEqual(panned.translateY, 10, accuracy: accuracy)
        XCTAssertEqual(panned.scale, 1.0)
    }

    func testPanDoesNotChangeScale() {
        let initial = CanvasTransform(translateX: 0, translateY: 0, scale: 2.5)
        let panned = initial.panned(dx: 100, dy: 200)
        XCTAssertEqual(panned.scale, 2.5)
    }

    func testPanZeroDeltaNoChange() {
        let initial = CanvasTransform(translateX: 50, translateY: 60, scale: 1.0)
        let panned = initial.panned(dx: 0, dy: 0)
        XCTAssertEqual(panned, initial)
    }

    // MARK: - Fit to view

    func testFitToViewCentersDiagram() {
        let t = CanvasTransform.fitting(
            diagramWidth: 400, diagramHeight: 300,
            viewportWidth: 800, viewportHeight: 600,
            padding: 0
        )

        // Diagram should be centered
        let centerContent = t.screenToContent(x: 400, y: 300)
        XCTAssertEqual(centerContent.x, 200, accuracy: accuracy)
        XCTAssertEqual(centerContent.y, 150, accuracy: accuracy)
    }

    func testFitToViewRespectsMaxScale() {
        // Tiny diagram in a large viewport — should not scale beyond maxFitScale
        let t = CanvasTransform.fitting(
            diagramWidth: 10, diagramHeight: 10,
            viewportWidth: 1000, viewportHeight: 1000,
            padding: 0, maxFitScale: 2
        )
        XCTAssertEqual(t.scale, 2.0, accuracy: accuracy)
    }

    func testFitToViewSmallViewportScalesDown() {
        let t = CanvasTransform.fitting(
            diagramWidth: 1000, diagramHeight: 800,
            viewportWidth: 400, viewportHeight: 300,
            padding: 80
        )
        XCTAssertLessThan(t.scale, 1.0)
        // The diagram should fit within the viewport
        let visible = t.visibleRect(viewportWidth: 400, viewportHeight: 300)
        // Content origin should be negative (diagram starts past the visible origin)
        // or the visible area should encompass the diagram
        XCTAssertLessThanOrEqual(visible.x, 0)
    }

    func testFitToViewWithZeroDiagramReturnsIdentity() {
        let t = CanvasTransform.fitting(
            diagramWidth: 0, diagramHeight: 0,
            viewportWidth: 800, viewportHeight: 600
        )
        XCTAssertEqual(t, .identity)
    }

    func testFitToViewWideDiagram() {
        // Very wide diagram: width is the constraining dimension
        let t = CanvasTransform.fitting(
            diagramWidth: 2000, diagramHeight: 100,
            viewportWidth: 800, viewportHeight: 600,
            padding: 0
        )
        XCTAssertEqual(t.scale, 0.4, accuracy: accuracy) // 800 / 2000
    }

    func testFitToViewTallDiagram() {
        // Very tall diagram: height is the constraining dimension
        let t = CanvasTransform.fitting(
            diagramWidth: 100, diagramHeight: 2000,
            viewportWidth: 800, viewportHeight: 600,
            padding: 0
        )
        XCTAssertEqual(t.scale, 0.3, accuracy: accuracy) // 600 / 2000
    }

    // MARK: - Screen ↔ Content mapping

    func testScreenToContentRoundtrip() {
        let t = CanvasTransform(translateX: 50, translateY: 30, scale: 2.0)
        let screenX = 250.0, screenY = 130.0

        let content = t.screenToContent(x: screenX, y: screenY)
        let back = t.contentToScreen(x: content.x, y: content.y)

        XCTAssertEqual(back.x, screenX, accuracy: accuracy)
        XCTAssertEqual(back.y, screenY, accuracy: accuracy)
    }

    func testContentToScreenRoundtrip() {
        let t = CanvasTransform(translateX: -100, translateY: 200, scale: 0.5)
        let contentX = 80.0, contentY = 60.0

        let screen = t.contentToScreen(x: contentX, y: contentY)
        let back = t.screenToContent(x: screen.x, y: screen.y)

        XCTAssertEqual(back.x, contentX, accuracy: accuracy)
        XCTAssertEqual(back.y, contentY, accuracy: accuracy)
    }

    func testScreenToContentAtIdentity() {
        let t = CanvasTransform.identity
        let result = t.screenToContent(x: 100, y: 200)
        XCTAssertEqual(result.x, 100)
        XCTAssertEqual(result.y, 200)
    }

    // MARK: - Visible rect

    func testVisibleRectAtIdentity() {
        let t = CanvasTransform.identity
        let r = t.visibleRect(viewportWidth: 800, viewportHeight: 600)
        XCTAssertEqual(r.x, 0, accuracy: accuracy)
        XCTAssertEqual(r.y, 0, accuracy: accuracy)
        XCTAssertEqual(r.width, 800, accuracy: accuracy)
        XCTAssertEqual(r.height, 600, accuracy: accuracy)
    }

    func testVisibleRectZoomedIn() {
        let t = CanvasTransform(translateX: 0, translateY: 0, scale: 2.0)
        let r = t.visibleRect(viewportWidth: 800, viewportHeight: 600)
        XCTAssertEqual(r.width, 400, accuracy: accuracy)
        XCTAssertEqual(r.height, 300, accuracy: accuracy)
    }

    func testVisibleRectPanned() {
        let t = CanvasTransform(translateX: -100, translateY: -50, scale: 1.0)
        let r = t.visibleRect(viewportWidth: 800, viewportHeight: 600)
        XCTAssertEqual(r.x, 100, accuracy: accuracy)
        XCTAssertEqual(r.y, 50, accuracy: accuracy)
    }

    // MARK: - CSS output

    func testScalePercent() {
        XCTAssertEqual(CanvasTransform(translateX: 0, translateY: 0, scale: 1.0).scalePercent, 100)
        XCTAssertEqual(CanvasTransform(translateX: 0, translateY: 0, scale: 0.5).scalePercent, 50)
        XCTAssertEqual(CanvasTransform(translateX: 0, translateY: 0, scale: 2.5).scalePercent, 250)
    }

    // MARK: - Compound operations

    func testPanThenZoomAtCenterPreservesPoint() {
        // Pan to some position, then zoom at a specific point.
        // The zoom center should remain fixed.
        var t = CanvasTransform.identity
        t = t.panned(dx: 200, dy: 150)

        let cx = 400.0, cy = 300.0
        let before = t.screenToContent(x: cx, y: cy)
        t = t.zoomedAt(centerX: cx, centerY: cy, delta: -0.5)
        let after = t.screenToContent(x: cx, y: cy)

        XCTAssertEqual(before.x, after.x, accuracy: accuracy)
        XCTAssertEqual(before.y, after.y, accuracy: accuracy)
    }

    func testMultipleZoomStepsKeepPointFixed() {
        // Simulate multiple small zoom increments (like trackpad gesture).
        var t = CanvasTransform(translateX: 100, translateY: 80, scale: 1.0)
        let cx = 350.0, cy = 250.0

        let contentBefore = t.screenToContent(x: cx, y: cy)

        // 10 incremental zoom steps
        for _ in 0..<10 {
            t = t.zoomedAt(centerX: cx, centerY: cy, delta: -0.05)
        }

        let contentAfter = t.screenToContent(x: cx, y: cy)
        XCTAssertEqual(contentBefore.x, contentAfter.x, accuracy: 1e-6)
        XCTAssertEqual(contentBefore.y, contentAfter.y, accuracy: 1e-6)
    }
}
