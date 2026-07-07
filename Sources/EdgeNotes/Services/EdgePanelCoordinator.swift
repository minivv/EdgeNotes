import AppKit
import SwiftUI

@MainActor
final class EdgePanelCoordinator: NSObject, ObservableObject {
  @Published var isPanelPinned: Bool {
    didSet {
      UserDefaults.standard.set(isPanelPinned, forKey: AppPreferences.Key.panelPinned)
    }
  }
  @Published var route: SidePanelRoute {
    didSet {
      UserDefaults.standard.set(route.rawValue, forKey: AppPreferences.Key.sidePanelRoute)
    }
  }

  private weak var store: NotesStore?
  private weak var settingsCoordinator: SettingsCoordinator?
  private var openBarWindow: EdgePanelWindow?
  private var notesPanelWindow: EdgePanelWindow?
  private var hideWorkItem: DispatchWorkItem?
  private var showWorkItem: DispatchWorkItem?
  private var localMouseMonitor: Any?
  private var globalMouseMonitor: Any?
  private var outsideTrackingTimer: Timer?
  private var mouseOutsideSince: Date?
  private var didConfigure = false
  private var pendingRefreshWorkItem: DispatchWorkItem?

  override init() {
    isPanelPinned = UserDefaults.standard.bool(forKey: AppPreferences.Key.panelPinned)
    let savedRoute = UserDefaults.standard.string(forKey: AppPreferences.Key.sidePanelRoute)
    route = savedRoute.flatMap(SidePanelRoute.init(rawValue:)) ?? .folders
    super.init()
  }

  func configure(store: NotesStore, settingsCoordinator: SettingsCoordinator? = nil) {
    self.store = store
    self.settingsCoordinator = settingsCoordinator
    guard !didConfigure else {
      scheduleRefreshFromSettings()
      return
    }

    didConfigure = true
    installOutsideClickMonitors()
    scheduleRefreshFromSettings()
  }

  func refreshFromSettings() {
    pendingRefreshWorkItem?.cancel()
    pendingRefreshWorkItem = nil
    showOpenBar()
    positionOpenBar()
    positionPanel()
    updatePanelRootView()
    updateOutsideTrackingForCollapseTrigger()
  }

  func togglePanel() {
    if notesPanelWindow?.isVisible == true {
      hidePanel()
    } else {
      showPanel(activate: true)
    }
  }

