import SwiftUI

struct EditSegmentSheet: View {
    @EnvironmentObject private var manager: TimerManager
    @Environment(\.dismiss) private var dismiss

    let segment: Segment
    let day: Date

    @State private var selectedTag: TagItem = TagItem(name: TagDefaults.idleName, order: 0, isHidden: false, isSystem: true)
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var isRunning: Bool = false
    @State private var noteText: String = ""
    @State private var splitEnabled: Bool = false
    @State private var splitTime: Date = Date()
    @State private var splitBeforeTag: TagItem = TagItem(name: TagDefaults.idleName, order: 0, isHidden: false, isSystem: true)
    @State private var splitAfterTag: TagItem = TagItem(name: TagDefaults.idleName, order: 0, isHidden: false, isSystem: true)
    @State private var splitErrorMessage: String?
    @State private var showDeleteConfirm: Bool = false
    @State private var showDetails: Bool = false
    @State private var activeSplitComponent: SplitComponent = .minute
    @State private var hasAdjustedSplitTime: Bool = false

    private let calendar = Calendar.current

    var body: some View {
        let startDate = combine(day: day, time: startTime)
        let endDate = isRunning ? nil : combine(day: day, time: endTime)
        let validationError = manager.validationErrorForEdit(id: segment.id, tag: selectedTag, start: startDate, end: endDate)
        let durationEnd = isRunning ? manager.nowTick : (endDate ?? manager.nowTick)
        let durationText = formattedDuration(max(0, durationEnd.timeIntervalSince(startDate)))

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(tagColor(selectedTag))
                    .frame(width: 10, height: 10)
                Text("Edit \(selectedTag.name)")
                    .font(.title3)
                    .fontWeight(.semibold)
                if isRunning {
                    Text("• Running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("Split mode")
                        .font(.subheadline)
                    Toggle("Split mode", isOn: $splitEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                    if splitEnabled {
                        Spacer(minLength: 8)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tagColor(splitBeforeTag))
                                .frame(width: 10, height: 10)
                            tagMenu(selection: $splitBeforeTag)
                        }

                        Image(systemName: "arrow.right")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(tagColor(splitAfterTag))
                                .frame(width: 10, height: 10)
                            tagMenu(selection: $splitAfterTag)
                        }
                    }
                }

