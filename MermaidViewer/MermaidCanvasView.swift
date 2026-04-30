import SwiftUI
import WebKit

struct MermaidCanvasView: NSViewRepresentable {
    let mermaidContent: String
    let theme: AppTheme

    @EnvironmentObject var appState: AppState

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.userContentController.add(context.coordinator, name: "themeChanged")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false

        context.coordinator.webView = webView
        context.coordinator.installEventMonitor()

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let escaped = mermaidContent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let themeJS: String
        switch theme {
        case .system: themeJS = "system"
        case .light: themeJS = "light"
        case .dark: themeJS = "dark"
        }

        // If content hasn't changed, just switch theme via JS
        if context.coordinator.lastContent == mermaidContent && context.coordinator.hasLoaded {
            webView.evaluateJavaScript("if(window.setTheme) window.setTheme('\(themeJS)');")
            return
        }

        context.coordinator.lastContent = mermaidContent
        context.coordinator.hasLoaded = true

        let html = Self.buildHTML(mermaidSource: escaped, themeMode: themeJS)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.appState = appState
        return coordinator
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastContent: String = ""
        var hasLoaded = false
        weak var appState: AppState?
        weak var webView: WKWebView?

        private var eventMonitor: Any?
        private var baseScale: Double = 1.0
        private var isMagnifying = false

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "themeChanged", let value = message.body as? String {
                DispatchQueue.main.async {
                    switch value {
                    case "light": self.appState?.theme = .light
                    case "dark": self.appState?.theme = .dark
                    default: self.appState?.theme = .system
                    }
                }
            }
        }

        // MARK: - Magnification event monitor

        func installEventMonitor() {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
                self?.handleMagnifyEvent(event)
            }
        }

        private func handleMagnifyEvent(_ event: NSEvent) -> NSEvent? {
            guard let webView = webView else { return event }

            // Only handle if the event is targeted at our webView
            guard let window = webView.window,
                  event.window === window else { return event }

            // Get mouse location in webView coordinates
            let windowPoint = event.locationInWindow
            let viewPoint = webView.convert(windowPoint, from: nil)

            // Check if the event is within our webView
            guard webView.bounds.contains(viewPoint) else { return event }

            let cx = viewPoint.x
            // Flip Y: NSView has origin at bottom-left, web has origin at top-left
            let cy = webView.bounds.height - viewPoint.y

            switch event.phase {
            case .began:
                isMagnifying = true
                webView.evaluateJavaScript("window.getScale()") { [weak self] result, _ in
                    self?.baseScale = (result as? Double) ?? 1.0
                }
            case .changed:
                if isMagnifying {
                    // event.magnification is the incremental delta per event
                    baseScale = baseScale * (1.0 + event.magnification)
                    webView.evaluateJavaScript("window.zoomedTo(\(cx), \(cy), \(baseScale))")
                }
            case .ended, .cancelled:
                isMagnifying = false
            default:
                break
            }

            // Force reset WKWebView's native magnification every time
            if webView.magnification != 1.0 {
                webView.magnification = 1.0
            }

            // Return nil to consume the event — prevents WKWebView from handling it
            return nil
        }
    }

    static func buildHTML(mermaidSource: String, themeMode: String = "system") -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }

            html, body {
                width: 100%;
                height: 100%;
                overflow: hidden;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro', system-ui, sans-serif;
                user-select: none;
                -webkit-user-select: none;
                transition: background 0.3s ease, color 0.3s ease;
            }

            /* Theme: light */
            html.theme-light, html.theme-light body { background: #fafafa; color: #333; }
            html.theme-light #minimap { background: rgba(255,255,255,0.85); border-color: rgba(0,0,0,0.08); }
            html.theme-light #toolbar { background: rgba(255,255,255,0.85); border-color: rgba(0,0,0,0.08); }
            html.theme-light .toolbar-btn:hover { background: rgba(0,0,0,0.06); }
            html.theme-light .toolbar-divider { background: rgba(0,0,0,0.08); }
            html.theme-light .spinner { border-color: rgba(0,0,0,0.1); border-top-color: rgba(0,0,0,0.5); }
            html.theme-light #loading-text { color: rgba(0,0,0,0.4); }
            html.theme-light #theme-label { color: rgba(0,0,0,0.45); }

            /* Theme: dark */
            html.theme-dark, html.theme-dark body { background: #1a1a1a; color: #eee; }
            html.theme-dark #minimap { background: rgba(40,40,40,0.85); border-color: rgba(255,255,255,0.08); }
            html.theme-dark #toolbar { background: rgba(40,40,40,0.85); border-color: rgba(255,255,255,0.08); }
            html.theme-dark .toolbar-btn:hover { background: rgba(255,255,255,0.08); }
            html.theme-dark .toolbar-divider { background: rgba(255,255,255,0.1); }
            html.theme-dark .spinner { border-color: rgba(255,255,255,0.1); border-top-color: rgba(255,255,255,0.5); }
            html.theme-dark #loading-text { color: rgba(255,255,255,0.4); }
            html.theme-dark #theme-label { color: rgba(255,255,255,0.45); }

            #canvas {
                position: absolute;
                top: 0; left: 0;
                width: 100%;
                height: 100%;
            }

            #diagram-container {
                transform-origin: 0 0;
                will-change: transform;
                transition: none;
            }

            #diagram-container svg {
                display: block;
                filter: drop-shadow(0 1px 3px rgba(0,0,0,0.06));
            }

            /* Grid background */
            #grid {
                position: fixed;
                top: 0; left: 0;
                width: 100%; height: 100%;
                pointer-events: none;
                z-index: 0;
            }

            #diagram-container {
                position: relative;
                z-index: 1;
            }

            /* Zoom indicator */
            #zoom-indicator {
                position: fixed;
                bottom: 16px;
                left: 50%;
                transform: translateX(-50%);
                background: rgba(0,0,0,0.6);
                backdrop-filter: blur(20px);
                -webkit-backdrop-filter: blur(20px);
                color: white;
                padding: 6px 14px;
                border-radius: 20px;
                font-size: 12px;
                font-weight: 500;
                letter-spacing: 0.02em;
                opacity: 0;
                transition: opacity 0.2s ease;
                z-index: 100;
                pointer-events: none;
            }

            #zoom-indicator.visible {
                opacity: 1;
            }

            /* Mini-map */
            #minimap {
                position: fixed;
                bottom: 16px;
                right: 16px;
                width: 160px;
                height: 100px;
                backdrop-filter: blur(20px);
                -webkit-backdrop-filter: blur(20px);
                border: 1px solid;
                border-radius: 10px;
                overflow: hidden;
                z-index: 100;
                box-shadow: 0 2px 12px rgba(0,0,0,0.08);
                transition: background 0.3s ease, border-color 0.3s ease;
            }

            #minimap-content {
                width: 100%;
                height: 100%;
                position: relative;
            }

            #minimap-viewport {
                position: absolute;
                border: 1.5px solid rgba(59, 130, 246, 0.7);
                background: rgba(59, 130, 246, 0.08);
                border-radius: 2px;
                pointer-events: none;
            }

            /* Toolbar */
            #toolbar {
                position: fixed;
                bottom: 16px;
                left: 16px;
                display: flex;
                gap: 2px;
                align-items: center;
                backdrop-filter: blur(20px);
                -webkit-backdrop-filter: blur(20px);
                border: 1px solid;
                border-radius: 10px;
                padding: 4px;
                z-index: 100;
                box-shadow: 0 2px 12px rgba(0,0,0,0.08);
                transition: background 0.3s ease, border-color 0.3s ease;
            }

            .toolbar-btn {
                width: 32px;
                height: 32px;
                border: none;
                background: transparent;
                border-radius: 7px;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
                color: inherit;
                font-size: 16px;
                transition: background 0.15s ease;
            }

            .toolbar-divider {
                width: 1px;
                height: 20px;
                margin: 0 2px;
                transition: background 0.3s ease;
            }

            #theme-label {
                font-size: 10px;
                font-weight: 600;
                letter-spacing: 0.04em;
                padding: 0 4px;
                text-transform: uppercase;
                transition: color 0.3s ease;
                pointer-events: none;
                min-width: 44px;
                text-align: center;
            }

            /* Loading */
            #loading {
                position: fixed;
                top: 50%; left: 50%;
                transform: translate(-50%, -50%);
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 12px;
                z-index: 200;
            }

            .spinner {
                width: 24px; height: 24px;
                border: 2.5px solid;
                border-radius: 50%;
                animation: spin 0.7s linear infinite;
                transition: border-color 0.3s ease;
            }

            @keyframes spin { to { transform: rotate(360deg); } }

            #loading-text {
                font-size: 13px;
                transition: color 0.3s ease;
            }

            /* Error */
            #error {
                display: none;
                position: fixed;
                top: 50%; left: 50%;
                transform: translate(-50%, -50%);
                text-align: center;
                z-index: 200;
                color: #e74c3c;
                font-size: 14px;
                max-width: 400px;
                line-height: 1.5;
            }
        </style>
        </head>
        <body>
            <canvas id="grid"></canvas>
            <div id="canvas">
                <div id="diagram-container"></div>
            </div>

            <div id="loading">
                <div class="spinner"></div>
                <div id="loading-text">Rendering diagram...</div>
            </div>

            <div id="error"></div>

            <div id="zoom-indicator">100%</div>

            <div id="toolbar">
                <button class="toolbar-btn" onclick="zoomIn()" title="Zoom In (⌘+)">+</button>
                <button class="toolbar-btn" onclick="zoomOut()" title="Zoom Out (⌘-)">−</button>
                <button class="toolbar-btn" onclick="resetView()" title="Fit to View (⌘0)">⊡</button>
                <div class="toolbar-divider"></div>
                <button class="toolbar-btn" id="theme-btn" onclick="cycleTheme()" title="Toggle Theme (⌘T)">◐</button>
                <div id="theme-label">Auto</div>
                <div class="toolbar-divider"></div>
                <button class="toolbar-btn" onclick="exportSVG()" title="Export SVG">↓</button>
            </div>

            <div id="minimap">
                <div id="minimap-content">
                    <canvas id="minimap-canvas"></canvas>
                    <div id="minimap-viewport"></div>
                </div>
            </div>

            <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
            <script>
            (function() {
                // --- Theme ---
                let currentThemeMode = '\\THEME_MODE\\';

                function resolveTheme(mode) {
                    if (mode === 'dark') return 'dark';
                    if (mode === 'light') return 'light';
                    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
                }

                function applyThemeClass(mode) {
                    currentThemeMode = mode;
                    const resolved = resolveTheme(mode);
                    document.documentElement.className = 'theme-' + resolved;
                    updateThemeUI(mode);
                    return resolved;
                }

                function updateThemeUI(mode) {
                    const btn = document.getElementById('theme-btn');
                    const label = document.getElementById('theme-label');
                    if (mode === 'dark') {
                        btn.textContent = '●';
                        label.textContent = 'Dark';
                    } else if (mode === 'light') {
                        btn.textContent = '○';
                        label.textContent = 'Light';
                    } else {
                        btn.textContent = '◐';
                        label.textContent = 'Auto';
                    }
                }

                window.setTheme = function(mode) {
                    const resolved = applyThemeClass(mode);
                    reRenderWithTheme(resolved);
                };

                window.cycleTheme = function() {
                    const next = currentThemeMode === 'system' ? 'light'
                               : currentThemeMode === 'light' ? 'dark' : 'system';
                    const resolved = applyThemeClass(next);
                    reRenderWithTheme(resolved);
                    window.webkit.messageHandlers.themeChanged.postMessage(next);
                };

                window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
                    if (currentThemeMode === 'system') {
                        const resolved = applyThemeClass('system');
                        reRenderWithTheme(resolved);
                    }
                });

                applyThemeClass(currentThemeMode);

                // =====================================================
                // CanvasTransform — mirrors Swift CanvasTransform struct
                // =====================================================
                const MIN_SCALE = 0.1;
                const MAX_SCALE = 10;

                function clampScale(s) {
                    return Math.min(MAX_SCALE, Math.max(MIN_SCALE, s));
                }

                // Transform state
                let scale = 1, translateX = 0, translateY = 0;

                // zoomedTo: zoom to absolute newScale, keeping (cx, cy) fixed on screen
                function zoomedTo(cx, cy, newScale) {
                    const clamped = clampScale(newScale);
                    const ratio = clamped / scale;
                    translateX = cx - (cx - translateX) * ratio;
                    translateY = cy - (cy - translateY) * ratio;
                    scale = clamped;
                }

                // zoomedAt: zoom by multiplicative delta at screen point
                function zoomedAt(cx, cy, delta) {
                    zoomedTo(cx, cy, scale * (1 - delta));
                }

                // panned: add screen-space delta
                function panned(dx, dy) {
                    translateX += dx;
                    translateY += dy;
                }

                // fitToView: compute transform that fits diagram in viewport
                function fitToView(animate) {
                    if (!diagramWidth || !diagramHeight) return;
                    const pad = 80, maxFit = 2;
                    const sx = (window.innerWidth - pad * 2) / diagramWidth;
                    const sy = (window.innerHeight - pad * 2) / diagramHeight;
                    const fitScale = clampScale(Math.min(sx, sy, maxFit));
                    const tx = (window.innerWidth - diagramWidth * fitScale) / 2;
                    const ty = (window.innerHeight - diagramHeight * fitScale) / 2;

                    if (animate) {
                        animateTo(tx, ty, fitScale);
                    } else {
                        scale = fitScale;
                        translateX = tx;
                        translateY = ty;
                        scheduleUpdate();
                    }
                    showZoomIndicator();
                }

                // visibleRect in content-space
                function visibleRect() {
                    return {
                        x: -translateX / scale,
                        y: -translateY / scale,
                        w: window.innerWidth / scale,
                        h: window.innerHeight / scale
                    };
                }

                // =====================================================
                // Interaction state
                // =====================================================
                let isPanning = false;
                let startX = 0, startY = 0, startTX = 0, startTY = 0;
                let diagramWidth = 0, diagramHeight = 0;
                let zoomTimeout = null, rafId = null, needsUpdate = false;

                const ZOOM_SENSITIVITY = 0.003;

                const container = document.getElementById('diagram-container');
                const zoomIndicator = document.getElementById('zoom-indicator');
                const gridCanvas = document.getElementById('grid');
                const gridCtx = gridCanvas.getContext('2d');

                // --- Render loop ---
                function scheduleUpdate() {
                    if (!needsUpdate) {
                        needsUpdate = true;
                        rafId = requestAnimationFrame(applyTransform);
                    }
                }

                function applyTransform() {
                    needsUpdate = false;
                    container.style.transform =
                        `translate(${translateX}px, ${translateY}px) scale(${scale})`;
                    drawGrid();
                    updateMinimap();
                }

                // =====================================================
                // GridLayout — mirrors Swift GridLayout enum
                // =====================================================
                function drawGrid() {
                    const w = window.innerWidth;
                    const h = window.innerHeight;
                    const dpr = window.devicePixelRatio || 1;

                    gridCanvas.width = w * dpr;
                    gridCanvas.height = h * dpr;
                    gridCanvas.style.width = w + 'px';
                    gridCanvas.style.height = h + 'px';
                    gridCtx.scale(dpr, dpr);
                    gridCtx.clearRect(0, 0, w, h);

                    const isDark = document.documentElement.classList.contains('theme-dark');

                    // adaptiveGridSize
                    let gridSize = 20 * scale;
                    while (gridSize < 10) gridSize *= 5;
                    while (gridSize > 100) gridSize /= 5;

                    // dotSize & dotAlpha
                    const dotSz = Math.max(0.8, scale * 0.8);
                    const alpha = Math.min(0.35, 0.1 + (gridSize - 10) / 200);

                    gridCtx.fillStyle = isDark
                        ? `rgba(255,255,255,${alpha})`
                        : `rgba(0,0,0,${alpha})`;

                    // gridOffset
                    const offX = translateX % gridSize;
                    const offY = translateY % gridSize;

                    for (let x = offX; x < w; x += gridSize) {
                        for (let y = offY; y < h; y += gridSize) {
                            gridCtx.beginPath();
                            gridCtx.arc(x, y, dotSz, 0, Math.PI * 2);
                            gridCtx.fill();
                        }
                    }
                }

                // --- Zoom UI ---
                function showZoomIndicator() {
                    zoomIndicator.textContent = Math.round(scale * 100) + '%';
                    zoomIndicator.classList.add('visible');
                    clearTimeout(zoomTimeout);
                    zoomTimeout = setTimeout(() => {
                        zoomIndicator.classList.remove('visible');
                    }, 800);
                }

                window.zoomIn = function() {
                    zoomedAt(window.innerWidth / 2, window.innerHeight / 2, -0.15);
                    scheduleUpdate(); showZoomIndicator();
                };
                window.zoomOut = function() {
                    zoomedAt(window.innerWidth / 2, window.innerHeight / 2, 0.15);
                    scheduleUpdate(); showZoomIndicator();
                };
                window.resetView = function() { fitToView(true); };

                // Expose for Swift evaluateJavaScript calls
                window.zoomedTo = function(cx, cy, ns) {
                    zoomedTo(cx, cy, ns);
                    scheduleUpdate(); showZoomIndicator();
                };
                window.getScale = function() { return scale; };

                window.exportSVG = function() {
                    const svg = container.querySelector('svg');
                    if (!svg) return;
                    const blob = new Blob([svg.outerHTML], { type: 'image/svg+xml' });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url; a.download = 'diagram.svg'; a.click();
                    URL.revokeObjectURL(url);
                };

                // --- Pan & Zoom events ---
                // Trackpad pinch zoom is handled by Swift's
                // NSMagnificationGestureRecognizer → evaluateJavaScript.
                // Wheel events handle panning only. ctrlKey+wheel is kept
                // as a fallback for external mice with scroll wheels.
                document.addEventListener('wheel', (e) => {
                    e.preventDefault();
                    if (e.ctrlKey) {
                        // Ctrl+scroll wheel (external mouse)
                        zoomedAt(e.clientX, e.clientY, e.deltaY * ZOOM_SENSITIVITY);
                        scheduleUpdate(); showZoomIndicator();
                    } else {
                        panned(-e.deltaX, -e.deltaY);
                        scheduleUpdate();
                    }
                }, { passive: false });

                // Consume gesture events to prevent WKWebView's native zoom
                document.addEventListener('gesturestart', (e) => e.preventDefault());
                document.addEventListener('gesturechange', (e) => e.preventDefault());
                document.addEventListener('gestureend', (e) => e.preventDefault());

                document.addEventListener('mousedown', (e) => {
                    isPanning = true;
                    startX = e.clientX; startY = e.clientY;
                    startTX = translateX; startTY = translateY;
                    document.body.style.cursor = 'grabbing';
                    e.preventDefault();
                });
                document.addEventListener('mousemove', (e) => {
                    if (!isPanning) return;
                    translateX = startTX + (e.clientX - startX);
                    translateY = startTY + (e.clientY - startY);
                    scheduleUpdate();
                });
                document.addEventListener('mouseup', () => {
                    isPanning = false;
                    document.body.style.cursor = 'default';
                });

                document.addEventListener('keydown', (e) => {
                    if (e.metaKey && e.key === '=') { e.preventDefault(); zoomIn(); }
                    else if (e.metaKey && e.key === '-') { e.preventDefault(); zoomOut(); }
                    else if (e.metaKey && e.key === '0') { e.preventDefault(); resetView(); }
                    else if (e.metaKey && e.key === 't') { e.preventDefault(); cycleTheme(); }
                });

                // =====================================================
                // MinimapLayout — mirrors Swift MinimapLayout struct
                // =====================================================
                function updateMinimap() {
                    const mc = document.getElementById('minimap-canvas');
                    const vp = document.getElementById('minimap-viewport');
                    if (!mc || !diagramWidth || !diagramHeight) return;

                    const mmW = 160, mmH = 100, pad = 20;
                    const contentW = diagramWidth + pad * 2;
                    const contentH = diagramHeight + pad * 2;
                    const mmScale = Math.min(mmW / contentW, mmH / contentH);

                    const thumbW = contentW * mmScale;
                    const thumbH = contentH * mmScale;
                    const thumbOX = (mmW - thumbW) / 2;
                    const thumbOY = (mmH - thumbH) / 2;

                    mc.width = mmW * 2; mc.height = mmH * 2;
                    mc.style.width = mmW + 'px'; mc.style.height = mmH + 'px';
                    const ctx = mc.getContext('2d');
                    ctx.scale(2, 2);
                    ctx.clearRect(0, 0, mmW, mmH);

                    const isDark = document.documentElement.classList.contains('theme-dark');
                    ctx.fillStyle = isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)';
                    ctx.fillRect(thumbOX, thumbOY, thumbW, thumbH);

                    ctx.fillStyle = isDark ? 'rgba(255,255,255,0.15)' : 'rgba(0,0,0,0.1)';
                    ctx.roundRect(
                        thumbOX + pad * mmScale, thumbOY + pad * mmScale,
                        diagramWidth * mmScale, diagramHeight * mmScale, 2);
                    ctx.fill();

                    // viewportRect — same formula as Swift MinimapLayout.viewportRect
                    const vis = visibleRect();
                    const vpX = vis.x * mmScale + thumbOX + pad * mmScale;
                    const vpY = vis.y * mmScale + thumbOY + pad * mmScale;
                    const vpW = vis.w * mmScale;
                    const vpH = vis.h * mmScale;

                    vp.style.left = vpX + 'px';
                    vp.style.top = vpY + 'px';
                    vp.style.width = vpW + 'px';
                    vp.style.height = vpH + 'px';
                }

                // --- Animation ---
                function animateTo(targetTX, targetTY, targetScale) {
                    const sTX = translateX, sTY = translateY, sS = scale;
                    const dur = 400, t0 = performance.now();
                    function ease(t) { return 1 - Math.pow(1 - t, 3); }
                    function step(now) {
                        const t = Math.min(1, (now - t0) / dur);
                        const e = ease(t);
                        scale = sS + (targetScale - sS) * e;
                        translateX = sTX + (targetTX - sTX) * e;
                        translateY = sTY + (targetTY - sTY) * e;
                        applyTransform();
                        if (t < 1) requestAnimationFrame(step);
                    }
                    requestAnimationFrame(step);
                }

                window.addEventListener('resize', () => { drawGrid(); updateMinimap(); });

                // --- Init Mermaid ---
                const mermaidSource = `\\MERMAID_SOURCE\\`;
                let renderCounter = 0;

                function getMermaidTheme(resolved) {
                    return resolved === 'dark' ? 'dark' : 'default';
                }

                async function renderDiagram(mermaidTheme, isInitial) {
                    mermaid.initialize({
                        startOnLoad: false,
                        theme: mermaidTheme,
                        securityLevel: 'loose',
                        fontFamily: '-apple-system, BlinkMacSystemFont, SF Pro, system-ui, sans-serif',
                        flowchart: { curve: 'basis', padding: 20 },
                        sequence: { mirrorActors: false },
                        themeVariables: mermaidTheme === 'dark' ? {
                            primaryColor: '#3B82F6',
                            primaryTextColor: '#E5E7EB',
                            primaryBorderColor: '#60A5FA',
                            lineColor: '#9CA3AF',
                            secondaryColor: '#1F2937',
                            tertiaryColor: '#374151',
                        } : {
                            primaryColor: '#4A90D9',
                            primaryTextColor: '#333',
                            primaryBorderColor: '#3A7BC8',
                            lineColor: '#666',
                            secondaryColor: '#F4F6F9',
                            tertiaryColor: '#E8ECF1',
                        }
                    });

                    // Save current view state
                    const prevScale = scale;
                    const prevTX = translateX;
                    const prevTY = translateY;

                    try {
                        renderCounter++;
                        const id = 'mermaid-diagram-' + renderCounter;
                        const { svg } = await mermaid.render(id, mermaidSource);
                        container.innerHTML = svg;

                        const svgEl = container.querySelector('svg');
                        if (svgEl) {
                            diagramWidth = svgEl.viewBox.baseVal.width || svgEl.getBoundingClientRect().width;
                            diagramHeight = svgEl.viewBox.baseVal.height || svgEl.getBoundingClientRect().height;
                            svgEl.style.width = diagramWidth + 'px';
                            svgEl.style.height = diagramHeight + 'px';
                        }

                        document.getElementById('loading').style.display = 'none';
                        document.getElementById('error').style.display = 'none';

                        if (isInitial) {
                            fitToView(false);
                        } else {
                            // Restore view position on theme change
                            scale = prevScale;
                            translateX = prevTX;
                            translateY = prevTY;
                            scheduleUpdate();
                        }
                    } catch (err) {
                        document.getElementById('loading').style.display = 'none';
                        document.getElementById('error').style.display = 'block';
                        document.getElementById('error').innerHTML =
                            '<div style="font-size:32px;margin-bottom:8px;">⚠</div>' +
                            '<div style="font-weight:600;margin-bottom:4px;">Render Error</div>' +
                            '<div style="opacity:0.7;font-size:12px;">' + (err.message || err) + '</div>';
                    }
                }

                async function reRenderWithTheme(resolved) {
                    await renderDiagram(getMermaidTheme(resolved), false);
                    drawGrid();
                    updateMinimap();
                }

                // Draw initial grid
                drawGrid();
                const initialResolved = resolveTheme(currentThemeMode);
                renderDiagram(getMermaidTheme(initialResolved), true);
            })();
            </script>
        </body>
        </html>
        """.replacingOccurrences(of: "\\MERMAID_SOURCE\\", with: mermaidSource)
           .replacingOccurrences(of: "\\THEME_MODE\\", with: themeMode)
    }
}
