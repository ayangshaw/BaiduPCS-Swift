import BaiduKit
import FerryCore
import SwiftUI

/// 侧边栏中的任务分类。
enum JobCategory: String, CaseIterable, Identifiable {
    case all
    /// 转存中和下载中的任务，包括已暂停的任务。
    case active
    case completed
    /// 转存失败和下载失败。
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "全部")
        case .active: String(localized: "进行中")
        case .completed: String(localized: "已完成")
        case .failed: String(localized: "失败")
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .active: "arrow.down.circle"
        case .completed: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        }
    }

    /// 这个分类没有任务时的说明。
    var emptyTitle: String {
        switch self {
        case .all: String(localized: "没有任务")
        case .active: String(localized: "没有进行中的任务")
        case .completed: String(localized: "没有已完成的任务")
        case .failed: String(localized: "没有失败的任务")
        }
    }

    func contains(_ job: Job) -> Bool {
        switch (self, job.phase) {
        case (.all, _), (.active, .transferring), (.active, .downloading), (.completed, .completed), (.failed, .failed):
            true
        default:
            false
        }
    }
}

/// 侧边栏：任务分类和每个分类的任务数。底部是账号。
struct SidebarView: View {
    @Binding var selection: JobCategory?
    @Environment(AppModel.self) private var model

    var body: some View {
        let jobs = model.coordinator.jobs
        List(selection: $selection) {
            ForEach(JobCategory.allCases) { category in
                Label(category.title, systemImage: category.systemImage)
                    .badge(jobs.count(where: category.contains))
                    .tag(category)
            }
        }
        .edgeBar(.bottom) {
            VStack(spacing: 0) {
                StatusBar()
                AccountView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
    }
}

/// 侧边栏底部的状态栏：全部任务的总下载速度。没有在下载时不显示。
private struct StatusBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let activities = model.coordinator.jobs
            .filter { $0.phase == .downloading }
            .map { model.coordinator.activity(of: $0.id) }
        let speed = activities.reduce(0) { $0 + $1.progress.bytesPerSecond }
        if activities.contains(where: \.isRunning), speed > 0 {
            HStack {
                Label("\(Int64(speed).byteCount)/s", systemImage: "arrow.down")
                    .help("全部任务的总下载速度")
                    .accessibilityLabel("总下载速度 \(Int64(speed).byteCount)/s")
                Spacer()
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

/// 侧边栏底部的账号：用户名和状态。点击后弹出账号菜单。未登录时显示“登录…”。
private struct AccountView: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingLogOut = false

    var body: some View {
        if let account = model.account {
            Menu {
                if model.isLoginExpired {
                    Button("重新登录…") { model.presentLogin() }
                }
                Button("退出登录") { isConfirmingLogOut = model.requestLogOut() }
                Divider()
                SettingsLink { Text("设置…") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: model.isLoginExpired ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(account.username.isEmpty ? String(localized: "百度账号") : account.username)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(model.isLoginExpired ? String(localized: "登录已失效") : String(localized: "已登录"))
                            .font(.caption)
                            .foregroundStyle(model.isLoginExpired ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .menuStyle(.button)
            // 悬停和按下时有高亮，看得出可以点击。
            .buttonStyle(.accessoryBar)
            .menuIndicator(.hidden)
            .help("账号")
            .logOutConfirmation(isPresented: $isConfirmingLogOut)
        } else {
            Button {
                model.presentLogin()
            } label: {
                Label("登录…", systemImage: "person.crop.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
    }
}
