import AppKit
import SwiftUI

private enum InvisibleHitLayer {
  static let color = NSColor(calibratedWhite: 1, alpha: 0.001).cgColor
}

final class ScrollForwardingHostingView<Content: View>: NSHostingView<Content> {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    wantsLayer = true
    // Fully clear pixels can drop out of a transparent NSPanel's hit path.
    layer?.backgroundColor = InvisibleHitLayer.color
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    if let hitView = super.hitTest(point) {
      return hitView
    }
    return bounds.contains(point) ? self : nil
  }

  override func scrollWheel(with event: NSEvent) {
    guard let scrollView = edgeNotesScrollView(containingWindowPoint: event.locationInWindow) else {
      super.scrollWheel(with: event)
      return
    }
    scrollView.scrollWheel(with: event)
  }
}

final class ScrollWheelForwardingBackgroundView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configure()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configure()
  }

  override var isOpaque: Bool { false }

  private func configure() {
    wantsLayer = true
    layer?.backgroundColor = InvisibleHitLayer.color
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    bounds.contains(point) ? self : nil
  }

  override func scrollWheel(with event: NSEvent) {
    if let scrollView = enclosingScrollView {
      scrollView.scrollWheel(with: event)
      return
    }

    if let scrollView = window?.contentView?.edgeNotesScrollView(containingWindowPoint: event.locationInWindow) {
      scrollView.scrollWheel(with: event)
      return
    }

    super.scrollWheel(with: event)
  }
}

extension NSView {
  func edgeNotesScrollView(containingWindowPoint windowPoint: NSPoint) -> NSScrollView? {
    guard !isHidden else { return nil }

    let localPoint = convert(windowPoint, from: nil)
    guard bounds.contains(localPoint) else { return nil }

    for subview in subviews.reversed() {
      if let scrollView = subview.edgeNotesScrollView(containingWindowPoint: windowPoint) {
        return scrollView
      }
    }

    if let scrollView = self as? NSScrollView,
       scrollView.identifier?.rawValue != "EdgeNotesInlineMarkdownEditor" {
      return scrollView
    }
    return nil
  }
}
