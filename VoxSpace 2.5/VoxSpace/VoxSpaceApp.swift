import SwiftUI
@main
struct VoxSpaceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if os(macOS)
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    #endif
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 420, height: 595)
    }
}
