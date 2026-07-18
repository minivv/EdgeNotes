import AppKit
import MarkdownEngine
import SwiftUI

struct InlineMarkdownEditor: View {
  @Binding var text: String
  @Binding var height: CGFloat

  @State private var selectionToolbar: MarkdownSelectionToolbarState?

  var textColor: Color
  var accentColor: Color
  var toolbarBackgroundColor: Color
  var toolbarTextColor: Color
  var toolbarAccentColor: Color
  var fontSize: CGFloat
  var minHeight: CGFloat
  var isFocused = false
  var focusAtStart: Binding<Bool> = .constant(false)
  var onFocus: () -> Void = {}
  var documentId = "default"
  var fitsContent = true

  var body: some View {
    NativeTextViewWrapper(
      text: $text,
      configuration: configuration,
      fontSize: fontSize,
      documentId: documentId
    )
    .id(editorAppearanceID)
    .frame(minHeight: minHeight, alignment: .topLeading)
    .background(
        InlineMarkdownFocusBridge(
          selectionToolbar: $selectionToolbar,
          isFocused: isFocused,
          focusAtStart: focusAtStart,
          onFocus: onFocus,
          documentId: documentId,
          listIndentPerLevel: listIndentPerLevel
        )
      )
    .background(heightReader)
    .overlay(alignment: .topLeading) {
      GeometryReader { proxy in
        if let selectionToolbar {
          MarkdownSelectionToolbar(
            bus: toolbarBus,
            backgroundColor: toolbarBackgroundColor,
            textColor: toolbarTextColor,
            accentColor: toolbarAccentColor
          )
          .position(toolbarPosition(for: selectionToolbar.rect, in: proxy.size))
          .transition(.opacity.combined(with: .scale(scale: 0.94)))
          .zIndex(2)
        }
      }
    }
    .animation(.easeOut(duration: 0.12), value: selectionToolbar)
  }

  private var heightReader: some View {
    GeometryReader { proxy in
      Color.clear
        .onAppear {
          syncHeight(proxy.size.height)
        }
        .onChange(of: proxy.size.height) { _, newHeight in
          syncHeight(newHeight)
        }
    }
  }

  private var toolbarBus: MarkdownToolbarBus {
    MarkdownToolbarBus(documentId: documentId)
  }

  private var listIndentPerLevel: CGFloat {
    20
  }

  private var editorAppearanceID: String {
    [textColor.themeHex ?? "", accentColor.themeHex ?? ""].joined(separator: "|")
  }

  private var configuration: MarkdownEditorConfiguration {
    var config = MarkdownEditorConfiguration.default
    let bodyText = NSColor(textColor)
    let accent = NSColor(accentColor)

    config.theme = MarkdownEditorTheme(
      bodyText: bodyText,
      mutedText: bodyText.withAlphaComponent(0.62),
      disabledText: bodyText.withAlphaComponent(0.36),
      headingMarker: accent,
      link: accent,
      incompleteLink: accent.withAlphaComponent(0.72),
      findMatchHighlight: accent.withAlphaComponent(0.18),
      findCurrentMatchHighlight: accent.withAlphaComponent(0.32),
      latexLightModeText: bodyText,
      latexDarkModeText: bodyText,
      strikethroughColor: bodyText,
      highlightColor: accent.withAlphaComponent(0.22)
    )
    config.services = MarkdownEditorServices(
      syntaxHighlighter: EdgeNotesSyntaxHighlighter(),
      bus: toolbarBus.markdownBus
    )
    config.heightBehavior = fitsContent ? .fitsContent : .scrolls
    config.scrollers = fitsContent ? .hidden : .vertical
    config.textInsets = TextInsets(horizontal: 0, vertical: 4)
    config.codeBlock = CodeBlockStyle(fontSizeScale: 1, paragraphSpacing: 0, horizontalIndent: 0)
    config.inlineCode = InlineCodeStyle(fontSizeScale: 1)
    config.paragraph = ParagraphStyle(spacingFactor: 0.24, lineHeightExtraSpacing: 2)
    config.lists = ListStyle(
      helpersEnabled: true,
      autoClosePairsEnabled: true,
      indentPerLevel: listIndentPerLevel,
      maximumNestingLevel: 4,
      extraLineHeight: 2
    )
    return config
  }

