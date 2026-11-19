import SwiftUI

#if canImport(AppKit)
  import AppKit

  /// Scheduling for the canvas control tip. Kept testable and independent of
  /// system `.help`, which is slow and would stack with a custom bubble.
  public enum FlowHoverTipPolicy {
    public static let delayMs = 150
    public static let skipDelayMs = 200

    public static func openDelayMs(
      preferred: Int = delayMs,
      lastClosedAt: Date?,
      now: Date,
      skipDelayMs: Int = skipDelayMs
    ) -> Int {
      if let lastClosedAt {
        let elapsed = now.timeIntervalSince(lastClosedAt) * 1000
        if elapsed < Double(skipDelayMs) { return 0 }
      }
      return preferred
    }

    public static func shouldShow(hovering: Bool, cancelled: Bool) -> Bool {
      hovering && !cancelled
    }

    /// Prefer above the control; flip below or shift if the visible edge would clip.
    public static func position(
      anchor: CGRect, tipSize: CGSize, visible: CGRect? = nil, gap: CGFloat = 6
    ) -> CGPoint {
      let screen =
        visible
        ?? CGRect(x: 0, y: 0, width: 2000, height: 1200)
      var x = anchor.midX - tipSize.width / 2
      var y = anchor.maxY + gap
      if y + tipSize.height > screen.maxY {
        y = anchor.minY - tipSize.height - gap
      }
      x = min(max(x, screen.minX), max(screen.minX, screen.maxX - tipSize.width))
      y = min(max(y, screen.minY), max(screen.minY, screen.maxY - tipSize.height))
      return CGPoint(x: x, y: y)
    }

    /// Window-base rect (origin at the window's bottom-left) → screen. Do not add the frame origin twice.
    public static func screenRect(windowRect: CGRect, windowFrameOnScreen: CGRect) -> CGRect {
      windowRect.offsetBy(dx: windowFrameOnScreen.minX, dy: windowFrameOnScreen.minY)
    }

    /// SwiftFlow content layer: scale from topLeading, then offset, in Y-down canvas space.
    public static func canvasRect(_ flowRect: CGRect, zoom: CGFloat, offset: CGSize) -> CGRect {
      CGRect(
        x: flowRect.minX * zoom + offset.width,
        y: flowRect.minY * zoom + offset.height,
        width: flowRect.width * zoom,
        height: flowRect.height * zoom
      )
    }

    /// Y-down rect in a flipped content view → window-base (Y-up) coordinates.
    public static func windowRect(
      fromFlippedContent rect: CGRect, contentHeight: CGFloat, contentOriginInWindow: CGPoint
    ) -> CGRect {
      CGRect(
        x: contentOriginInWindow.x + rect.minX,
        y: contentOriginInWindow.y + (contentHeight - rect.maxY),
        width: rect.width,
        height: rect.height
      )
    }

    /// Live screen frame, including ancestor CALayer transforms; convertToScreen once.
    @MainActor
    public static func screenFrame(of view: NSView) -> CGRect {
      guard let window = view.window else { return .zero }
      let windowRect: CGRect
      if let content = window.contentView, let from = view.layer, let to = content.layer {
        windowRect = content.convert(from.convert(view.bounds, to: to), to: nil)
      } else {
        windowRect = view.convert(view.bounds, to: nil)
      }
      return window.convertToScreen(windowRect)
    }
  }

  enum FlowControlCursorPolicy {
    static func resolved(overControl: Bool, tool: FlowCursor) -> FlowCursor {
      overControl ? .default : tool
    }

    static func stackChange(entering: Bool, isPushed: Bool) -> (push: Bool, pop: Bool, isPushed: Bool) {
      if entering, !isPushed { return (true, false, true) }
      if !entering, isPushed { return (false, true, false) }
      return (false, false, isPushed)
    }
  }

  @MainActor
  final class FlowHoverTipGate {
    static let shared = FlowHoverTipGate()
    private var lastClosedAt: Date?

    func openDelayMs() -> Int {
      FlowHoverTipPolicy.openDelayMs(lastClosedAt: lastClosedAt, now: Date())
    }

    func markClosed() {
      lastClosedAt = Date()
    }
  }

  /// Borderless, non-activating tip that does not hit-test or steal the cursor.
  @MainActor
  final class FlowHoverTipPortal {
    static let shared = FlowHoverTipPortal()

    private var panel: NSPanel?
    private var hosting: NSHostingView<FlowHoverTipBubble>?
    private var ownerID: UUID?
    private var dismissal: Any?

    func show(id: UUID, text: String, anchorScreen: CGRect) {
      let bubble = FlowHoverTipBubble(text: text)
      let host: NSHostingView<FlowHoverTipBubble>
      if let existing = hosting {
        existing.rootView = bubble
        host = existing
      } else {
        host = NSHostingView(rootView: bubble)
        hosting = host
      }
      host.invalidateIntrinsicContentSize()
      let size = host.fittingSize
      guard size.width > 0, size.height > 0 else { return }
      let origin = FlowHoverTipPolicy.position(
        anchor: anchorScreen,
        tipSize: size,
        visible: NSScreen.screens.first(where: { $0.frame.intersects(anchorScreen) })?.visibleFrame
          ?? NSScreen.main?.visibleFrame
      )
      let frame = NSRect(origin: origin, size: size)

      let win: NSPanel
      if let panel {
        win = panel
      } else {
        let created = NSPanel(
          contentRect: frame,
          styleMask: [.borderless, .nonactivatingPanel],
          backing: .buffered,
          defer: false
        )
        created.isFloatingPanel = true
        created.level = .floating
        created.isOpaque = false
        created.backgroundColor = .clear
        created.hasShadow = false
        created.ignoresMouseEvents = true
        created.hidesOnDeactivate = false
        created.becomesKeyOnlyIfNeeded = true
        created.contentView = host
        panel = created
        win = created
        installDismissal()
      }
      if win.contentView !== host {
        win.contentView = host
      }
      win.setFrame(frame, display: true)
      if !win.isVisible {
        win.orderFrontRegardless()
      }
      ownerID = id
    }

    func hideIfOwned(by id: UUID) {
      guard ownerID == id else { return }
      hideAll()
    }

    func hideAll() {
      ownerID = nil
      panel?.orderOut(nil)
      FlowHoverTipGate.shared.markClosed()
    }

    private func installDismissal() {
      guard dismissal == nil else { return }
      dismissal = NSEvent.addLocalMonitorForEvents(
        matching: [.leftMouseDown, .leftMouseDragged, .scrollWheel]
      ) { [weak self] event in
        self?.hideAll()
        return event
      }
    }

  }

  struct FlowHoverTipBubble: View {
    let text: String

    var body: some View {
      Text(text)
        .font(.system(size: 11))
        .foregroundStyle(.primary)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .fixedSize()
        .allowsHitTesting(false)
    }
  }

  @MainActor
  final class FlowTipAnchorBox {
    weak var view: NSView?
    func screenFrame() -> CGRect {
      guard let view else { return .zero }
      return FlowHoverTipPolicy.screenFrame(of: view)
    }
  }

  private final class FlowTipProbeView: NSView {
    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      wantsLayer = true
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
  }

  private struct FlowTipProbe: NSViewRepresentable {
    let box: FlowTipAnchorBox
    func makeNSView(context: Context) -> FlowTipProbeView {
      let v = FlowTipProbeView()
      box.view = v
      return v
    }
    func updateNSView(_ nsView: FlowTipProbeView, context: Context) {
      box.view = nsView
    }
  }

  struct FlowHoverTip<Content: View>: View {
    let text: String
    @ViewBuilder var content: () -> Content
    @State private var tipID = UUID()
    @State private var hovering = false
    @State private var anchorBox = FlowTipAnchorBox()
    @State private var showTask: Task<Void, Never>?

    var body: some View {
      content()
        .background(FlowTipProbe(box: anchorBox))
        .hoverCursor(.arrow)
        .onHover { inside in
          guard !text.isEmpty else { return }
          hovering = inside
          if inside {
            scheduleShow()
          } else {
            cancelAndHide()
          }
        }
        .onDisappear { cancelAndHide() }
    }

    private func scheduleShow() {
      showTask?.cancel()
      let delay = FlowHoverTipGate.shared.openDelayMs()
      let id = tipID
      let tipText = text
      showTask = Task { @MainActor in
        if delay > 0 {
          try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
        }
        guard !Task.isCancelled, FlowHoverTipPolicy.shouldShow(hovering: hovering, cancelled: false)
        else { return }
        let anchor = self.anchorBox.screenFrame()
        guard anchor.width > 0, anchor.height > 0 else { return }
        FlowHoverTipPortal.shared.show(id: id, text: tipText, anchorScreen: anchor)
      }
    }

    private func cancelAndHide() {
      showTask?.cancel()
      showTask = nil
      FlowHoverTipPortal.shared.hideIfOwned(by: tipID)
    }
  }

  extension View {
    /// Fast custom tip for canvas controls. Do not also apply `.help`.
    func flowHoverTip(_ text: String) -> some View {
      Group {
        if text.isEmpty {
          self
        } else {
          FlowHoverTip(text: text) { self }
        }
      }
    }
  }
#else
  public enum FlowHoverTipPolicy {
    public static let delayMs = 150
    public static func openDelayMs(
      preferred: Int = delayMs, lastClosedAt: Date?, now: Date, skipDelayMs: Int = 200
    ) -> Int {
      preferred
    }
    public static func shouldShow(hovering: Bool, cancelled: Bool) -> Bool {
      hovering && !cancelled
    }
  }

  extension View {
    func flowHoverTip(_ text: String) -> some View { self }
  }
#endif
