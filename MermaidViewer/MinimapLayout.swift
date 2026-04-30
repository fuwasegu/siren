import Foundation

/// Pure value type that computes minimap geometry from diagram/viewport state.
struct MinimapLayout: Equatable {
    let minimapWidth: Double
    let minimapHeight: Double
    let diagramWidth: Double
    let diagramHeight: Double
    let padding: Double

    init(minimapWidth: Double = 160, minimapHeight: Double = 100,
         diagramWidth: Double, diagramHeight: Double, padding: Double = 20) {
        self.minimapWidth = minimapWidth
        self.minimapHeight = minimapHeight
        self.diagramWidth = diagramWidth
        self.diagramHeight = diagramHeight
        self.padding = padding
    }

    /// Scale factor to fit diagram+padding into the minimap.
    var minimapScale: Double {
        guard contentWidth > 0, contentHeight > 0 else { return 1 }
        return min(minimapWidth / contentWidth, minimapHeight / contentHeight)
    }

    /// Diagram + padding total size in content space.
    var contentWidth: Double { diagramWidth + padding * 2 }
    var contentHeight: Double { diagramHeight + padding * 2 }

    /// Thumbnail size in minimap pixels.
    var thumbnailWidth: Double { contentWidth * minimapScale }
    var thumbnailHeight: Double { contentHeight * minimapScale }

    /// Thumbnail offset to center it in the minimap.
    var thumbnailOriginX: Double { (minimapWidth - thumbnailWidth) / 2 }
    var thumbnailOriginY: Double { (minimapHeight - thumbnailHeight) / 2 }

    /// Diagram rect within the minimap (inside the padding area of the thumbnail).
    var diagramRectX: Double { thumbnailOriginX + padding * minimapScale }
    var diagramRectY: Double { thumbnailOriginY + padding * minimapScale }
    var diagramRectWidth: Double { diagramWidth * minimapScale }
    var diagramRectHeight: Double { diagramHeight * minimapScale }

    // MARK: - Viewport

    /// Compute the viewport rectangle in minimap coordinates.
    /// The viewport represents what is currently visible on screen.
    func viewportRect(
        transform: CanvasTransform,
        viewportWidth: Double,
        viewportHeight: Double
    ) -> (x: Double, y: Double, width: Double, height: Double) {
        let visible = transform.visibleRect(viewportWidth: viewportWidth, viewportHeight: viewportHeight)

        let vpX = visible.x * minimapScale + thumbnailOriginX + padding * minimapScale
        let vpY = visible.y * minimapScale + thumbnailOriginY + padding * minimapScale
        let vpW = visible.width * minimapScale
        let vpH = visible.height * minimapScale

        return (vpX, vpY, vpW, vpH)
    }
}
