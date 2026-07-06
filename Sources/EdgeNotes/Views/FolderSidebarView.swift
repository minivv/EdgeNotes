import SwiftUI

struct FolderSidebarView: View {
  @EnvironmentObject private var store: NotesStore
  @State private var folderToRename: NoteFolder?
  @State private var renameDraft = ""

  var body: some View {
    VStack(spacing: 0) {
      List {
        Button {
          store.selectedFolderID = nil
        } label: {
          SidebarFolderRow(
            title: "All Notes",
            systemImage: "tray.full",
            color: .graphite,
            count: store.notes.count,
            isPinned: false,
            isSelected: store.selectedFolderID == nil
          )
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)

        Section("Folders") {
          ForEach(store.sortedFolders) { folder in
            Button {
              store.selectedFolderID = folder.id
            } label: {
              SidebarFolderRow(
                title: folder.name,
                systemImage: "folder",
                color: folder.color,
                count: store.notes.filter { $0.folderID == folder.id }.count,
                isPinned: folder.isPinned,
                isSelected: store.selectedFolderID == folder.id
              )
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button(folder.isPinned ? "Unpin Folder" : "Pin Folder") {
                store.toggleFolderPinned(folder.id)
              }
              Button("Rename") {
                renameDraft = folder.name
                folderToRename = folder
              }
              Divider()
              Button("Delete Folder", role: .destructive) {
                store.deleteFolder(folder.id)
              }
            }
          }
          .onMove { offsets, destination in
            store.moveFolders(from: offsets, to: destination)
          }
        }
      }
      .listStyle(.sidebar)

      Divider()

      Button {
        store.createFolder()
      } label: {
        Label("New Folder", systemImage: "folder.badge.plus")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.borderless)
      .padding(10)
    }
    .sheet(item: $folderToRename) { folder in
      RenameFolderSheet(
        folderName: $renameDraft,
        onCancel: {
          folderToRename = nil
        },
        onSave: {
          store.renameFolder(folder.id, name: renameDraft)
          folderToRename = nil
        }
      )
    }
  }
}

private struct SidebarFolderRow: View {
  var title: String
  var systemImage: String
  var color: NoteColor
  var count: Int
  var isPinned: Bool
  var isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage)
        .foregroundStyle(color.swatch)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(title)
            .lineLimit(1)
          if isPinned {
            Image(systemName: "pin.fill")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }

        Text("\(count) notes")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 8)
    }
    .padding(.vertical, 5)
    .padding(.horizontal, 7)
    .background {
      RoundedRectangle(cornerRadius: 6)
        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
    }
  }
}

private struct RenameFolderSheet: View {
  @Binding var folderName: String
  var onCancel: () -> Void
  var onSave: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Rename Folder")
        .font(.headline)

      TextField("Folder name", text: $folderName)
        .textFieldStyle(.roundedBorder)
        .frame(width: 320)

      HStack {
        Spacer()
        Button("Cancel", action: onCancel)
          .keyboardShortcut(.cancelAction)
        Button("Save", action: onSave)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
  }
}
