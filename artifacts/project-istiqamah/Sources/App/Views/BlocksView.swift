import SwiftUI

struct BlocksView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft: FocusBlock?
    @State private var editMode: EditMode = .inactive
    @State private var restoreError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.activeBlocks) { block in
                        HStack(spacing: 14) {
                            Image(systemName: "clock")
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.elevatedSurface)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(block.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("\(block.startTime) – \(block.endTime) · \(block.actions.count) actions")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text(weekdaySummary(block.weekdays))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.primary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture { draft = block }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { draft = block }
                        .accessibilityHint("Double-tap to edit. Use Reorder to move this block into another time slot.")
                        .listRowBackground(AppTheme.surface)
                        .swipeActions {
                            Button { store.archive(block) } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(AppTheme.warning)
                        }
                    }
                    .onMove(perform: moveBlocks)
                } footer: {
                    Text("Tap Reorder, then drag a block by its handle. The moved block and destination block exchange time slots.")
                }

                if !store.archivedBlocks.isEmpty {
                    Section("Archived") {
                        ForEach(store.archivedBlocks) { block in
                            HStack(spacing: 12) {
                                Image(systemName: "archivebox.fill")
                                    .foregroundStyle(AppTheme.tertiaryText)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(block.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(block.startTime) – \(block.endTime) · \(weekdaySummary(block.weekdays))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Button {
                                    draft = block
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Edit \(block.name)")
                                Button("Restore") {
                                    restoreError = store.restore(block)
                                }
                                .buttonStyle(.bordered)
                                .tint(AppTheme.primary)
                                .controlSize(.small)
                            }
                            .listRowBackground(AppTheme.surface)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Blocks")
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.primary)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(editMode.isEditing ? "Done" : "Reorder") {
                        withAnimation(.snappy) {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { draft = FocusBlock(name: "", startTime: "09:00", endTime: "10:00", note: "") } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add block")
                }
            }
            .sheet(item: $draft) { block in
                BlockEditor(block: block, existingBlocks: store.activeBlocks) { saved in
                    if store.blocks.contains(where: { $0.id == saved.id }) {
                        store.update(saved)
                    } else {
                        store.add(saved)
                    }
                    draft = nil
                }
            }
            .alert("Could not restore block", isPresented: Binding(
                get: { restoreError != nil },
                set: { if !$0 { restoreError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreError ?? "")
            }
        }
    }

    private func moveBlocks(from sourceOffsets: IndexSet, to destination: Int) {
        let activeBlocks = store.activeBlocks
        guard sourceOffsets.count == 1,
              let sourceIndex = sourceOffsets.first,
              activeBlocks.indices.contains(sourceIndex) else { return }
        let targetIndex = destination > sourceIndex ? destination - 1 : destination
        guard activeBlocks.indices.contains(targetIndex), targetIndex != sourceIndex else { return }
        store.swapBlockTimeSlots(activeBlocks[sourceIndex].id, with: activeBlocks[targetIndex].id)
    }

    private func weekdaySummary(_ weekdays: Set<Int>) -> String {
        if weekdays == FocusBlock.everyDay { return "Every day" }
        return weekdays.sorted().map { DateTools.weekdayName($0) }.joined(separator: " · ")
    }
}

private struct BlockEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var block: FocusBlock
    @State private var errorMessage: String?
    let existingBlocks: [FocusBlock]
    let onSave: (FocusBlock) -> Void

    init(
        block: FocusBlock,
        existingBlocks: [FocusBlock],
        onSave: @escaping (FocusBlock) -> Void
    ) {
        _block = State(initialValue: block)
        self.existingBlocks = existingBlocks
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Block name", text: $block.name)
                    DatePicker(
                        "Start",
                        selection: timeBinding(\.startTime),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "End",
                        selection: timeBinding(\.endTime),
                        displayedComponents: .hourAndMinute
                    )
                    TextField("Note", text: $block.note, axis: .vertical)
                } header: {
                    Text("Block")
                } footer: {
                    Text("Times use your iPhone's preferred 12-hour or 24-hour format.")
                }

                Section("Scheduled days") {
                    WeekdayPicker(selection: $block.weekdays)
                }

                Section("Actions · up to 5") {
                    ForEach($block.actions) { $action in
                        TextField("Action", text: $action.name)
                    }
                    .onDelete { block.actions.remove(atOffsets: $0) }
                    if block.actions.count < 5 {
                        Button("Add action", systemImage: "plus") {
                            block.actions.append(BlockAction(name: ""))
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(AppTheme.error)
                    }
                }
            }
            .navigationTitle(block.name.isEmpty ? "New Block" : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<FocusBlock, String>) -> Binding<Date> {
        Binding(
            get: { DateTools.date(for: block[keyPath: keyPath]) ?? Date() },
            set: { block[keyPath: keyPath] = DateTools.timeString(from: $0) }
        )
    }

    private func save() {
        block.name = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
        block.startTime = block.startTime.trimmingCharacters(in: .whitespacesAndNewlines)
        block.endTime = block.endTime.trimmingCharacters(in: .whitespacesAndNewlines)
        block.actions = block.actions
            .map { action in
                var action = action
                action.name = action.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return action
            }
            .filter { !$0.name.isEmpty }
            .prefix(5)
            .map { $0 }
        guard !block.name.isEmpty,
              DateTools.isValid(time: block.startTime),
              DateTools.isValid(time: block.endTime),
              !block.weekdays.isEmpty else {
            errorMessage = "Add a name, choose start and end times, and select at least one day."
            return
        }
        if let overlappingBlock = existingBlocks.first(where: {
            $0.id != block.id && DateTools.overlaps(block, $0)
        }) {
            errorMessage = "This time overlaps \(overlappingBlock.name). Choose an open time slot."
            return
        }
        onSave(block)
    }
}

private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let selected = selection.contains(weekday)
                Button {
                    if selected {
                        selection.remove(weekday)
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(DateTools.weekdayName(weekday, width: .narrow))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? AppTheme.onPrimary : AppTheme.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(selected ? AppTheme.primary : AppTheme.elevatedSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DateTools.weekdayName(weekday))
                .accessibilityValue(selected ? "Selected" : "Not selected")
            }
        }
        .padding(.vertical, 4)
    }
}
