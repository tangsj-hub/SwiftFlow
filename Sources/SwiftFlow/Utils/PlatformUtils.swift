import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

// MARK: - Platform Colors

extension Color {
  /// The default canvas background color, adapting to the platform appearance.
  static var swiftFlowBackground: Color {
    #if canImport(UIKit)
      Color(uiColor: .systemGroupedBackground)
    #elseif canImport(AppKit)
      Color(nsColor: .windowBackgroundColor)
    #else
      Color.gray.opacity(0.1)
    #endif
  }
}

// MARK: - View Helpers

extension View {
  @ViewBuilder
  func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
    if condition { transform(self) } else { self }
  }

  /// Runs `action` with the new value whenever `value` changes.
  ///
  /// Uses the two-value `onChange` where available (iOS 17, macOS 14) and the
  /// single-value variant on macOS 13, avoiding deprecation warnings on both.
  @ViewBuilder
  func onValueChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void)
    -> some View
  {
    #if os(macOS)
      if #available(macOS 14, *) {
        onChange(of: value) { _, newValue in action(newValue) }
      } else {
        onChange(of: value, perform: action)
      }
    #else
      onChange(of: value) { _, newValue in action(newValue) }
    #endif
  }
}

// MARK: - Cursor Helpers

#if canImport(AppKit)
  /// Cursor types for interactive flow elements.
  public enum FlowCursor: Equatable, Sendable {
    case grab, grabbing, pointer, crosshair, `default`

    var nsCursor: NSCursor {
      switch self {
      case .grab: return .openHand
      case .grabbing: return .closedHand
      case .pointer: return .pointingHand
      case .crosshair: return .crosshair
      case .default: return .arrow
      }
    }
  }

  /// Pushes `cursor` while the pointer is inside the view and pops it on exit.
  struct CursorOnHoverModifier: ViewModifier {
    let cursor: NSCursor
    @State private var isPushed = false

    func body(content: Content) -> some View {
      content
        .onHover { hovering in
          if hovering, !isPushed {
            cursor.push()
            isPushed = true
          } else if !hovering, isPushed {
            NSCursor.pop()
            isPushed = false
          }
        }
        .onDisappear {
          // Balance the cursor stack when the view goes away while hovered.
          if isPushed {
            NSCursor.pop()
            isPushed = false
          }
        }
    }
  }

  extension View {
    /// Sets the cursor when hovering over this view (macOS only).
    public func flowCursor(_ cursor: FlowCursor) -> some View {
      hoverCursor(cursor.nsCursor)
    }

    func hoverCursor(_ cursor: NSCursor) -> some View {
      modifier(CursorOnHoverModifier(cursor: cursor))
    }
  }
#else
  public enum FlowCursor { case grab, grabbing, pointer, crosshair, `default` }

  extension View {
    public func flowCursor(_ cursor: FlowCursor) -> some View { self }
  }
#endif

// MARK: - SnapLine (internal model)

struct SnapLine {
  var start: CGPoint
  var end: CGPoint
}

// MARK: - Secondary Action (Context Menu Trigger)

#if canImport(AppKit)
  struct SecondaryClickModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
      content.overlay(SecondaryClickView(action: action))
    }
  }

  /// Monitors right-clicks via a local event monitor while passing through
  /// all left-click, drag, and hover events to underlying SwiftUI content.
  private struct SecondaryClickView: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> SecondaryClickNSView {
      let view = SecondaryClickNSView()
      view.action = action
      return view
    }

    func updateNSView(_ nsView: SecondaryClickNSView, context: Context) {
      nsView.action = action
    }

    final class SecondaryClickNSView: NSView {
      var action: (() -> Void)?
      private var eventMonitor: Any?

      override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor()
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) {
          [weak self] event in
          guard let self, let action = self.action else { return event }
          guard event.window == self.window else { return event }
          let locationInView = self.convert(event.locationInWindow, from: nil)
          guard self.bounds.contains(locationInView) else { return event }
          action()
          return event
        }
      }

      private func removeMonitor() {
        if let monitor = eventMonitor {
          NSEvent.removeMonitor(monitor)
          eventMonitor = nil
        }
      }

      override func hitTest(_ point: NSPoint) -> NSView? {
        nil  // pass-through: let SwiftUI views handle all mouse events
      }
    }
  }
