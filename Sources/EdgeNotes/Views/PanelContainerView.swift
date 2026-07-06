import SwiftUI

struct PanelContainerView: View {
  var side: EdgeSide
  var onClose: () -> Void
  var onHoverChanged: (Bool) -> Void

  var body: some View {
    ZStack {
      EdgeNotesPanelView()
    }
    .background(Color.clear)
    .onHover(perform: onHoverChanged)
  }
}
