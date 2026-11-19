import CoreGraphics
import Foundation
import Testing

@testable import SwiftFlow

#if canImport(AppKit)
  import AppKit
#endif

@Suite("Trackpad canvas routing")
struct TrackpadCanvasRouterTests {

  @Test func pinchAccumulatesFromStartAndEnds() {
    var router = TrackpadCanvasRouter()
    let first = router.handleMagnify(
      increment: 0.2, ended: false, isSameWindow: true, isInBounds: true, enabled: true)
    #expect(first == .magnify(factorFromStart: 1.2, ended: false))
    #expect(router.isMagnifying)
    let second = router.handleMagnify(
      increment: 0.1, ended: false, isSameWindow: true, isInBounds: true, enabled: true)
    #expect(second == .magnify(factorFromStart: 1.3, ended: false))
    let ended = router.handleMagnify(
      increment: 0, ended: true, isSameWindow: true, isInBounds: true, enabled: true)
    #expect(ended == .magnify(factorFromStart: 1, ended: true))
    #expect(!router.isMagnifying)
  }

  @Test func pinchOutsideTheCanvasOrAnotherWindowIsIgnored() {
    var router = TrackpadCanvasRouter()
    #expect(
      router.handleMagnify(
        increment: 0.2, ended: false, isSameWindow: false, isInBounds: true, enabled: true)
        == .pass)
    #expect(
      router.handleMagnify(
        increment: 0.2, ended: false, isSameWindow: true, isInBounds: false, enabled: true)
        == .pass)
    #expect(!router.isMagnifying)
  }

  @Test func disabledPinchPassesTheEventThrough() {
    var router = TrackpadCanvasRouter()
    #expect(
      router.handleMagnify(
        increment: 0.4, ended: false, isSameWindow: true, isInBounds: true, enabled: false)
        == .pass)
    #expect(!router.isMagnifying)
  }

  @Test func scrollDuringPinchIsConsumedAndDoesNotPan() {
    var router = TrackpadCanvasRouter()
    _ = router.handleMagnify(
      increment: 0.2, ended: false, isSameWindow: true, isInBounds: true, enabled: true)
    #expect(
      router.handleScroll(
        delta: CGSize(width: 20, height: -10), ended: false, phaseBegan: false,
        isMomentum: false, isSameWindow: true, isInBounds: true, enabled: true)
        == .consume)
    _ = router.handleMagnify(
      increment: 0, ended: true, isSameWindow: true, isInBounds: true, enabled: true)
    // Residual momentum after pinch is also ignored until a new scroll begins.
    #expect(
      router.handleScroll(
        delta: CGSize(width: 8, height: 0), ended: false, phaseBegan: false,
        isMomentum: true, isSameWindow: true, isInBounds: true, enabled: true)
        == .consume)
    let resumed = router.handleScroll(
      delta: CGSize(width: 12, height: 0), ended: false, phaseBegan: true,
      isMomentum: false, isSameWindow: true, isInBounds: true, enabled: true)
    #expect(resumed == .scroll(delta: CGSize(width: 12, height: 0), ended: false))
  }

  @Test func scrollStillPansWhenNotPinching() {
    var router = TrackpadCanvasRouter()
    #expect(
      router.handleScroll(
        delta: CGSize(width: 15, height: -4), ended: false, phaseBegan: true,
        isMomentum: false, isSameWindow: true, isInBounds: true, enabled: true)
        == .scroll(delta: CGSize(width: 15, height: -4), ended: false))
    #expect(
      router.handleScroll(
        delta: .zero, ended: true, phaseBegan: false, isMomentum: false,
        isSameWindow: true, isInBounds: true, enabled: true)
        == .scroll(delta: .zero, ended: true))
  }

  @Test func pinchUpdatesViewportAroundAnchorAndClamps() {
    let start = Viewport(x: 10, y: 20, zoom: 1)
    let anchor = CGPoint(x: 100, y: 80)
    let zoomed = start.zoomed(to: start.zoom * 1.25, around: anchor)
    #expect(zoomed.zoom == 1.25)
    // The flow point under the anchor stays fixed.
    let flowX = (anchor.x - start.x) / start.zoom
    #expect(abs((anchor.x - zoomed.x) / zoomed.zoom - flowX) < 0.0001)

    #expect(start.zoomed(to: 0.01, around: anchor).zoom == Viewport.minZoom)
    #expect(start.zoomed(to: 99, around: anchor).zoom == Viewport.maxZoom)
  }
}

