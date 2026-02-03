import SwiftUI
import AppKit

struct PopoverView: View {
    @EnvironmentObject private var manager: TimerManager
    @Environment(\.openWindow) private var openWindow

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Switch Tag")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(manager.tags) { tag in
                    Button(action: { manager.switchTag(to: tag) }) {
                        Text(tag.name)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(tagColor(tag).opacity(manager.currentTag.id == tag.id ? 0.35 : 0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(tagColor(tag).opacity(manager.currentTag.id == tag.id ? 0.8 : 0.2), lineWidth: 1)
                    )
                }
            }

            HStack(spacing: 8) {
                Button("Open Dashboard") {
                    openWindow(id: "dashboard")
                    DispatchQueue.main.async {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        if let dashboardWindow = NSApp.windows.first(where: { $0.title == "Dashboard" }) {
                            dashboardWindow.makeKeyAndOrderFront(nil)
                            dashboardWindow.orderFrontRegardless()
                        }
                    }
                }
                .fixedSize()

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .fixedSize()
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            manager.handleAppBecameActive()
        }
        .onAppear {
            manager.setPopoverVisible(true)
        }
        .onDisappear {
            manager.setPopoverVisible(false)
        }
    }
}
