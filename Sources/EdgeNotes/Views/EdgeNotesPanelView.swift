import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SidePanelRoute: String {
  case folders
  case notes
}

private enum PanelFocus: Hashable {
  case search
  case folder(UUID)
  case folderHeader(UUID)
  case noteTitle(UUID)
  case noteBody(UUID)
}

struct EdgeNotesPanelView: View {
  @EnvironmentObject private var store: NotesStore
  @EnvironmentObject private var panelCoordinator: EdgePanelCoordinator
  @EnvironmentObject private var settingsCoordinator: SettingsCoordinator

  @AppStorage(AppPreferences.Key.themeName) private var themeName = "Edge"
  @AppStorage(AppPreferences.Key.showVerticalScrollbars) private var showVerticalScrollbars = true

  @State private var searchVisible = false
  @State private var folderSearchText = ""
  @State private var editingFolderID: UUID?
  @State private var draggingFolderID: UUID?
  @State private var draggingNoteID: UUID?
  @State private var folderDropTargetID: UUID?
  @State private var noteDropTargetID: UUID?
  @State private var folderToReveal: UUID?
  @State private var noteToReveal: UUID?
  @FocusState private var focusedField: PanelFocus?

  private var theme: ThemePreset {
    ThemePreset.named(themeName)
  }

