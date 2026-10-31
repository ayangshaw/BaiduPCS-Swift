import FerryCore
import SwiftUI

@main
struct FerryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Ferry", id: ContentView.windowID) {
            ContentView()
                .environment(appDelegate.model)
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            SidebarCommands()
            InspectorCommands()
            FerryCommands(model: appDelegate.model)
        }

        // 百度的登录页可能比主窗口大，所以登录用单独的窗口，不用 sheet。
        Window("登录百度网盘", id: LoginView.windowID) {
            LoginView()
                .environment(appDelegate.model)
        }
        .windowResizability(.contentSize)
        .commandsRemoved()

        Settings {
            SettingsView()
                .environment(appDelegate.model)
        }
    }
}

private struct FerryCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.jobSelection) private var selection

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Link…") {
                openWindow(id: ContentView.windowID)
                model.presentAddLink()
            }
            .keyboardShortcut("n")
            Button("Download from My Netdisk…") {
                openWindow(id: ContentView.windowID)
                model.presentNetdiskDownload()
            }
            .disabled(!model.canDownloadFromNetdisk)
        }
        CommandMenu("Tasks") {
            // 主窗口不是当前窗口时没有选中的任务，这些操作都不可用。
            JobActionsMenu(jobs: selection?.jobs ?? [], showsUnavailable: true) { selection?.onRemove($0, $1) }
                .environment(model)
            Divider()
            let jobs = model.coordinator.jobs
            Button("Pause All") { model.pauseAll(jobs) }
                .disabled(model.pausableJobs(in: jobs).isEmpty)
            Button("Resume All") { model.resumeAll(jobs) }
                .disabled(model.resumableJobs(in: jobs).isEmpty)
        }
    }
}
