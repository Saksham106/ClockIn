import SwiftUI

struct ManageTagsView: View {
    @EnvironmentObject private var manager: TimerManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedTagId: UUID?
    @State private var hoveredTagId: UUID?
    @State private var didCancel = false
    @State private var initialSnapshots: [UUID: TagSnapshot] = [:]
    @State private var hexDrafts: [UUID: String] = [:]

    private struct TagSnapshot {
        let name: String
        let colorHex: String?
        let isHidden: Bool
        let order: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Manage Tags")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(manager.allTags) { tag in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(tagColor(tag).opacity(0.8))
                                .frame(width: 8, height: 8)

                            if tag.isSystem {
                                Text(tag.name)
                                    .fontWeight(.semibold)
                            } else {
                                HStack(spacing: 6) {
                                    Button {
                                        focusedTagId = tag.id
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    TextField("Tag name", text: Binding(
                                        get: { tag.name },
                                        set: { tag.name = $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    ))
                                    .textFieldStyle(.plain)
                                    .focused($focusedTagId, equals: tag.id)
                                }
                            }

                            if !tag.isSystem {
                                HStack(spacing: 6) {
                                    ColorPicker("Color", selection: Binding(
                                        get: { tagColor(tag) },
                                        set: { newColor in
                                            let hex = newColor.toHexString()
                                            tag.colorHex = hex
                                            if let hex {
                                                hexDrafts[tag.id] = hex
                                            }
                                        }
                                    ), supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 32)

                                    TextField("#RRGGBB", text: Binding(
                                        get: { hexDrafts[tag.id] ?? (tag.colorHex ?? "") },
                                        set: { newValue in
                                            let normalized = normalizeHexInput(newValue)
                                            hexDrafts[tag.id] = normalized
                                            if isValidHex(normalized) {
                                                tag.colorHex = normalized
                                            }
                                        }
                                    ))
                                    .textFieldStyle(.plain)
                                    .frame(width: 74)
                                    .font(.caption)
                                    .monospaced()
                                }
                            }

                            Spacer()

                            Toggle("Show", isOn: Binding(
                                get: { !tag.isHidden },
                                set: { tag.isHidden = !$0 }
                            ))
                            .labelsHidden()
                            .disabled(tag.isSystem)
                            .help(tag.isSystem ? "System tag is always shown." : "Uncheck to hide this tag from quick switching.")

                            VStack(spacing: 4) {
                                Button {
                                    moveTag(tag, direction: -1)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(.white.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                                .disabled(tag.isSystem || !canMove(tag, direction: -1))

                                Button {
                                    moveTag(tag, direction: 1)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(.white.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                                .disabled(tag.isSystem || !canMove(tag, direction: 1))
                            }
                            .frame(width: 20)
                        }
                        .padding(10)
                        .background(
                            (focusedTagId == tag.id || hoveredTagId == tag.id) && !tag.isSystem
                                ? .white.opacity(0.08)
                                : .white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .onHover { isHovering in
                            hoveredTagId = isHovering ? tag.id : nil
                        }
                    }
                }
            }
            .frame(minHeight: 280)

            HStack {
                Text("Idle / Off is fixed and always visible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") {
                    restoreInitialState()
                    didCancel = true
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Done") {
                    manager.saveTagChanges()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
        .onDisappear {
            if !didCancel {
                manager.saveTagChanges()
            }
        }
        .onAppear {
            if initialSnapshots.isEmpty {
                captureInitialState()
            }
        }
    }

    private func captureInitialState() {
        var snapshots: [UUID: TagSnapshot] = [:]
        var drafts: [UUID: String] = [:]
        for tag in manager.allTags {
            snapshots[tag.id] = TagSnapshot(
                name: tag.name,
                colorHex: tag.colorHex,
                isHidden: tag.isHidden,
                order: tag.order
            )
            if let hex = tag.colorHex ?? tagColor(tag).toHexString() {
                drafts[tag.id] = hex
            }
        }
        initialSnapshots = snapshots
        hexDrafts = drafts
    }

    private func restoreInitialState() {
        for tag in manager.allTags {
            guard let snapshot = initialSnapshots[tag.id] else { continue }
            tag.name = snapshot.name
            tag.colorHex = snapshot.colorHex
            tag.isHidden = snapshot.isHidden
            tag.order = snapshot.order
        }
        hexDrafts = manager.allTags.reduce(into: [:]) { result, tag in
            if let hex = tag.colorHex ?? tagColor(tag).toHexString() {
                result[tag.id] = hex
            }
        }
    }

    private func normalizeHexInput(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            return trimmed.uppercased()
        }
        return "#" + trimmed.uppercased()
    }

    private func isValidHex(_ input: String) -> Bool {
        let sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitized.hasPrefix("#") else { return false }
        let hex = String(sanitized.dropFirst())
        guard hex.count == 6, hex.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
            return false
        }
        return true
    }

    private func canMove(_ tag: TagItem, direction: Int) -> Bool {
        guard let index = manager.allTags.firstIndex(of: tag) else { return false }
        let nextIndex = index + direction
        return nextIndex >= 0 && nextIndex < manager.allTags.count
    }

    private func moveTag(_ tag: TagItem, direction: Int) {
        guard let index = manager.allTags.firstIndex(of: tag) else { return }
        let destination = index + direction
        guard destination >= 0 && destination < manager.allTags.count else { return }
        manager.moveTags(from: IndexSet(integer: index), to: destination)
    }
}