  private func toolbarPosition(for rect: CGRect, in size: CGSize) -> CGPoint {
    let toolbarWidth: CGFloat = 234
    let toolbarHeight: CGFloat = 34
    let margin: CGFloat = 6
    let x = min(
      max(rect.midX, toolbarWidth / 2 + margin),
      max(toolbarWidth / 2 + margin, size.width - toolbarWidth / 2 - margin)
    )
    let yAbove = rect.minY - toolbarHeight / 2 - 8
    let yBelow = rect.maxY + toolbarHeight / 2 + 8
    let y = yAbove > toolbarHeight / 2 + margin
      ? yAbove
      : min(yBelow, max(toolbarHeight / 2 + margin, size.height - toolbarHeight / 2 - margin))
    return CGPoint(x: x, y: y)
  }

  private func syncHeight(_ nextHeight: CGFloat) {
    let resolvedHeight = max(minHeight, ceil(nextHeight))
    guard abs(height - resolvedHeight) > 0.5 else { return }
    DispatchQueue.main.async {
      height = resolvedHeight
    }
  }
}

private struct MarkdownSelectionToolbarState: Equatable {
  var rect: CGRect
}

enum MarkdownTaskList {
  static func replacement(in text: NSString, selectedRange: NSRange) -> (range: NSRange, text: String)? {
    guard selectedRange.length > 0, NSMaxRange(selectedRange) <= text.length else { return nil }

    let lineRange = text.lineRange(for: selectedRange)
    let original = text.substring(with: lineRange) as NSString
    let replacement = NSMutableString()
    var offset = 0

    while offset < original.length {
      let range = original.lineRange(for: NSRange(location: offset, length: 0))
      replacement.append(taskLine(from: original.substring(with: range)))
      offset = NSMaxRange(range)
    }

    return (lineRange, replacement as String)
  }

  private static func taskLine(from line: String) -> String {
    let hasNewline = line.hasSuffix("\n") || line.hasSuffix("\r")
    let content = line.trimmingCharacters(in: .newlines)
    guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return line }

    let indentation = String(content.prefix { $0 == " " || $0 == "\t" })
    var body = String(content.dropFirst(indentation.count))
    let patterns = [
      #"^- \[[ xX]\]\s*"#,
      #"^[-+*]\s+"#,
      #"^\d+[.)]\s+"#
    ]
    for pattern in patterns {
      if let range = body.range(of: pattern, options: .regularExpression) {
        body.removeSubrange(range)
        break
      }
    }

    return indentation + "- [ ] " + body + (hasNewline ? "\n" : "")
  }
}

private struct MarkdownToolbarBus {
  let documentId: String

  var markdownBus: MarkdownEditorBus {
    MarkdownEditorBus(
      applyBoldRequest: name("bold"),
      applyItalicRequest: name("italic"),
      applyStrikethroughRequest: name("strikethrough"),
      applyBlockquoteRequest: name("blockquote"),
      applyUnorderedListRequest: name("unorderedList"),
      applyOrderedListRequest: name("orderedList")
    )
  }

  func post(_ command: Command) {
    NotificationCenter.default.post(name: notificationName(for: command), object: nil)
  }

  var taskListRequest: Notification.Name {
    name("taskList")
  }

  private func notificationName(for command: Command) -> Notification.Name {
    switch command {
    case .bold:
      name("bold")
    case .italic:
      name("italic")
    case .strikethrough:
      name("strikethrough")
    case .blockquote:
      name("blockquote")
    case .unorderedList:
      name("unorderedList")
    case .orderedList:
      name("orderedList")
    case .taskList:
      name("taskList")
    }
  }

  private func name(_ suffix: String) -> Notification.Name {
    Notification.Name("EdgeNotes.Markdown.\(documentId).\(suffix)")
  }

  enum Command {
    case bold
    case italic
    case strikethrough
    case blockquote
    case unorderedList
    case orderedList
    case taskList
  }
}

