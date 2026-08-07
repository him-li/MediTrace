import SwiftUI

@main
struct MediTraceApp: App {
    @StateObject private var store = MedicationStore()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        #if os(macOS)
        .defaultSize(width: 1_050, height: 720)
        .commands {
            SidebarCommands()
        }
        #endif
    }
}
