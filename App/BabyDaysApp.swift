import SwiftUI

@main
struct BabyDaysApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            GalleryView()
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 900)
        #if !APP_STORE
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesCommand()
            }
        }
        #endif
        #endif
    }
}
