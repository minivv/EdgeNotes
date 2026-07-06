import SwiftUI

struct CompactNotesView: View {
  @EnvironmentObject private var store: NotesStore

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Picker("Folder", selection: $store.selectedFolderID) {
          Text("All Notes").tag(UUID?.none)
          ForEach(store.sortedFolders) { folder in
            Text(folder.name).tag(Optional(folder.id))
          }
        }
        .labelsHidden()
        .frame(maxWidth: 180)

        Spacer()

        Button {
          store.createFolder()
        } label: {
          Image(systemName: "folder.badge.plus")
        }
        .buttonStyle(.borderless)
        .help("New Folder")

        Button {
          store.createNote()
        } label: {
          Image(systemName: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .help("New Note")
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)

      Divider()

      VSplitView {
        NoteListView(compact: true)
          .frame(minHeight: 170)

        NoteEditorView(compact: true)
          .frame(minHeight: 260)
      }
    }
  }
}