  private var filteredFolders: [NoteFolder] {
    let query = folderSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return store.sortedFolders }
    return store.sortedFolders.filter { folder in
      folder.name.localizedCaseInsensitiveContains(query)
    }
  }

  private var visibleNotesAllCollapsed: Bool {
    let notes = store.visibleNotes()
    return !notes.isEmpty && notes.allSatisfy(\.isCollapsed)
  }

  var body: some View {
    VStack(spacing: 12) {
      panelHeader

      if searchVisible {
        SearchField(
          text: panelCoordinator.route == .folders ? $folderSearchText : $store.searchText,
          placeholder: panelCoordinator.route == .folders ? "搜索文件夹" : "搜索笔记",
          theme: theme,
          focusedField: $focusedField
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      panelBody
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 10)
    .background(Color.clear)
    .foregroundStyle(theme.text)
    .animation(.easeOut(duration: 0.16), value: searchVisible)
  }

  private var panelHeader: some View {
    HStack(spacing: 8) {
      if panelCoordinator.route == .notes {
        Button {
          panelCoordinator.route = .folders
          store.searchText = ""
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(theme.accent)
            .frame(width: 48, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("返回文件夹")
      }

      headerTitle
        .layoutPriority(1)

      Spacer(minLength: 8)

      if panelCoordinator.route == .folders {
        Button {
          openSettings()
        } label: {
          Image(systemName: "gearshape")
            .font(.system(size: 21, weight: .medium))
        }
        .buttonStyle(PanelIconButtonStyle(theme: theme))
        .help("设置")
      }

      if panelCoordinator.route == .notes {
        Button {
          store.setVisibleNotesCollapsed(!visibleNotesAllCollapsed)
        } label: {
          Image(systemName: "arrow.up.and.down")
            .font(.system(size: 21, weight: .medium))
        }
        .buttonStyle(PanelIconButtonStyle(theme: theme, selected: visibleNotesAllCollapsed))
        .help(visibleNotesAllCollapsed ? "全部展开" : "全部折叠")
      }

      Button {
        panelCoordinator.togglePinned()
      } label: {
        Image(systemName: panelCoordinator.isPanelPinned ? "pin.fill" : "pin")
          .font(.system(size: 21, weight: .medium))
      }
      .buttonStyle(PanelIconButtonStyle(theme: theme, selected: panelCoordinator.isPanelPinned))
      .help(panelCoordinator.isPanelPinned ? "取消固定" : "固定侧边栏")

      Button {
        toggleSearch()
      } label: {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 23, weight: .medium))
      }
      .buttonStyle(PanelIconButtonStyle(theme: theme, selected: searchVisible))
      .help("搜索")

      Button(action: createForCurrentRoute) {
        Image(systemName: "plus")
          .font(.system(size: 27, weight: .medium))
      }
      .buttonStyle(PanelIconButtonStyle(theme: theme))
      .help(panelCoordinator.route == .folders ? "新建文件夹" : "新建笔记")
    }
    .padding(.horizontal, 14)
    .frame(height: 64)
    .background(theme.background, in: RoundedRectangle(cornerRadius: 13))
  }

  @ViewBuilder
  private var headerTitle: some View {
    switch panelCoordinator.route {
    case .folders:
      HStack(spacing: 9) {
        Image(systemName: "folder")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(theme.accent)
        VStack(alignment: .leading, spacing: 1) {
          Text("文件夹")
            .font(.system(size: 20, weight: .bold))
            .lineLimit(1)
          Text("\(store.sortedFolders.count) 个文件夹")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

    case .notes:
      HStack(spacing: 0) {
        noteHeaderTitle
      }
    }
  }

  @ViewBuilder
  private var noteHeaderTitle: some View {
    VStack(alignment: .leading, spacing: 1) {
      folderHeaderName
      Text("\(store.visibleNotes().count) 条笔记")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var folderHeaderName: some View {
    if let folderID = store.selectedFolderID {
      TextField("文件夹名称", text: Binding(
        get: { store.selectedFolderName },
        set: { store.renameFolder(folderID, name: $0) }
      ))
      .font(.system(size: 22, weight: .bold))
      .lineLimit(1)
      .minimumScaleFactor(0.82)
      .textFieldStyle(.plain)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .focused($focusedField, equals: .folderHeader(folderID))
      .onSubmit {
        focusedField = nil
      }
    } else {
      Text(store.selectedFolderName)
        .font(.system(size: 22, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(store.selectedFolderID == nil ? "全部笔记不能重命名" : "重命名文件夹")
    }
  }

  @ViewBuilder
  private var panelBody: some View {
    switch panelCoordinator.route {
    case .folders:
      foldersView
    case .notes:
      notesView
    }
  }

  private var foldersView: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(filteredFolders) { folder in
            CardHitRow {
              FolderCard(
                folder: folder,
                count: store.notes.filter { $0.folderID == folder.id }.count,
                theme: theme,
                isEditing: editingFolderID == folder.id,
                focusedField: $focusedField,
                onOpen: {
                  store.selectedFolderID = folder.id
                  store.searchText = ""
                  panelCoordinator.route = .notes
                },
                onRename: { name in
                  store.renameFolder(folder.id, name: name)
                },
                onStartRename: {
                  editingFolderID = folder.id
                  focusedField = .folder(folder.id)
                },
                onFinishRename: {
                  editingFolderID = nil
                  focusedField = nil
                },
                onTogglePinned: {
                  store.toggleFolderPinned(folder.id)
                },
                onDelete: {
                  store.deleteFolder(folder.id)
                }
              )
              .overlay(alignment: .top) {
                if folderDropTargetID == folder.id {
                  DropIndicator(color: theme.accent)
                    .offset(y: -6)
                }
              }
            }
            .id(folder.id)
            .onDrag {
              draggingFolderID = folder.id
              return NSItemProvider(object: folder.id.uuidString as NSString)
            }
            .onDrop(
              of: [UTType.plainText],
              delegate: ReorderDropDelegate(
                targetID: folder.id,
                draggingID: $draggingFolderID,
                dropTargetID: $folderDropTargetID,
                move: { sourceID, targetID in
                  store.moveFolder(sourceID: sourceID, before: targetID)
                }
              )
            )
          }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
      }
      .scrollIndicators(showVerticalScrollbars ? .visible : .hidden)
      .background(ScrollHitBackground())
      .contentShape(Rectangle())
      .onChange(of: folderToReveal) { _, folderID in
        guard let folderID else { return }
        withAnimation(.easeOut(duration: 0.18)) {
          proxy.scrollTo(folderID, anchor: .bottom)
        }
      }
    }
  }

  private var notesView: some View {
    let notes = store.visibleNotes()

    return ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          if notes.isEmpty {
            CardHitRow {
              EmptyNotesCard(theme: theme) {
                let noteID = store.createNote()
                noteToReveal = noteID
                focusedField = .noteTitle(noteID)
              }
            }
          }

          ForEach(notes) { note in
            CardHitRow {
              MarkdownNoteCard(
                note: note,
                theme: theme,
                focusedField: $focusedField,
                onTitleChange: { store.updateNote(note.id, title: $0) },
                onBodyChange: { store.updateNote(note.id, body: $0) },
                onToggleCollapsed: { store.toggleNoteCollapsed(note.id) },
                onTogglePinned: { store.toggleNotePinned(note.id) },
                onDelete: { store.deleteNote(note.id) },
                onSetColor: { store.setNoteColor(note.id, color: $0) },
                onToggleTask: { lineIndex in
                  store.toggleTask(noteID: note.id, lineIndex: lineIndex)
                },
                tasks: store.taskLines(for: note)
              )
              .overlay(alignment: .top) {
                if noteDropTargetID == note.id {
                  DropIndicator(color: theme.accent)
                    .offset(y: -6)
                }
              }
            }
            .id(note.id)
            .onDrag {
              draggingNoteID = note.id
              return NSItemProvider(object: note.id.uuidString as NSString)
            }
            .onDrop(
              of: [UTType.plainText],
              delegate: ReorderDropDelegate(
                targetID: note.id,
                draggingID: $draggingNoteID,
                dropTargetID: $noteDropTargetID,
                move: { sourceID, targetID in
                  store.moveNote(sourceID: sourceID, before: targetID)
                }
              )
            )
          }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
      }
      .scrollIndicators(showVerticalScrollbars ? .visible : .hidden)
      .background(ScrollHitBackground())
      .contentShape(Rectangle())
      .onChange(of: noteToReveal) { _, noteID in
        guard let noteID else { return }
        withAnimation(.easeOut(duration: 0.18)) {
          proxy.scrollTo(noteID, anchor: .top)
        }
      }
    }
  }

  private func createForCurrentRoute() {
    switch panelCoordinator.route {
    case .folders:
      let folderID = store.createFolder()
      editingFolderID = folderID
      folderToReveal = folderID
      DispatchQueue.main.async {
        focusedField = .folder(folderID)
      }

    case .notes:
      let noteID = store.createNote()
      noteToReveal = noteID
      DispatchQueue.main.async {
        focusedField = .noteTitle(noteID)
      }
    }
  }

  private func openSettings() {
    settingsCoordinator.show()
  }

  private func toggleSearch() {
    searchVisible.toggle()
    if searchVisible {
      DispatchQueue.main.async {
        focusedField = .search
      }
    } else if focusedField == .search {
      focusedField = nil
    }
  }
}

private struct FolderCard: View {
  var folder: NoteFolder
  var count: Int
  var theme: ThemePreset
  var isEditing: Bool
  @FocusState.Binding var focusedField: PanelFocus?
  var onOpen: () -> Void
  var onRename: (String) -> Void
  var onStartRename: () -> Void
  var onFinishRename: () -> Void
  var onTogglePinned: () -> Void
  var onDelete: () -> Void

  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "folder")
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(theme.accent)
        .frame(width: 32)

      folderName

      if folder.isPinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(theme.accent)
      }

      Spacer(minLength: 8)

      Text("\(count)")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.secondary)
        .monospacedDigit()

      if isHovering || isEditing {
        HStack(spacing: 4) {
          SmallIconButton(systemName: "pencil", help: "重命名", action: onStartRename)
          SmallIconButton(systemName: folder.isPinned ? "pin.slash" : "pin", help: folder.isPinned ? "取消置顶" : "置顶", action: onTogglePinned)
          SmallIconButton(systemName: "trash", role: .destructive, help: "删除", action: onDelete)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 52)
    .background(theme.background, in: RoundedRectangle(cornerRadius: 8))
    .contentShape(RoundedRectangle(cornerRadius: 8))
    .onHover { isInside in
      withAnimation(.easeOut(duration: 0.14)) {
        isHovering = isInside
      }
    }
    .onTapGesture(count: AppPreferences.folderOpenMode == "double" ? 2 : 1) {
      if !isEditing {
        onOpen()
      }
    }
  }

  @ViewBuilder
  private var folderName: some View {
    if isEditing {
      TextField("文件夹名称", text: Binding(
        get: { folder.name },
        set: onRename
      ))
      .font(.system(size: 17, weight: .semibold))
      .textFieldStyle(.plain)
      .focused($focusedField, equals: .folder(folder.id))
      .onSubmit(onFinishRename)
      .onExitCommand(perform: onFinishRename)
      .onAppear {
        DispatchQueue.main.async {
          NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
      }
    } else {
      Text(folder.name.isEmpty ? "新建文件夹" : folder.name)
        .font(.system(size: 17, weight: .semibold))
        .lineLimit(1)
    }
  }
}