private struct MarkdownSelectionToolbar: View {
  var bus: MarkdownToolbarBus
  var backgroundColor: Color
  var textColor: Color
  var accentColor: Color

  var body: some View {
    HStack(spacing: 2) {
      toolbarButton("B", help: "加粗") {
        bus.post(.bold)
      }
      .font(.system(size: 13, weight: .bold))

      toolbarButton("I", help: "斜体") {
        bus.post(.italic)
      }
      .italic()

      toolbarButton("S", help: "删除线") {
        bus.post(.strikethrough)
      }
      .strikethrough()

      divider

      toolbarIcon("list.bullet", help: "无序列表") {
        bus.post(.unorderedList)
      }

      toolbarIcon("list.number", help: "有序列表") {
        bus.post(.orderedList)
      }

      toolbarIcon("checklist", help: "待办列表") {
        bus.post(.taskList)
      }

      toolbarIcon("quote.opening", help: "引用") {
        bus.post(.blockquote)
      }
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 4)
    .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(accentColor.opacity(0.72), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
  }

  private var divider: some View {
    Rectangle()
      .fill(textColor.opacity(0.20))
      .frame(width: 1, height: 18)
      .padding(.horizontal, 3)
  }

  private func toolbarButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .frame(width: 28, height: 26)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(textColor)
    .help(help)
  }

  private func toolbarIcon(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 28, height: 26)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(textColor)
    .help(help)
  }
}

private struct EdgeNotesSyntaxHighlighter: SyntaxHighlighter {
  func codeFont(size: CGFloat) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: .regular)
  }

  func backgroundColor() -> NSColor {
    .clear
  }

  func highlight(code: String, language: String?) -> NSAttributedString? {
    nil
  }

  var appearanceDidChangeNotification: Notification.Name? {
    nil
  }
}

private struct InlineMarkdownFocusBridge: NSViewRepresentable {
  var selectionToolbar: Binding<MarkdownSelectionToolbarState?>
  var isFocused: Bool
  var focusAtStart: Binding<Bool>
  var onFocus: () -> Void
  var documentId: String
  var listIndentPerLevel: CGFloat

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> FocusBridgeView {
    FocusBridgeView()
  }

  func updateNSView(_ nsView: FocusBridgeView, context: Context) {
    context.coordinator.parent = self
    DispatchQueue.main.async {
      context.coordinator.refresh(from: nsView)
    }
  }

  final class Coordinator {
    var parent: InlineMarkdownFocusBridge?
    private weak var observedTextView: NSTextView?
    private weak var bridgeView: NSView?
    private var beginEditingObserver: NSObjectProtocol?
    private var selectionObserver: NSObjectProtocol?
    private var textChangeObserver: NSObjectProtocol?
    private var taskListObserver: NSObjectProtocol?
    private var isApplyingListStyle = false

    deinit {
      removeObservers()
    }

    func refresh(from bridgeView: FocusBridgeView) {
      self.bridgeView = bridgeView
      guard let parent,
            let textView = bridgeView.closestMarkdownTextView()
      else { return }

      textView.enclosingScrollView?.identifier = NSUserInterfaceItemIdentifier("EdgeNotesInlineMarkdownEditor")
      observe(textView: textView)
      scheduleListIndentFix(for: textView)
      updateToolbar(for: textView, bridgeView: bridgeView)

      guard parent.isFocused else { return }
      textView.window?.makeFirstResponder(textView)

      if parent.focusAtStart.wrappedValue {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        DispatchQueue.main.async {
          parent.focusAtStart.wrappedValue = false
        }
      }
    }

