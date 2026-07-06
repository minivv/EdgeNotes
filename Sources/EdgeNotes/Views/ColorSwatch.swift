import SwiftUI

struct ColorSwatch: View {
  var color: NoteColor
  var isSelected = false

  var body: some View {
    Circle()
      .fill(color.swatch)
      .frame(width: 14, height: 14)
      .overlay {
        if isSelected {
          Circle()
            .stroke(.primary, lineWidth: 2)
            .padding(-3)
        }
      }
      .accessibilityLabel(color.displayName)
  }
}