private struct CardHitRow<Content: View>: View {
  var content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    VStack(spacing: 0) {
      content
      ScrollWheelForwardingBackground()
        .frame(height: 10)
    }
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
  }
}

private struct MarkdownNoteCard: View {
  var note: Note
  var theme: ThemePreset
  @FocusState.Binding var focusedField: PanelFocus?
  var onTitleChange: (String) -> Void
  var onBodyChange: (String) -> Void
  var onToggleCollapsed: () -> Void
  var onTogglePinned: () -> Void
  var onDelete: () -> Void
  var onSetColor: (NoteColor) -> Void
  var onToggleTask: (Int) -> Void
  var tasks: [TaskLine]

  @State private var isHovering = false
  @State private var editorHeight: CGFloat = 100
  @State private var focusBodyAtStart = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 8) {
        TextField("标题", text: Binding(
          get: { note.title },
          set: onTitleChange
        ))
        .font(.system(size: 18, weight: .bold))
        .textFieldStyle(.plain)
        .tint(theme.accent)
        .focused($focusedField, equals: .noteTitle(note.id))
        .onSubmit {
          focusBodyAtStart = true
          focusedField = .noteBody(note.id)
        }

        if note.isPinned {
          Image(systemName: "pin.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.accent)
        }

        Spacer(minLength: 8)

        if isHovering || note.isPinned || note.isCollapsed {
          HStack(spacing: 4) {
            SmallIconButton(systemName: note.isCollapsed ? "chevron.down" : "chevron.up", help: note.isCollapsed ? "展开" : "折叠", action: onToggleCollapsed)
            SmallIconButton(systemName: note.isPinned ? "pin.slash" : "pin", help: note.isPinned ? "取消置顶" : "置顶", action: onTogglePinned)
            SmallIconButton(systemName: "trash", role: .destructive, help: "删除", action: onDelete)
          }
          .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
      }

      if !note.isCollapsed {
        InlineMarkdownEditor(
          text: Binding(
            get: { note.body },
            set: onBodyChange
          ),
          height: $editorHeight,
          textColor: theme.text,
          accentColor: theme.accent,
          fontSize: 15,
          minHeight: 92,
          isFocused: focusedField == .noteBody(note.id),
          focusAtStart: $focusBodyAtStart,
          onFocus: {
            focusedField = .noteBody(note.id)
          },
          documentId: note.id.uuidString,
          fitsContent: true
        )

        HStack(spacing: 8) {
          ForEach(NoteColor.allCases) { color in
            Button {
              onSetColor(color)
            } label: {
              ColorSwatch(color: color, isSelected: color == note.color)
            }
            .buttonStyle(.plain)
            .help(color.displayName)
          }

          Spacer()

          Text("创建 \(DisplayDate.date(note.createdAt))")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)

          Image(systemName: "line.3.horizontal")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .help("拖动排序")
        }
        .frame(height: 24)
        .opacity(isHovering ? 1 : 0)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.noteFill(for: note.color), in: RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(isHovering ? 0.10 : 0.06), radius: isHovering ? 6 : 3, x: 0, y: isHovering ? 3 : 1)
    .contentShape(RoundedRectangle(cornerRadius: 12))
    .onHover { isInside in
      withAnimation(.easeOut(duration: 0.14)) {
        isHovering = isInside
      }
    }
  }
}