  func showPanel(activate: Bool = false) {
    guard let store else { return }
    cancelAutoHide()
    validateRoute()

    if notesPanelWindow == nil {
      let window = EdgePanelWindow(
        contentRect: panelFrame(),
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      window.level = .floating
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
      window.isOpaque = false
      window.backgroundColor = .clear
      window.hasShadow = true
      window.hidesOnDeactivate = false
      window.title = "EdgeNotes Side Panel"
      window.delegate = self
      notesPanelWindow = window
    }

    updatePanelRootView()
    positionPanel()

    if activate {
      notesPanelWindow?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    } else {
      notesPanelWindow?.orderFrontRegardless()
    }

    openBarWindow?.orderOut(nil)
    updateOutsideTrackingForCollapseTrigger()

    _ = store
  }

  func schedulePanelShow(activate: Bool = false) {
    cancelAutoHide()
    showWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      Task { @MainActor [weak self] in
        self?.showPanel(activate: activate)
      }
    }
    showWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + showDelay(), execute: workItem)
  }

  func hidePanel() {
    cancelAutoHide()
    notesPanelWindow?.orderOut(nil)
    outsideTrackingTimer?.invalidate()
    outsideTrackingTimer = nil
    showOpenBar()
  }

  func panelHoverChanged(_ isInside: Bool) {
    guard usesMouseLeaveCollapse else {
      cancelAutoHide()
      return
    }

    if isInside {
      cancelAutoHide()
    } else {
      scheduleAutoHide()
    }
  }

  func togglePinned() {
    isPanelPinned.toggle()
    if isPanelPinned {
      cancelAutoHide()
      stopOutsideTrackingTimer()
    } else {
      updateOutsideTrackingForCollapseTrigger()
    }
  }

  func collapseTriggerDidChange() {
    cancelAutoHide()
    updateOutsideTrackingForCollapseTrigger()
  }

  func hidePanelFromEmptyClick() {
    guard !isPanelPinned,
          notesPanelWindow?.isVisible == true
    else { return }
    hidePanel()
  }

  private var usesMouseLeaveCollapse: Bool {
    AppPreferences.panelCollapseTrigger == .mouseLeave
  }

  private func showOpenBar() {
    guard let store else { return }

    if openBarWindow == nil {
      let window = EdgePanelWindow(
        contentRect: openBarFrame(),
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      window.level = .floating
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
      window.isOpaque = false
      window.backgroundColor = .clear
      window.hasShadow = false
      window.hidesOnDeactivate = false
      window.title = "EdgeNotes Open Bar"
      openBarWindow = window
    }

    let side = EdgePanelSettings.side
    openBarWindow?.contentView = NSHostingView(
      rootView: OpenBarView(
        side: side,
        onHoverOpen: { [weak self] in
          self?.schedulePanelShow(activate: false)
        },
        onClickOpen: { [weak self] in
          self?.showPanel(activate: true)
        }
      )
      .environmentObject(store)
    )
    positionOpenBar()
    openBarWindow?.orderFrontRegardless()
  }

  private func updatePanelRootView() {
    guard let store, let notesPanelWindow, let settingsCoordinator else { return }
    let side = EdgePanelSettings.side
    notesPanelWindow.removeAllInteractiveRegions()
    notesPanelWindow.contentView = ScrollForwardingHostingView(
      rootView: PanelContainerView(
        side: side,
        onClose: { [weak self] in
          self?.hidePanel()
        },
        onHoverChanged: { [weak self] isInside in
          self?.panelHoverChanged(isInside)
        }
      )
      .environmentObject(store)
      .environmentObject(self)
      .environmentObject(settingsCoordinator)
    )
  }

  private func scheduleAutoHide(after delay: TimeInterval? = nil) {
    guard !isPanelPinned, usesMouseLeaveCollapse else { return }
    hideWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      Task { @MainActor [weak self] in
        self?.hidePanel()
      }
    }
    hideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + (delay ?? autoHideDelay()), execute: workItem)
  }

  private func cancelAutoHide() {
    hideWorkItem?.cancel()
    hideWorkItem = nil
  }

  private func showDelay() -> TimeInterval {
    let speed = UserDefaults.standard.string(forKey: AppPreferences.Key.displaySpeed) ?? "standard"
    switch speed {
    case "slow", "慢":
      return 0.35
    case "fast", "快":
      return 0.04
    default:
      return 0.15
    }
  }

  private func validateRoute() {
    guard route == .notes,
          let store
    else { return }

    guard let selectedFolderID = store.selectedFolderID else {
      return
    }

    if !store.folders.contains(where: { $0.id == selectedFolderID }) {
      route = .folders
    }
  }

  private func scheduleRefreshFromSettings() {
    pendingRefreshWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      Task { @MainActor [weak self] in
        self?.refreshFromSettings()
      }
    }
    pendingRefreshWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func installOutsideClickMonitors() {
    guard localMouseMonitor == nil, globalMouseMonitor == nil else { return }

    localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      Task { @MainActor [weak self] in
        self?.hidePanelIfOutsideClick()
      }
      return event
    }

    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.hidePanelIfOutsideClick()
      }
    }
  }

  private func hidePanelIfOutsideClick() {
    guard !isPanelPinned,
          let notesPanelWindow,
          notesPanelWindow.isVisible
    else { return }

    let mouseLocation = NSEvent.mouseLocation
    if notesPanelWindow.frame.contains(mouseLocation) {
      if notesPanelWindow.isEmptyPanelArea(screenPoint: mouseLocation) {
        hidePanel()
      }
      return
    }
    if let openBarWindow, openBarWindow.frame.contains(mouseLocation) {
      return
    }
    hidePanel()
  }

  private func updateOutsideTrackingForCollapseTrigger() {
    guard notesPanelWindow?.isVisible == true,
          !isPanelPinned,
          usesMouseLeaveCollapse
    else {
      stopOutsideTrackingTimer()
      return
    }

    startOutsideTrackingTimer()
  }

  private func startOutsideTrackingTimer() {
    guard usesMouseLeaveCollapse else {
      stopOutsideTrackingTimer()
      return
    }
    guard outsideTrackingTimer == nil else { return }
    mouseOutsideSince = nil
    outsideTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.trackMouseOutsidePanel()
      }
    }
  }

  private func stopOutsideTrackingTimer() {
    outsideTrackingTimer?.invalidate()
    outsideTrackingTimer = nil
    mouseOutsideSince = nil
  }

  private func trackMouseOutsidePanel() {
    guard !isPanelPinned,
          usesMouseLeaveCollapse,
          let notesPanelWindow,
          notesPanelWindow.isVisible
    else {
      mouseOutsideSince = nil
      return
    }

    let mouseLocation = NSEvent.mouseLocation
    if notesPanelWindow.frame.contains(mouseLocation),
       !notesPanelWindow.isEmptyPanelArea(screenPoint: mouseLocation) {
      mouseOutsideSince = nil
      return
    }
    if let openBarWindow, openBarWindow.frame.contains(mouseLocation) {
      mouseOutsideSince = nil
      return
    }

    if mouseOutsideSince == nil {
      mouseOutsideSince = Date()
      return
    }

    if let mouseOutsideSince,
       Date().timeIntervalSince(mouseOutsideSince) >= autoHideDelay() {
      hidePanel()
    }
  }

  private func positionOpenBar() {
    openBarWindow?.setFrame(openBarFrame(), display: true)
  }

  private func positionPanel() {
    let frame = panelFrame()
    notesPanelWindow?.minSize = frame.size
    notesPanelWindow?.maxSize = frame.size
    notesPanelWindow?.setFrame(frame, display: true)
  }

  private func openBarFrame() -> NSRect {
    let visible = activeVisibleFrame()
    let width: CGFloat = 14
    let height: CGFloat = min(180, visible.height * 0.28)
    let side = EdgePanelSettings.side
    let x = side == .left ? visible.minX : visible.maxX - width
    let y = visible.midY - height / 2
    return NSRect(x: x, y: y, width: width, height: height)
  }

  private func panelFrame() -> NSRect {
    let visible = activeVisibleFrame()
    let width = min(CGFloat(388), visible.width - 16)
    let height = max(520, visible.height - 24)
    let side = EdgePanelSettings.side
    let x = side == .left ? visible.minX : visible.maxX - width
    let y = visible.minY + 12
    return NSRect(x: x, y: y, width: width, height: min(height, visible.height - 24))
  }

  private func activeVisibleFrame() -> NSRect {
    selectedScreen()?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
  }

  private func selectedScreen() -> NSScreen? {
    let preference = EdgePanelSettings.screenPreference

    if preference == ScreenPreference.mouse.rawValue {
      let mouseLocation = NSEvent.mouseLocation
      return NSScreen.screens.first { screen in
        screen.frame.contains(mouseLocation)
      } ?? primaryScreen()
    }

    if preference.hasPrefix(ScreenPreference.displayPrefix) {
      let displayID = String(preference.dropFirst(ScreenPreference.displayPrefix.count))
      return NSScreen.screens.first { screen in
        screen.edgeNotesDisplayID == displayID
      } ?? primaryScreen()
    }

    return primaryScreen()
  }

  private func primaryScreen() -> NSScreen? {
    NSScreen.screens.first ?? NSScreen.main
  }

  private func autoHideDelay() -> TimeInterval {
    let speed = UserDefaults.standard.string(forKey: AppPreferences.Key.displaySpeed) ?? "standard"
    switch speed {
    case "slow", "慢":
      return 0.9
    case "fast", "快":
      return 0.35
    default:
      return 0.65
    }
  }

  deinit {
    if let localMouseMonitor {
      NSEvent.removeMonitor(localMouseMonitor)
    }
    if let globalMouseMonitor {
      NSEvent.removeMonitor(globalMouseMonitor)
    }
    pendingRefreshWorkItem?.cancel()
    outsideTrackingTimer?.invalidate()
    outsideTrackingTimer = nil
  }
}

