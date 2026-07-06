import SwiftUI

struct NoteListView: View {
  @EnvironmentObject private var store: NotesStore
  var compact: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Text(store.selectedFolderName)
          .font(compact ? .headline : .title3.weight(.semibold))
          .lineLimit(1)

        Spacer()

        Button {
          store.createNote()
        } label: {
          Image(systemName: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .help("New Note")
      }
      .padding(.horizontal, compact ? 10 : 14)
      .padding(.vertical, compact ? 8 : 12)

      Divider()

      List(selection: $store.selectedNoteID) {
        ForEach(store.visibleNotes()) { note in
          NoteRowView(note: note, compact: compact)
            .tag(note.id)
            .contextMenu {
              Button(note.isPinned ? "Unpin Note" : "Pin Note") {
                store.toggleNotePinned(note.id)
              }
              Button(note.isCollapsed ? "Expand Preview" : "Collapse Preview") {
                store.toggleNoteCollapsed(note.id)
              }
              Button("Duplicate") {
                store.duplicateNote(note.id)
              }
              Menu("Move to Folder") {
                Button("All Notes") {
                  store.selectedNoteID = note.id
                  store.moveSelectedNote(to: nil)
                }
                ForEach(store.sortedFolders) { folder in
                  Button(folder.name) {
                    store.selectedNoteID = note.id
                    store.moveSelectedNote(to: folder.id)
                  }
                }
              }
              Menu("Color") {
                ForEach(NoteColor.allCases) { color in
                  Button {
                    store.setNoteColor(note.id, color: color)
                  } label: {
                    Label(color.displayName, systemImage: note.color == color ? "checkmark.circle.fill" : "circle")
                  }
                }
              }
              Divider()
              Button("Delete Note", role: .destructive) {
                store.deleteNote(note.id)
              }
            }
        }
        .onMove { offsets, destination in
          store.moveVisibleNotes(from: offsets, to: destination)
        }
      }
      .listStyle(.inset)
      .searchable(text: $store.searchText, placement: .automatic, prompt: "Search notes")
    }
  }
}

struct NoteRowView: View {
  var note: Note
  var compact: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      RoundedRectangle(cornerRadius: 2)
        .fill(note.color.swatch)
        .frame(width: 4)
        .padding(.vertical, 2)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(note.title.isEmpty ? "Untitled Note" : note.title)
            .font(.body.weight(note.isPinned ? .semibold : .regular))
            .lineLimit(1)

          if note.isPinned {
            Image(systemName: "pin.fill")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          if note.isCollapsed {
            Image(systemName: "chevron.right.circle")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if !note.isCollapsed {
          Text(note.body.isEmpty ? "No content" : note.body)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(compact ? 1 : 2)
        }

        Text(DisplayDate.relative(note.updatedAt))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, compact ? 4 : 6)
    .contentShape(Rectangle())
  }
}