private struct EmptyNotesCard: View {
  var theme: ThemePreset
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 10) {
        Image(systemName: "square.and.pencil")
          .font(.system(size: 28, weight: .medium))
          .foregroundStyle(theme.accent)
        Text("创建第一条笔记")
          .font(.system(size: 17, weight: .bold))
        Text("标题写完按回车即可继续写正文。")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, minHeight: 158)
      .background(theme.background, in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
  }
}

private struct SearchField: View {
  @Binding var text: String
  var placeholder: String
  var theme: ThemePreset
  @FocusState.Binding var focusedField: PanelFocus?

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .focused($focusedField, equals: .search)
    }
    .padding(.horizontal, 12)
    .frame(height: 38)
    .background(theme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
    .onAppear {
      DispatchQueue.main.async {
        focusedField = .search
      }
    }
  }
}

private struct ScrollHitBackground: View {
  var body: some View {
    ScrollWheelForwardingBackground()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct ScrollWheelForwardingBackground: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    ScrollWheelForwardingBackgroundView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

private struct SmallIconButton: View {
  var systemName: String
  var role: ButtonRole?
  var help: String
  var action: () -> Void

  init(systemName: String, role: ButtonRole? = nil, help: String, action: @escaping () -> Void) {
    self.systemName = systemName
    self.role = role
    self.help = help
    self.action = action
  }

  var body: some View {
    Button(role: role, action: action) {
      Image(systemName: systemName)
        .font(.system(size: 14, weight: .semibold))
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(help)
  }
}

private struct PanelIconButtonStyle: ButtonStyle {
  var theme: ThemePreset
  var selected = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(selected ? theme.background : theme.accent)
      .frame(width: 32, height: 40)
      .background(selected ? theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

private struct DropIndicator: View {
  var color: Color

  var body: some View {
    Capsule()
      .fill(color)
      .frame(height: 3)
      .frame(maxWidth: .infinity)
      .shadow(color: color.opacity(0.45), radius: 4, x: 0, y: 0)
  }
}

private struct ReorderDropDelegate: DropDelegate {
  let targetID: UUID
  @Binding var draggingID: UUID?
  @Binding var dropTargetID: UUID?
  let move: (UUID, UUID) -> Void

  func dropEntered(info: DropInfo) {
    guard let draggingID, draggingID != targetID else { return }
    dropTargetID = targetID
  }

  func performDrop(info: DropInfo) -> Bool {
    if let draggingID, let dropTargetID {
      withAnimation(.interpolatingSpring(stiffness: 110, damping: 16)) {
        move(draggingID, dropTargetID)
      }
    }
    draggingID = nil
    dropTargetID = nil
    return true
  }

  func dropExited(info: DropInfo) {
    if dropTargetID == targetID {
      dropTargetID = nil
    }
  }
}
