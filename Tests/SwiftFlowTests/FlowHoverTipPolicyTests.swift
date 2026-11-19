import Foundation
import Testing

@testable import SwiftFlow

@Suite("FlowHoverTipPolicy")
struct FlowHoverTipPolicyTests {
  @Test func canvasDelayIsAbout150msAndSkipDelayOpensImmediately() {
    #expect(FlowHoverTipPolicy.delayMs == 150)
    let now = Date()
    #expect(
      FlowHoverTipPolicy.openDelayMs(preferred: 150, lastClosedAt: nil, now: now) == 150)
    #expect(
      FlowHoverTipPolicy.openDelayMs(
        preferred: 150, lastClosedAt: now.addingTimeInterval(-0.05), now: now) == 0)
    #expect(
      FlowHoverTipPolicy.openDelayMs(
        preferred: 150, lastClosedAt: now.addingTimeInterval(-1), now: now) == 150)
  }

  @Test func leavingOrCancellingBeforeShowDoesNotPresent() {
    #expect(FlowHoverTipPolicy.shouldShow(hovering: true, cancelled: false))
    #expect(!FlowHoverTipPolicy.shouldShow(hovering: false, cancelled: false))
    #expect(!FlowHoverTipPolicy.shouldShow(hovering: true, cancelled: true))
  }

  @Test func positionFlipsWhenThePreferredSideWouldClip() {
    #if canImport(AppKit)
      let visible = CGRect(x: 0, y: 0, width: 400, height: 300)
      let nearTop = CGRect(x: 100, y: 260, width: 32, height: 32)
      let tip = CGSize(width: 80, height: 24)
      let origin = FlowHoverTipPolicy.position(anchor: nearTop, tipSize: tip, visible: visible)
      #expect(origin.y + tip.height <= visible.maxY + 0.5)
      #expect(origin.y + tip.height <= nearTop.minY + 0.5)
      #expect(origin.x >= visible.minX && origin.x + tip.width <= visible.maxX + 0.5)
    #endif
  }


  @Test func screenAnchorAppliesZoomPanAndWindowOriginOnce() {
    #if canImport(AppKit)
      let windowFrame = CGRect(x: -1200, y: 200, width: 800, height: 600)
      let windowRect = CGRect(x: 40, y: 80, width: 22, height: 22)
      let screen = FlowHoverTipPolicy.screenRect(
        windowRect: windowRect, windowFrameOnScreen: windowFrame)
      #expect(screen == CGRect(x: -1160, y: 280, width: 22, height: 22))

      let flow = CGRect(x: 10, y: 20, width: 22, height: 22)
      let inCanvas = FlowHoverTipPolicy.canvasRect(
        flow, zoom: 2, offset: CGSize(width: 50, height: 80))
      #expect(inCanvas == CGRect(x: 70, y: 120, width: 44, height: 44))
      let win = FlowHoverTipPolicy.windowRect(
        fromFlippedContent: inCanvas, contentHeight: 400,
        contentOriginInWindow: CGPoint(x: 0, y: 22))
      #expect(abs(win.origin.y - (22 + 400 - 164)) < 0.01)
      let screen2 = FlowHoverTipPolicy.screenRect(
        windowRect: win, windowFrameOnScreen: windowFrame)
      #expect(abs(screen2.origin.x - (windowFrame.minX + win.minX)) < 0.01)
    #endif
  }

  @Test func controlHoverArrowWinsAndStackStaysBalanced() {
    #if canImport(AppKit)
      #expect(FlowControlCursorPolicy.resolved(overControl: true, tool: .grab) == .default)
      #expect(FlowControlCursorPolicy.resolved(overControl: true, tool: .default) == .default)
      #expect(FlowControlCursorPolicy.resolved(overControl: false, tool: .grab) == .grab)
      #expect(FlowControlCursorPolicy.resolved(overControl: false, tool: .default) == .default)
      let enter = FlowControlCursorPolicy.stackChange(entering: true, isPushed: false)
      #expect(enter.push && !enter.pop && enter.isPushed)
      let stay = FlowControlCursorPolicy.stackChange(entering: true, isPushed: true)
      #expect(!stay.push && !stay.pop && stay.isPushed)
      let leave = FlowControlCursorPolicy.stackChange(entering: false, isPushed: true)
      #expect(!leave.push && leave.pop && !leave.isPushed)
      let gone = FlowControlCursorPolicy.stackChange(entering: false, isPushed: false)
      #expect(!gone.push && !gone.pop && !gone.isPushed)
    #endif
  }
}