    private func observe(textView: NSTextView) {
      guard observedTextView !== textView else { return }
      removeObservers()

      observedTextView = textView
      let center = NotificationCenter.default

      beginEditingObserver = center.addObserver(
        forName: NSText.didBeginEditingNotification,
        object: textView,
        queue: .main
      ) { [weak self] _ in
        self?.parent?.onFocus()
      }

      selectionObserver = center.addObserver(
        forName: NSTextView.didChangeSelectionNotification,
        object: textView,
        queue: .main
      ) { [weak self] _ in
        guard let self, let bridgeView = self.bridgeView else { return }
        self.updateToolbar(for: textView, bridgeView: bridgeView)
        self.scheduleListIndentFix(for: textView)
      }

      textChangeObserver = center.addObserver(
        forName: NSText.didChangeNotification,
        object: textView,
        queue: .main
      ) { [weak self] _ in
        guard let self, let bridgeView = self.bridgeView else { return }
        self.updateToolbar(for: textView, bridgeView: bridgeView)
        self.scheduleListIndentFix(for: textView)
      }

      if let parent {
        taskListObserver = center.addObserver(
          forName: MarkdownToolbarBus(documentId: parent.documentId).taskListRequest,
          object: nil,
          queue: .main
        ) { [weak self, weak textView] _ in
          guard let self, let textView else { return }
          self.applyTaskList(to: textView)
        }
      }

    }

    private func removeObservers() {
      let center = NotificationCenter.default
      [beginEditingObserver, selectionObserver, textChangeObserver, taskListObserver].compactMap { $0 }.forEach {
        center.removeObserver($0)
      }
      beginEditingObserver = nil
      selectionObserver = nil
      textChangeObserver = nil
      taskListObserver = nil
    }

    private func updateToolbar(for textView: NSTextView, bridgeView: NSView) {
      guard let parent else { return }
      let selectedRange = textView.selectedRange()

      guard selectedRange.length > 0,
            let window = textView.window
      else {
        parent.selectionToolbar.wrappedValue = nil
        return
      }

      var actualRange = NSRange(location: 0, length: 0)
      let screenRect = textView.firstRect(forCharacterRange: selectedRange, actualRange: &actualRange)
      guard !screenRect.isEmpty, screenRect.width.isFinite, screenRect.height.isFinite else {
        parent.selectionToolbar.wrappedValue = nil
        return
      }

      let windowRect = window.convertFromScreen(screenRect)
      let localRect = bridgeView.convert(windowRect, from: nil)
      let flippedRect = CGRect(
        x: localRect.minX,
        y: bridgeView.bounds.height - localRect.maxY,
        width: max(localRect.width, 1),
        height: max(localRect.height, 1)
      )

      parent.selectionToolbar.wrappedValue = MarkdownSelectionToolbarState(rect: flippedRect)
    }

    private func applyTaskList(to textView: NSTextView) {
      let text = textView.string as NSString
      let selectedRange = textView.selectedRange()
      guard let change = MarkdownTaskList.replacement(in: text, selectedRange: selectedRange),
            textView.shouldChangeText(in: change.range, replacementString: change.text)
      else { return }

      textView.replaceCharacters(in: change.range, with: change.text)
      textView.didChangeText()
      textView.setSelectedRange(NSRange(location: change.range.location, length: (change.text as NSString).length))
      scheduleListIndentFix(for: textView)
    }

    private func scheduleListIndentFix(for textView: NSTextView) {
      applyListIndentFixSoon(for: textView, delay: 0)
      applyListIndentFixSoon(for: textView, delay: 0.05)
      applyListIndentFixSoon(for: textView, delay: 0.16)
    }

