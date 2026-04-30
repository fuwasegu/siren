import XCTest
@testable import MermaidViewerCore

final class MinimapLayoutTests: XCTestCase {

    let accuracy = 1e-9

    // MARK: - Basic geometry

    func testThumbnailFitsWithinMinimap() {
        let layout = MinimapLayout(diagramWidth: 500, diagramHeight: 400)
        XCTAssertLessThanOrEqual(layout.thumbnailWidth, layout.minimapWidth + accuracy)
        XCTAssertLessThanOrEqual(layout.thumbnailHeight, layout.minimapHeight + accuracy)
    }

    func testThumbnailIsCentered() {
        let layout = MinimapLayout(diagramWidth: 500, diagramHeight: 400)

        let centerX = layout.thumbnailOriginX + layout.thumbnailWidth / 2
        let centerY = layout.thumbnailOriginY + layout.thumbnailHeight / 2

        XCTAssertEqual(centerX, layout.minimapWidth / 2, accuracy: accuracy)
        XCTAssertEqual(centerY, layout.minimapHeight / 2, accuracy: accuracy)
    }

    func testDiagramRectInsideThumbnail() {
        let layout = MinimapLayout(diagramWidth: 500, diagramHeight: 400, padding: 20)

        XCTAssertGreaterThanOrEqual(layout.diagramRectX, layout.thumbnailOriginX)
        XCTAssertGreaterThanOrEqual(layout.diagramRectY, layout.thumbnailOriginY)
        XCTAssertLessThanOrEqual(
            layout.diagramRectX + layout.diagramRectWidth,
            layout.thumbnailOriginX + layout.thumbnailWidth + accuracy
        )
        XCTAssertLessThanOrEqual(
            layout.diagramRectY + layout.diagramRectHeight,
            layout.thumbnailOriginY + layout.thumbnailHeight + accuracy
        )
    }

    func testContentSizeIncludesPadding() {
        let layout = MinimapLayout(diagramWidth: 300, diagramHeight: 200, padding: 20)
        XCTAssertEqual(layout.contentWidth, 340, accuracy: accuracy)
        XCTAssertEqual(layout.contentHeight, 240, accuracy: accuracy)
    }

    func testZeroPaddingDiagramFillsThumbnail() {
        let layout = MinimapLayout(diagramWidth: 500, diagramHeight: 400, padding: 0)
        XCTAssertEqual(layout.diagramRectX, layout.thumbnailOriginX, accuracy: accuracy)
        XCTAssertEqual(layout.diagramRectY, layout.thumbnailOriginY, accuracy: accuracy)
        XCTAssertEqual(layout.diagramRectWidth, layout.thumbnailWidth, accuracy: accuracy)
        XCTAssertEqual(layout.diagramRectHeight, layout.thumbnailHeight, accuracy: accuracy)
    }

    // MARK: - Minimap scale

    func testMinimapScaleWideDiagram() {
        // Wide diagram: width is constraining
        let layout = MinimapLayout(minimapWidth: 160, minimapHeight: 100,
                                   diagramWidth: 1000, diagramHeight: 100, padding: 0)
        let expectedScale = 160.0 / 1000.0
        XCTAssertEqual(layout.minimapScale, expectedScale, accuracy: accuracy)
    }

    func testMinimapScaleTallDiagram() {
        // Tall diagram: height is constraining
        let layout = MinimapLayout(minimapWidth: 160, minimapHeight: 100,
                                   diagramWidth: 100, diagramHeight: 1000, padding: 0)
        let expectedScale = 100.0 / 1000.0
        XCTAssertEqual(layout.minimapScale, expectedScale, accuracy: accuracy)
    }

    // MARK: - Viewport rect

    func testViewportAtIdentityCoversEntireContent() {
        let layout = MinimapLayout(diagramWidth: 400, diagramHeight: 300, padding: 0)
        // Viewport big enough to see everything
        let vp = layout.viewportRect(
            transform: .identity,
            viewportWidth: 400, viewportHeight: 300
        )
        // Viewport origin in minimap should match thumbnail origin
        XCTAssertEqual(vp.x, layout.thumbnailOriginX, accuracy: accuracy)
        XCTAssertEqual(vp.y, layout.thumbnailOriginY, accuracy: accuracy)
    }

    func testViewportMovesWhenPanning() {
        let layout = MinimapLayout(diagramWidth: 800, diagramHeight: 600, padding: 0)
        let transform = CanvasTransform(translateX: 0, translateY: 0, scale: 1)

        let vp1 = layout.viewportRect(
            transform: transform,
            viewportWidth: 400, viewportHeight: 300
        )

        // Pan right (translateX increases → viewport content origin moves left)
        let panned = transform.panned(dx: 100, dy: 0)
        let vp2 = layout.viewportRect(
            transform: panned,
            viewportWidth: 400, viewportHeight: 300
        )

        // The viewport rect in minimap should move LEFT when we pan RIGHT
        // (because panning right means we see content further left)
        XCTAssertLessThan(vp2.x, vp1.x)
    }

    func testViewportShrinkWhenZoomingIn() {
        let layout = MinimapLayout(diagramWidth: 800, diagramHeight: 600, padding: 0)

        let normal = CanvasTransform(translateX: 0, translateY: 0, scale: 1)
        let vpNormal = layout.viewportRect(
            transform: normal,
            viewportWidth: 800, viewportHeight: 600
        )

        let zoomed = CanvasTransform(translateX: 0, translateY: 0, scale: 2)
        let vpZoomed = layout.viewportRect(
            transform: zoomed,
            viewportWidth: 800, viewportHeight: 600
        )

        // Zooming in means we see less content → viewport in minimap should be smaller
        XCTAssertLessThan(vpZoomed.width, vpNormal.width)
        XCTAssertLessThan(vpZoomed.height, vpNormal.height)
    }

    func testViewportWidthInverslyProportionalToScale() {
        let layout = MinimapLayout(diagramWidth: 800, diagramHeight: 600, padding: 0)
        let viewportWidth = 800.0

        let t1 = CanvasTransform(translateX: 0, translateY: 0, scale: 1)
        let vp1 = layout.viewportRect(transform: t1, viewportWidth: viewportWidth, viewportHeight: 600)

        let t2 = CanvasTransform(translateX: 0, translateY: 0, scale: 2)
        let vp2 = layout.viewportRect(transform: t2, viewportWidth: viewportWidth, viewportHeight: 600)

        // At 2x zoom, viewport width in minimap should be half
        XCTAssertEqual(vp2.width, vp1.width / 2, accuracy: accuracy)
    }

    // MARK: - Edge cases

    func testVerySmallDiagram() {
        let layout = MinimapLayout(diagramWidth: 1, diagramHeight: 1, padding: 0)
        XCTAssertGreaterThan(layout.minimapScale, 0)
        XCTAssertLessThanOrEqual(layout.thumbnailWidth, layout.minimapWidth + accuracy)
    }

    func testVeryLargeDiagram() {
        let layout = MinimapLayout(diagramWidth: 100000, diagramHeight: 100000, padding: 0)
        XCTAssertGreaterThan(layout.minimapScale, 0)
        XCTAssertLessThanOrEqual(layout.thumbnailWidth, layout.minimapWidth + accuracy)
    }
}
