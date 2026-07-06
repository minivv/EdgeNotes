import SwiftUI

struct NoteEditorView: View {
  @EnvironmentObject private var store: NotesStore
  @State private var editorHeight: CGFloat = 320
  var compact: Bool

  var body: some View {
    Group {
      if let note = store.selectedNote {
        VStack(spacing: 0) {
          editorHeader(for: note)
          Divider()

          InlineMarkdownEditor(
            text: bodyBinding(for: note),
            height: $editorHeight,
            textColor: .primary,
            accentColor: .accentColor,
            fontSize: compact ? 14 : 15,
            minHeight: compact ? 220 : 320,
            documentId: note.id.uuidString,
            fitsContent: false
          )
          .frame(minHeight: compact ? 220 : 320)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(.horizontal, compact ? 10 : 16)
          .padding(.vertical, 12)
          .background(note.color.softFill)
        }
      } else {
        ContentUnavailableView(
          "No Note Selected",
          systemImage: "note.text",
          description: Text("Create or select a note to start writing.")
        )
      }
    }
  }

  private func editorHeader(for note: Note) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        TextField("Title", text: titleBinding(for: note))
          .font(compact ? .title3.weight(.semibold) : .title2.weight(.semibold))
          .textFieldStyle(.plain)

        Button {
          store.toggleNotePinned(note.id)
        } label: {
          Image(systemName: note.isPinned ? "pin.fill" : "pin")
        }
        .buttonStyle(.borderless)
        .help(note.isPinned ? "Unpin Note" : "Pin Note")

        Button {
          store.toggleNoteCollapsed(note.id)
        } label: {
          Image(systemName: note.isCollapsed ? "chevron.right.circle.fill" : "chevron.down.circle")
        }
        .buttonStyle(.borderless)
        .help(note.isCollapsed ? "Expand Preview" : "Collapse Preview")
      }

      HStack(spacing: 8) {
        ForEach(NoteColor.allCases) { color in
          Button {
            store.setNoteColor(note.id, color: color)
          } label: {
            ColorSwatch(color: color, isSelected: note.color == color)
          }
          .buttonStyle(.plain)
        }

        Spacer()

        Text("Updated \(DisplayDate.relative(note.updatedAt))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, compact ? 10 : 16)
    .padding(.vertical, compact ? 10 : 14)
    .background(note.color.softFill)
  }

  private func titleBinding(for note: Note) -> Binding<String> {
    Binding(
      get: { store.selectedNote?.title ?? note.title },
      set: { store.updateNote(note.id, title: $0) }
    )
  }

  private func bodyBinding(for note: Note) -> Binding<String> {
    Binding(
      get: { store.selectedNote?.body ?? note.body },
      set: { store.updateNote(note.id, body: $0) }
    )
  }
}

private struct TaskChecklistView: View {
  @EnvironmentObject private var store: NotesStore
  var note: Note
  var tasks: [TaskLine]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(tasks) { task in
        Toggle(isOn: Binding(
          get: { task.isDone },
          set: { _ in store.toggleTask(noteID: note.id, lineIndex: task.lineIndex) }
        )) {
          Text(task.title)
            .strikethrough(task.isDone)
            .foregroundStyle(task.isDone ? .secondary : .primary)
            .lineLimit(1)
        }
        .toggleStyle(.checkbox)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }
}