    private func applyListIndentFixSoon(for textView: NSTextView, delay: TimeInterval) {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak textView] in
        guard let self, let textView else { return }
        self.applyListIndentFix(to: textView)
      }
    }

    private func applyListIndentFix(to textView: NSTextView) {
      guard let parent,
            !isApplyingListStyle,
            let textStorage = textView.textStorage
      else { return }

      let nsText = textView.string as NSString
      guard nsText.length > 0 else { return }

      isApplyingListStyle = true
      defer { isApplyingListStyle = false }

      textStorage.beginEditing()
      neutralizeCodeMarkup(in: textStorage, text: nsText, textView: textView)
      enumerateListLines(in: nsText) { item in
        let lineRange = item.lineRange
        guard lineRange.location < textStorage.length else { return }

        let baseFont = textStorage.attribute(.font, at: lineRange.location, effectiveRange: nil) as? NSFont
          ?? textView.font
          ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let prefixWidth = (item.fullPrefix as NSString).size(withAttributes: [.font: baseFont]).width
        let depth = CGFloat(Self.indentLevel(from: item.leadingWhitespace)) * parent.listIndentPerLevel
        let paragraphStyle = (textStorage.attribute(.paragraphStyle, at: lineRange.location, effectiveRange: nil) as? NSParagraphStyle)?
          .mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()

        if let prefixBeforeCheckbox = item.prefixBeforeCheckbox {
          let hiddenPrefixWidth = (prefixBeforeCheckbox as NSString).size(withAttributes: [.font: baseFont]).width
          let visiblePrefixWidth = max(0, prefixWidth - hiddenPrefixWidth)
          paragraphStyle.firstLineHeadIndent = depth - hiddenPrefixWidth
          paragraphStyle.headIndent = depth + visiblePrefixWidth
        } else {
          paragraphStyle.firstLineHeadIndent = depth
          paragraphStyle.headIndent = depth + prefixWidth
        }

        paragraphStyle.defaultTabInterval = parent.listIndentPerLevel
        paragraphStyle.tabStops = (1...12).map {
          NSTextTab(textAlignment: .left, location: CGFloat($0) * parent.listIndentPerLevel)
        }

        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
      }
      textStorage.endEditing()
      textView.setNeedsDisplay(textView.visibleRect)
    }

    private func neutralizeCodeMarkup(in textStorage: NSTextStorage, text: NSString, textView: NSTextView) {
      let baseFont = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
      let baseColor = textView.textColor ?? NSColor.labelColor
      let plainAttributes: [NSAttributedString.Key: Any] = [
        .font: baseFont,
        .foregroundColor: baseColor
      ]

      for block in MarkdownCodeRanges.codeBlocks(in: text) where NSMaxRange(block.fullRange) <= textStorage.length {
        textStorage.addAttributes(plainAttributes, range: block.fullRange)
        textStorage.removeAttribute(.backgroundColor, range: block.fullRange)
        textStorage.removeAttribute(.paragraphStyle, range: block.fullRange)
        textStorage.removeAttribute(.spellingState, range: block.fullRange)
      }

      MarkdownCodeRanges.inlineCodeRegex.enumerateMatches(
        in: text as String,
        range: NSRange(location: 0, length: text.length)
      ) { match, _, _ in
        guard let match,
              NSMaxRange(match.range) <= textStorage.length
        else { return }

        textStorage.addAttributes(plainAttributes, range: match.range)
        textStorage.removeAttribute(.backgroundColor, range: match.range)
        textStorage.removeAttribute(.paragraphStyle, range: match.range)
        textStorage.removeAttribute(.spellingState, range: match.range)
      }
    }

    private func enumerateListLines(
      in nsText: NSString,
      body: (MarkdownListLine) -> Void
    ) {
      let regex = Self.listLineRegex
      var location = 0

      while location < nsText.length {
        let fullLineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
        var lineRange = fullLineRange
        while lineRange.length > 0 {
          let last = nsText.character(at: NSMaxRange(lineRange) - 1)
          guard last == 0x0A || last == 0x0D else { break }
          lineRange.length -= 1
        }

        let line = nsText.substring(with: lineRange) as NSString
        if let match = regex.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)) {
          let leadingWhitespace = line.substring(with: match.range(at: 1))
          let markerRange = match.range(at: 2)
          let fullPrefixRange = NSRange(
            location: markerRange.location,
            length: NSMaxRange(match.range) - markerRange.location
          )
          let fullPrefix = line.substring(with: fullPrefixRange)
          let checkboxRange = match.range(at: 4)
          let prefixBeforeCheckbox: String? = if checkboxRange.location != NSNotFound {
            line.substring(with: NSRange(location: markerRange.location, length: checkboxRange.location - markerRange.location))
          } else {
            nil
          }

          body(MarkdownListLine(
            lineRange: lineRange,
            leadingWhitespace: leadingWhitespace,
            fullPrefix: fullPrefix,
            prefixBeforeCheckbox: prefixBeforeCheckbox
          ))
        }

        let nextLocation = NSMaxRange(fullLineRange)
        guard nextLocation > location else { break }
        location = nextLocation
      }
    }

    private static let listLineRegex = try! NSRegularExpression(
      pattern: #"^([ \t]*)((?:\d+\.|[-*+]))([ \t]+)(?:(\[[ xX]\])([ \t]+))?"#
    )

    private static func indentLevel(from leadingWhitespace: String) -> Int {
      let tabCount = leadingWhitespace.filter { $0 == "\t" }.count
      let spaceCount = leadingWhitespace.filter { $0 == " " }.count
      return tabCount + (spaceCount / 2)
    }
  }
}

