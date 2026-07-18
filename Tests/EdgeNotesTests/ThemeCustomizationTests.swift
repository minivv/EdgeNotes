import SwiftUI
import XCTest
@testable import EdgeNotes

final class ThemeCustomizationTests: XCTestCase {
  func testCustomizationsRoundTripAndStayIsolatedByTheme() {
    var customizations = ThemeCustomizations()
    let color = Color(.sRGB, red: 0.12, green: 0.34, blue: 0.56, opacity: 0.42)
    customizations.set(color, for: "Edge", role: .background)

    let decoded = ThemeCustomizations(json: customizations.json)

    XCTAssertEqual(decoded.color(for: "Edge", role: .background)?.themeHex, color.themeHex)
    XCTAssertNil(decoded.color(for: "Clean", role: .background))
  }

  func testUserForegroundColorsAreNotReplacedForContrast() {
    var customizations = ThemeCustomizations()
    let red = Color(.sRGB, red: 0.92, green: 0.08, blue: 0.12, opacity: 0.73)
    let blue = Color(.sRGB, red: 0.05, green: 0.22, blue: 0.94, opacity: 0.61)
    customizations.set(red, for: "Edge", role: .folderText)
    customizations.set(blue, for: "Edge", role: .noteText, noteColor: .graphite)
    customizations.set(red, for: "Edge", role: .noteAccent, noteColor: .graphite)
    customizations.set(blue, for: "Edge", role: .toolbarText)
    customizations.set(red, for: "Edge", role: .toolbarAccent)

    let theme = ThemePreset.named("Edge").customized(using: customizations)

    XCTAssertEqual(theme.folderText.themeHex, red.themeHex)
    XCTAssertEqual(theme.noteText(for: .graphite).themeHex, blue.themeHex)
    XCTAssertEqual(theme.noteAccent(for: .graphite).themeHex, red.themeHex)
    XCTAssertEqual(theme.toolbarText.themeHex, blue.themeHex)
    XCTAssertEqual(theme.toolbarAccent.themeHex, red.themeHex)
  }

  func testBaseTextAndAccentDoNotCascadeIntoColoredNotes() {
    var customizations = ThemeCustomizations()
    let baseText = Color(.sRGB, red: 0.82, green: 0.12, blue: 0.25, opacity: 0.88)
    let baseAccent = Color(.sRGB, red: 0.10, green: 0.35, blue: 0.93, opacity: 0.76)
    let folderOverride = Color(.sRGB, red: 0.20, green: 0.75, blue: 0.38, opacity: 0.69)
    customizations.set(baseText, for: "Edge", role: .text)
    customizations.set(baseAccent, for: "Edge", role: .accent)
    customizations.set(folderOverride, for: "Edge", role: .folderText)

    let theme = ThemePreset.named("Edge").customized(using: customizations)

    XCTAssertEqual(theme.headerText.themeHex, baseText.themeHex)
    XCTAssertEqual(theme.folderText.themeHex, folderOverride.themeHex)
    XCTAssertEqual(
      theme.noteText(for: .sky).themeHex,
      ThemePreset.named("Edge").noteText(for: .sky).themeHex
    )
    XCTAssertEqual(theme.toolbarText.themeHex, baseText.themeHex)
    XCTAssertEqual(theme.headerAccent.themeHex, baseAccent.themeHex)
    XCTAssertEqual(
      theme.noteAccent(for: .sky).themeHex,
      ThemePreset.named("Edge").noteAccent(for: .sky).themeHex
    )
    XCTAssertEqual(theme.toolbarAccent.themeHex, baseAccent.themeHex)
  }

  func testEveryEditableBackgroundPreservesOpacity() {
    var customizations = ThemeCustomizations()
    let translucent = Color(.sRGB, red: 0.18, green: 0.44, blue: 0.72, opacity: 0.27)
    let roles: [ThemeColorRole] = [
      .background, .card, .folderBackground, .toolbarBackground
    ]
    for role in roles {
      customizations.set(translucent, for: "Edge", role: role)
    }
    customizations.set(translucent, for: "Edge", role: .noteBackground, noteColor: .rose)

    let theme = ThemePreset.named("Edge").customized(using: ThemeCustomizations(json: customizations.json))

    XCTAssertEqual(theme.background.themeHex, translucent.themeHex)
    XCTAssertEqual(theme.card.themeHex, translucent.themeHex)
    XCTAssertEqual(theme.folderFill.themeHex, translucent.themeHex)
    XCTAssertEqual(theme.noteFill(for: .rose).themeHex, translucent.themeHex)
    XCTAssertEqual(theme.toolbarFill.themeHex, translucent.themeHex)
  }