extension EdgePanelCoordinator: NSWindowDelegate {
  nonisolated func windowDidResignKey(_ notification: Notification) {
    Task { @MainActor [weak self] in
      guard let self,
            notification.object as? NSWindow === self.notesPanelWindow
      else { return }
      guard self.usesMouseLeaveCollapse else { return }
      self.scheduleAutoHide(after: 0.12)
    }
  }
}

final class EdgePanelWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
  private var interactiveRegions: [String: NSRect] = [:]

  func setInteractiveRegion(id: String, rect: NSRect?) {
    if let rect {
      interactiveRegions[id] = rect
    } else {
      interactiveRegions.removeValue(forKey: id)
    }
  }

  func removeAllInteractiveRegions() {
    interactiveRegions.removeAll()
  }

  func isEmptyPanelArea(screenPoint: NSPoint) -> Bool {
    guard frame.contains(screenPoint),
          let contentView
    else { return false }

    let windowPoint = convertPoint(fromScreen: screenPoint)
    let contentPoint = contentView.convert(windowPoint, from: nil)
    guard contentView.bounds.contains(contentPoint) else { return false }

    if interactiveRegions.values.contains(where: { $0.insetBy(dx: -1, dy: -1).contains(windowPoint) }) {
      return false
    }

    guard let hitView = contentView.hitTest(contentPoint) else {
      return true
    }

    return hitView.edgeNotesIsEmptyPanelHitView()
  }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .scrollWheel,
       let scrollView = contentView?.edgeNotesScrollView(containingWindowPoint: event.locationInWindow) {
      scrollView.scrollWheel(with: event)
      return
    }

    super.sendEvent(event)
  }
}

private extension NSView {
  func edgeNotesIsEmptyPanelHitView() -> Bool {
    if self is ScrollWheelForwardingBackgroundView {
      return true
    }
    if self is NSScroller {
      return false
    }
    if edgeNotesBelongsToInlineMarkdownEditor {
      return false
    }
    return true
  }

  var edgeNotesBelongsToInlineMarkdownEditor: Bool {
    if let scrollView = self as? NSScrollView {
      return scrollView.identifier?.rawValue == "EdgeNotesInlineMarkdownEditor"
    }
    return enclosingScrollView?.identifier?.rawValue == "EdgeNotesInlineMarkdownEditor"
  }
}