#elseif canImport(UIKit)
  struct SecondaryClickModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
      content.overlay(LongPressView(action: action))
    }
  }

  private struct LongPressView: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.backgroundColor = .clear
      let recognizer = UILongPressGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
      view.addGestureRecognizer(recognizer)
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
      context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    @MainActor final class Coordinator: NSObject {
      var action: () -> Void
      init(action: @escaping () -> Void) { self.action = action }
      @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began { action() }
      }
    }
  }
#endif

extension View {
  func onSecondaryAction(perform action: @escaping () -> Void) -> some View {
    modifier(SecondaryClickModifier(action: action))
  }
}

// MARK: - macOS Trackpad Scroll and Magnify

#if canImport(AppKit)
  /// A same-window trackpad event already converted into view coordinates.
  /// Tests drive the monitor through this type instead of synthesizing NSEvents
  /// with private CGEvent fields.
  struct TrackpadCanvasNSEvent {
    enum Kind {
      case scroll(delta: CGSize, ended: Bool, phaseBegan: Bool, isMomentum: Bool)
      case magnify(increment: CGFloat, ended: Bool)
    }

    var kind: Kind
    var isSameWindow: Bool
    var locationInView: CGPoint
  }

  struct TrackpadCanvasModifier: ViewModifier {
    var onScroll: ((CGSize, CGPoint, Bool) -> Void)?
    var onMagnify: ((CGFloat, CGPoint, Bool) -> Void)?

    func body(content: Content) -> some View {
      content.overlay(TrackpadCanvasView(onScroll: onScroll, onMagnify: onMagnify))
    }
  }

  /// Local-monitor bridge for scroll and native magnify. The view itself is
  /// pass-through so SwiftUI keeps node drag, pane drag, and controls.
  private struct TrackpadCanvasView: NSViewRepresentable {
    var onScroll: ((CGSize, CGPoint, Bool) -> Void)?
    var onMagnify: ((CGFloat, CGPoint, Bool) -> Void)?

    func makeNSView(context: Context) -> TrackpadCanvasNSView {
      let view = TrackpadCanvasNSView()
      view.onScroll = onScroll
      view.onMagnify = onMagnify
      return view
    }

    func updateNSView(_ nsView: TrackpadCanvasNSView, context: Context) {
      nsView.onScroll = onScroll
      nsView.onMagnify = onMagnify
    }
  }

  final class TrackpadCanvasNSView: NSView {
    override var isFlipped: Bool { true }
    var onScroll: ((CGSize, CGPoint, Bool) -> Void)?
    var onMagnify: ((CGFloat, CGPoint, Bool) -> Void)?
    var router = TrackpadCanvasRouter()
    private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      removeMonitor()
      guard window != nil else { return }
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) {
        [weak self] event in
        guard let self else { return event }
        let outcome = self.route(Self.sample(from: event, in: self))
        switch outcome {
        case .pass: return event
        case .consume, .scroll, .magnify: return nil
        }
      }
    }

    /// Shared by the local monitor and tests.
    @discardableResult
    func route(_ event: TrackpadCanvasNSEvent) -> TrackpadCanvasRouter.Outcome {
      let outcome: TrackpadCanvasRouter.Outcome
      switch event.kind {
      case .magnify(let increment, let ended):
        outcome = router.handleMagnify(
          increment: increment, ended: ended, isSameWindow: event.isSameWindow,
          isInBounds: bounds.contains(event.locationInView), enabled: onMagnify != nil)
      case .scroll(let delta, let ended, let phaseBegan, let isMomentum):
        outcome = router.handleScroll(
          delta: delta, ended: ended, phaseBegan: phaseBegan, isMomentum: isMomentum,
          isSameWindow: event.isSameWindow, isInBounds: bounds.contains(event.locationInView),
          enabled: onScroll != nil)
      }
      switch outcome {
      case .scroll(let delta, let ended):
        onScroll?(delta, event.locationInView, ended)
      case .magnify(let factor, let ended):
        onMagnify?(factor, event.locationInView, ended)
      case .pass, .consume:
        break
      }
      return outcome
    }

    static func sample(from event: NSEvent, in view: TrackpadCanvasNSView) -> TrackpadCanvasNSEvent {
      let location = view.convert(event.locationInWindow, from: nil)
      let sameWindow = event.window == view.window
      if event.type == .magnify {
        return TrackpadCanvasNSEvent(
          kind: .magnify(increment: event.magnification, ended: isGestureEnd(event)),
          isSameWindow: sameWindow, locationInView: location)
      }
      var delta = CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY)
      if !event.hasPreciseScrollingDeltas {
        // Mouse wheels report line deltas; scale them to points.
        delta = CGSize(width: delta.width * 10, height: delta.height * 10)
      }
      let isMomentum = event.hasPreciseScrollingDeltas && event.phase.isEmpty
      return TrackpadCanvasNSEvent(
        kind: .scroll(
          delta: delta, ended: isGestureEnd(event),
          phaseBegan: event.phase.contains(.began), isMomentum: isMomentum),
        isSameWindow: sameWindow, locationInView: location)
    }

    static func isGestureEnd(_ event: NSEvent) -> Bool {
      event.phase.contains(.ended) || event.phase.contains(.cancelled)
        || event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled)
    }

    private func removeMonitor() {
      if let monitor = eventMonitor {
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
      }
    }

    override func removeFromSuperview() {
      removeMonitor()
      super.removeFromSuperview()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      nil  // pass-through: let SwiftUI views handle mouse events
    }
  }

  extension View {
    func onCanvasTrackpadEvents(
      onScroll: ((CGSize, CGPoint, Bool) -> Void)?,
      onMagnify: ((CGFloat, CGPoint, Bool) -> Void)?
    ) -> some View {
      modifier(TrackpadCanvasModifier(onScroll: onScroll, onMagnify: onMagnify))
    }
  }
