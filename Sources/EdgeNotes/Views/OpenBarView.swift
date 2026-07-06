import SwiftUI

struct OpenBarView: View {
  var side: EdgeSide
  var onHoverOpen: () -> Void
  var onClickOpen: () -> Void

  var body: some View {
    Button(action: onClickOpen) {
      RoundedRectangle(cornerRadius: 6)
        .fill(.regularMaterial)
        .overlay {
          VStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { _ in
              Circle()
                .fill(.secondary.opacity(0.75))
                .frame(width: 3, height: 3)
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(.plain)
    .onHover { isInside in
      if isInside {
        onHoverOpen()
      }
    }
    .help("Hover to open EdgeNotes")
  }
}