  func testUniformListBackgroundOnlyUpdatesGraphiteNoteCard() {
    var customizations = ThemeCustomizations()
    let color = Color(.sRGB, red: 0.13, green: 0.47, blue: 0.71, opacity: 0.58)

    customizations.setUniform(color, for: "Edge", role: .card)
    let theme = ThemePreset.named("Edge").customized(using: customizations)

    XCTAssertEqual(theme.card.themeHex, color.themeHex)
    XCTAssertEqual(theme.folderFill.themeHex, color.themeHex)
    XCTAssertEqual(theme.noteFill(for: .graphite).themeHex, color.themeHex)
    for noteColor in NoteColor.allCases where noteColor != .graphite {
      XCTAssertEqual(
        theme.noteFill(for: noteColor).themeHex,
        ThemePreset.named("Edge").noteFill(for: noteColor).themeHex
      )
    }
  }

  func testUniformTextAndAccentUpdateAllPrimaryRoles() {
    var customizations = ThemeCustomizations()
    let text = Color(.sRGB, red: 0.83, green: 0.18, blue: 0.24, opacity: 0.84)
    let accent = Color(.sRGB, red: 0.12, green: 0.38, blue: 0.91, opacity: 0.77)

    customizations.setUniform(text, for: "Edge", role: .text)
    customizations.setUniform(accent, for: "Edge", role: .accent)
    let theme = ThemePreset.named("Edge").customized(using: customizations)

    XCTAssertEqual(theme.headerText.themeHex, text.themeHex)
    XCTAssertEqual(theme.folderText.themeHex, text.themeHex)
    XCTAssertEqual(theme.toolbarText.themeHex, text.themeHex)
    XCTAssertEqual(theme.headerAccent.themeHex, accent.themeHex)
    XCTAssertEqual(theme.folderAccent.themeHex, accent.themeHex)
    XCTAssertEqual(theme.toolbarAccent.themeHex, accent.themeHex)
    XCTAssertEqual(theme.noteText(for: .graphite).themeHex, text.themeHex)
    XCTAssertEqual(theme.noteAccent(for: .graphite).themeHex, accent.themeHex)
    for noteColor in NoteColor.allCases where noteColor != .graphite {
      XCTAssertEqual(
        theme.noteText(for: noteColor).themeHex,
        ThemePreset.named("Edge").noteText(for: noteColor).themeHex
      )
      XCTAssertEqual(
        theme.noteAccent(for: noteColor).themeHex,
        ThemePreset.named("Edge").noteAccent(for: noteColor).themeHex
      )
    }
  }

  func testChangingOneNoteColorPreservesOtherNoteColors() {
    var customizations = ThemeCustomizations()
    let replacement = Color(red: 0.10, green: 0.20, blue: 0.30)
    customizations.set(replacement, for: "Edge", role: .noteBackground, noteColor: .graphite)

    let base = ThemePreset.named("Edge")
    let customized = base.customized(using: customizations)

    XCTAssertEqual(customized.noteFill(for: .graphite).themeHex, replacement.themeHex)
    XCTAssertEqual(customized.noteFill(for: .rose).themeHex, base.noteFill(for: .rose).themeHex)
    XCTAssertEqual(customized.noteFill(for: .amber).themeHex, base.noteFill(for: .amber).themeHex)
  }

  func testGraphiteNoteContinuesToFollowCustomizedThemeBackground() {
    var customizations = ThemeCustomizations()
    let replacement = Color(red: 0.22, green: 0.31, blue: 0.40)
    customizations.set(replacement, for: "Edge", role: .background)

    let customized = ThemePreset.named("Edge").customized(using: customizations)

    XCTAssertEqual(customized.noteFill(for: .graphite).themeHex, replacement.themeHex)
  }

  func testResetOnlyRemovesSelectedTheme() {
    var customizations = ThemeCustomizations()
    customizations.set(.red, for: "Edge", role: .accent)
    customizations.set(.blue, for: "Clean", role: .accent)

    customizations.reset(themeName: "Edge")

    XCTAssertFalse(customizations.hasValues(for: "Edge"))
    XCTAssertTrue(customizations.hasValues(for: "Clean"))
  }
}

final class MarkdownTaskListTests: XCTestCase {
  func testConvertsEverySelectedLineToAnUncheckedTask() throws {
    let source = "First\n- Second\n2. Third\nAfter"
    let selectedRange = NSRange(location: 1, length: 21)

    let change = try XCTUnwrap(MarkdownTaskList.replacement(
      in: source as NSString,
      selectedRange: selectedRange
    ))

    XCTAssertEqual(change.text, "- [ ] First\n- [ ] Second\n- [ ] Third\n")
  }

  func testPreservesIndentationAndRemovesExistingTaskState() throws {
    let source = "  - [x] Finished\n"

    let change = try XCTUnwrap(MarkdownTaskList.replacement(
      in: source as NSString,
      selectedRange: NSRange(location: 2, length: 5)
    ))

    XCTAssertEqual(change.text, "  - [ ] Finished\n")
  }
}