#endif

// MARK: - macOS Key Handling

/// Decides whether a key press belongs to the canvas.
///
/// The canvas handles keys only after the user clicked inside it, only for
/// events sent to its window (key events go to the key window), and only while
/// no text view is being edited, so typing in text fields (including ones
/// inside nodes) is never intercepted.
func canvasShouldHandleKey(isCanvasActive: Bool, isInCanvasWindow: Bool, isEditingText: Bool)
  -> Bool
{
  isCanvasActive && isInCanvasWindow && !isEditingText
}

#if canImport(AppKit)
  /// Routes key presses to the canvas through a window-local event monitor.
  ///
  /// Unlike a first-responder view, the monitor needs no focus of its own: it
  /// becomes active when a mouse click lands inside the canvas and inactive
  /// when a click lands elsewhere.
  struct KeyDownHandler: NSViewRepresentable {
    let handler: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyMonitorView {
      let view = KeyMonitorView()
      view.handler = handler
      return view
    }

    func updateNSView(_ nsView: KeyMonitorView, context: Context) {
      nsView.handler = handler
    }

    final class KeyMonitorView: NSView {
      var handler: ((NSEvent) -> Bool)?
      private(set) var isCanvasActive = false
      private var monitors: [Any] = []

      override var isFlipped: Bool { true }

      override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitors()
        guard window != nil else { return }
        monitors.append(
          NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
          ) { [weak self] event in
            guard let self else { return event }
            let location = self.convert(event.locationInWindow, from: nil)
            self.isCanvasActive = event.window == self.window && self.bounds.contains(location)
            return event
          } as Any)
        monitors.append(
          NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let handler = self.handler, let window = self.window else {
              return event
            }
            let shouldHandle = canvasShouldHandleKey(
              isCanvasActive: self.isCanvasActive,
              isInCanvasWindow: event.window == window,
              isEditingText: window.firstResponder is NSText)
            return shouldHandle && handler(event) ? nil : event
          } as Any)
      }

      override func removeFromSuperview() {
        removeMonitors()
        super.removeFromSuperview()
      }

      private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
      }

      override func hitTest(_ point: NSPoint) -> NSView? {
        nil  // pass-through: let SwiftUI views handle all mouse events
      }
    }
  }

  extension View {
    func onKeyDown(_ handler: @escaping (NSEvent) -> Bool) -> some View {
      background(KeyDownHandler(handler: handler))
    }
  }
#endif

// MARK: - Text Editing

/// Ends text editing in the key window, like a click on the empty pane blurs
/// inputs in React Flow.
@MainActor
func endTextEditing() {
  #if canImport(UIKit)
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  #elseif canImport(AppKit)
    if let window = NSApp.keyWindow, window.firstResponder is NSText {
      window.makeFirstResponder(nil)
    }
  #endif
}
