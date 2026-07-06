import SwiftUI

enum AppSurfaceMode {
  case main
  case panel
}

struct ContentView: View {
  var mode: AppSurfaceMode

  var body: some View {
    switch mode {
    case .main:
      NavigationSplitView {
        FolderSidebarView()
          .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
      } content: {
        NoteListView(compact: false)
          .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
      } detail: {
        NoteEditorView(compact: false)
      }
      .navigationTitle("EdgeNotes")

    case .panel:
      CompactNotesView()
    }
  }
}