                if splitEnabled {
                HStack(spacing: 12) {
                    Text("Split at")
                        timePickerLabel
                        Stepper("", value: Binding(
                            get: {
                                activeSplitComponent == .hour
                                    ? calendar.component(.hour, from: splitTime)
                                    : calendar.component(.minute, from: splitTime)
                            },
                            set: { newValue in
                                hasAdjustedSplitTime = true
                                let hour = activeSplitComponent == .hour ? newValue : calendar.component(.hour, from: splitTime)
                                let minute = activeSplitComponent == .minute ? newValue : calendar.component(.minute, from: splitTime)
                                splitTime = updatedSplitTime(hour: hour, minute: minute)
                            }
                        ), in: activeSplitComponent == .hour ? 0...23 : 0...59)
                        .labelsHidden()
                        Button("Last 5m") { applyQuickSplit(minutes: 5) }
                        Button("Last 10m") { applyQuickSplit(minutes: 10) }
                        Button("Last 15m") { applyQuickSplit(minutes: 15) }
                }
                    .buttonStyle(.bordered)

                if let splitErrorMessage {
                    Text(splitErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                }
            }
            .padding(12)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

            DisclosureGroup(isExpanded: $showDetails) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration · \(durationText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Tag", selection: $selectedTag) {
                        ForEach(manager.allTags) { tag in
                            Text(tag.name).tag(tag)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedTag) { oldTag, newTag in
                        splitBeforeTag = newTag
                        let reference = segment.end ?? manager.nowTick
                        if let suggestion = manager.suggestedAfterTag(for: newTag, referenceDate: reference), suggestion.id != newTag.id {
                            splitAfterTag = suggestion
                        } else if splitAfterTag.id == oldTag.id {
                            splitAfterTag = newTag
                        }
                    }

                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    Toggle("Running", isOn: $isRunning)

                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                        .disabled(isRunning)

                    if isRunning {
                        Text("Ends at now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Label (optional)", text: $noteText)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Edit details")
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showDetails.toggle()
                }
            }

            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Delete", role: .destructive) {
                    showDeleteConfirm = true
                }
                .keyboardShortcut(.delete, modifiers: [.command])

                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    do {
                        try manager.updateSegment(id: segment.id, tag: selectedTag, start: startDate, end: endDate, note: noteText.isEmpty ? nil : noteText)
                        if splitEnabled {
                            let splitDate = combine(day: day, time: splitTime)
                            try manager.splitSegment(id: segment.id, at: splitDate, beforeTag: splitBeforeTag, afterTag: splitAfterTag)
                        }
                        dismiss()
                    } catch {
                        splitErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to save segment."
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .keyboardShortcut(.defaultAction)
                .disabled(validationError != nil)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
        .onAppear {
            selectedTag = manager.tagForSegment(segment)
            startTime = segment.start
            let end = segment.end ?? manager.nowTick
            endTime = end
            isRunning = segment.end == nil
            noteText = segment.note ?? ""
            splitEnabled = true
            splitTime = defaultSplitTime(for: segment, end: end)
            splitBeforeTag = selectedTag
            splitAfterTag = manager.suggestedAfterTag(for: selectedTag, referenceDate: end) ?? selectedTag
        }
        .confirmationDialog("Delete Segment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                manager.deleteSegment(id: segment.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func defaultSplitTime(for segment: Segment, end: Date) -> Date {
        if segment.end == nil {
            let elapsed = max(0, manager.nowTick.timeIntervalSince(segment.start))
            let midpoint = segment.start.addingTimeInterval(elapsed / 2)
            let latest = manager.nowTick.addingTimeInterval(-5 * 60)
            let minSplit = segment.start.addingTimeInterval(60)
            return max(minSplit, min(midpoint, latest))
        }
        let mid = segment.start.addingTimeInterval(end.timeIntervalSince(segment.start) / 2)
        return mid
    }

    private func applyQuickSplit(minutes: Int) {
        let end = segment.end ?? manager.nowTick
        let target = end.addingTimeInterval(-TimeInterval(minutes) * 60)
        splitTime = target
        splitEnabled = true
        hasAdjustedSplitTime = true
    }

    private func tagMenu(selection: Binding<TagItem>) -> some View {
        Menu {
            ForEach(manager.allTags) { tag in
                Button(tag.name) {
                    selection.wrappedValue = tag
                }
            }
        } label: {
            Text(selection.wrappedValue.name)
                .lineLimit(2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
    }

    private var timePickerLabel: some View {
        let components = splitTimeComponents(for: splitTime)
        return HStack(spacing: 0) {
            Text(components.hour)
                .foregroundStyle(hasAdjustedSplitTime && activeSplitComponent == .hour ? .primary : .secondary)
                .onTapGesture {
                    activeSplitComponent = .hour
                    hasAdjustedSplitTime = true
                }
            Text(components.separator)
                .foregroundStyle(.secondary)
            Text(components.minute)
                .foregroundStyle(hasAdjustedSplitTime && activeSplitComponent == .minute ? .primary : .secondary)
                .onTapGesture {
                    activeSplitComponent = .minute
                    hasAdjustedSplitTime = true
                }
            Text(components.suffix)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
        }
        .font(.system(.headline, design: .monospaced))
        .monospacedDigit()
        .contentShape(Rectangle())
    }

    private func splitTimeComponents(for date: Date) -> (hour: String, minute: String, separator: String, suffix: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let formatted = formatter.string(from: date)
        let parts = formatted.split(separator: " ")
        let time = parts.first.map(String.init) ?? ""
        let suffix = parts.dropFirst().first.map(String.init) ?? ""
        let timeParts = time.split(separator: ":")
        let hour = timeParts.first.map(String.init) ?? ""
        let minute = timeParts.dropFirst().first.map(String.init) ?? ""
        return (hour, minute, ":", " " + suffix)
    }

    private func updatedSplitTime(hour: Int, minute: Int) -> Date {
        let clampedHour = max(0, min(23, hour))
        let clampedMinute = max(0, min(59, minute))
        return calendar.date(bySettingHour: clampedHour, minute: clampedMinute, second: 0, of: splitTime) ?? splitTime
    }

    private enum SplitComponent {
        case hour
        case minute
    }

    private func combine(day: Date, time: Date) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged) ?? time
    }
}