#if os(macOS)
  @Suite("Trackpad canvas AppKit monitor")
  @MainActor
  struct TrackpadCanvasMonitorTests {

    @Test func magnifyOnTheViewReachesTheCallback() {
      // Drive the same `route` entry the local NSEvent monitor calls. A real
      // NSWindow is not opened here so the test does not install a process-wide
      // local monitor or depend on a live trackpad.
      let view = TrackpadCanvasNSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

      var factors: [CGFloat] = []
      var locations: [CGPoint] = []
      var ends: [Bool] = []
      var scrolls: [CGSize] = []
      view.onMagnify = { factor, location, ended in
        factors.append(factor)
        locations.append(location)
        ends.append(ended)
      }
      view.onScroll = { delta, _, _ in scrolls.append(delta) }

      let inside = CGPoint(x: 120, y: 90)
      let begin = view.route(
        TrackpadCanvasNSEvent(
          kind: .magnify(increment: 0.25, ended: false),
          isSameWindow: true,
          locationInView: inside))
      #expect(begin == .magnify(factorFromStart: 1.25, ended: false))
      #expect(factors == [1.25])
      #expect(locations == [inside])
      #expect(ends == [false])

      // The same path the canvas uses: native factor -> viewport + end persist flag.
      var viewport = Viewport(x: 0, y: 0, zoom: 1)
      let startZoom = viewport.zoom
      viewport = viewport.zoomed(to: startZoom * factors[0], around: inside)
      #expect(viewport.zoom == 1.25)

      let ended = view.route(
        TrackpadCanvasNSEvent(
          kind: .magnify(increment: 0, ended: true),
          isSameWindow: true,
          locationInView: inside))
      #expect(ended == .magnify(factorFromStart: 1, ended: true))
      #expect(ends == [false, true])

      // Scroll mid-setup already ended; a fresh scroll still pans.
      let scrolled = view.route(
        TrackpadCanvasNSEvent(
          kind: .scroll(
            delta: CGSize(width: 30, height: 0), ended: false, phaseBegan: true,
            isMomentum: false),
          isSameWindow: true,
          locationInView: inside))
      #expect(scrolled == .scroll(delta: CGSize(width: 30, height: 0), ended: false))
      #expect(scrolls == [CGSize(width: 30, height: 0)])

      // Other windows and out-of-bounds locations are not consumed.
      #expect(
        view.route(
          TrackpadCanvasNSEvent(
            kind: .magnify(increment: 0.5, ended: false),
            isSameWindow: false,
            locationInView: inside)) == .pass)
      #expect(
        view.route(
          TrackpadCanvasNSEvent(
            kind: .magnify(increment: 0.5, ended: false),
            isSameWindow: true,
            locationInView: CGPoint(x: 900, y: 900))) == .pass)
      #expect(factors == [1.25, 1])
    }

    @Test func magnifyDisabledDoesNotConsumeOrCallback() {
      let view = TrackpadCanvasNSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
      var called = 0
      view.onMagnify = nil
      view.onScroll = { _, _, _ in called += 1 }
      let outcome = view.route(
        TrackpadCanvasNSEvent(
          kind: .magnify(increment: 0.4, ended: false),
          isSameWindow: true,
          locationInView: CGPoint(x: 10, y: 10)))
      #expect(outcome == .pass)
      #expect(called == 0)
    }
  }
#endif