private struct MarkdownListLine {
  var lineRange: NSRange
  var leadingWhitespace: String
  var fullPrefix: String
  var prefixBeforeCheckbox: String?
}

private final class FocusBridgeView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override var isOpaque: Bool {
    false
  }
}

private struct MarkdownCodeBlockRange {
  var fullRange: NSRange
  var contentRange: NSRange
  var openingLineRange: NSRange
  var closingLineRange: NSRange?
}

private enum MarkdownCodeRanges {
  static let inlineCodeRegex = try! NSRegularExpression(pattern: #"`([^`\n]+)`"#)

  static func codeBlocks(in text: NSString) -> [MarkdownCodeBlockRange] {
    var blocks: [MarkdownCodeBlockRange] = []
    var openingLine: NSRange?
    var openingEnd = 0
    var location = 0

    while location < text.length {
      let fullLineRange = text.lineRange(for: NSRange(location: location, length: 0))
      var trimmedLineRange = fullLineRange
      while trimmedLineRange.length > 0 {
        let last = text.character(at: NSMaxRange(trimmedLineRange) - 1)
        guard last == 0x0A || last == 0x0D else { break }
        trimmedLineRange.length -= 1
      }

      let line = text.substring(with: trimmedLineRange).trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("```") {
        if let start = openingLine {
          let fullRange = NSRange(location: start.location, length: NSMaxRange(fullLineRange) - start.location)
          let contentEnd = trimmedLineRange.location
          let contentRange = NSRange(location: openingEnd, length: max(0, contentEnd - openingEnd))
          blocks.append(MarkdownCodeBlockRange(
            fullRange: fullRange,
            contentRange: contentRange,
            openingLineRange: start,
            closingLineRange: fullLineRange
          ))
          openingLine = nil
        } else {
          openingLine = fullLineRange
          openingEnd = NSMaxRange(fullLineRange)
        }
      }

      let nextLocation = NSMaxRange(fullLineRange)
      guard nextLocation > location else { break }
      location = nextLocation
    }

    if let start = openingLine {
      let fullRange = NSRange(location: start.location, length: text.length - start.location)
      let contentRange = NSRange(location: openingEnd, length: max(0, text.length - openingEnd))
      blocks.append(MarkdownCodeBlockRange(
        fullRange: fullRange,
        contentRange: contentRange,
        openingLineRange: start,
        closingLineRange: nil
      ))
    }

    return blocks
  }
}

private extension NSView {
  func closestMarkdownTextView() -> NSTextView? {
    guard let root = window?.contentView else { return nil }
    let targetRect = convert(bounds, to: nil)
    let candidates = root.markdownTextViewCandidates()

    return candidates.max { lhs, rhs in
      score(textView: lhs, targetRect: targetRect) < score(textView: rhs, targetRect: targetRect)
    }
  }

  private func markdownTextViewCandidates() -> [NSTextView] {
    var result: [NSTextView] = []

    if let textView = self as? NSTextView,
       textView.isEditable,
       textView.enclosingScrollView != nil,
       !textView.isFieldEditor {
      result.append(textView)
    }

    for subview in subviews {
      result.append(contentsOf: subview.markdownTextViewCandidates())
    }

    return result
  }

  private func score(textView: NSTextView, targetRect: NSRect) -> CGFloat {
    let textRect = textView.convert(textView.bounds, to: nil)
    let intersection = textRect.intersection(targetRect)
    if !intersection.isNull, intersection.width > 0, intersection.height > 0 {
      return intersection.width * intersection.height
    }

    let dx = textRect.midX - targetRect.midX
    let dy = textRect.midY - targetRect.midY
    return -sqrt(dx * dx + dy * dy)
  }
}
