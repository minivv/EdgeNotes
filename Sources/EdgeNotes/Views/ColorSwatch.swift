import SwiftUI

struct ColorSwatch: View {
  var color: NoteColor
  var fillColor: Color?
  var selectionColor: Color = .primary
  var isSelected = false

  var body: some View {
    Circle()
      .fill(fillColor ?? color.swatch)
      .frame(width: 14, height: 14)
      .overlay {
        if isSelected {
          Circle()
            .stroke(selectionColor, lineWidth: 2)
            .padding(-3)
        }
      }
      .accessibilityLabel(color.displayName)
  }
}
