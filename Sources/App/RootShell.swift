import DesignSystem
import SwiftUI

struct RootShell: View {
    @StateObject private var store = FilterMarketStore()

    var body: some View {
        TabView {
            CameraScreen()
                .tabItem {
                    Label("Camera", systemImage: "camera.fill")
                }

            FilterLibraryScreen()
                .tabItem {
                    Label("Filters", systemImage: "square.stack.3d.up.fill")
                }

            MarketplaceScreen()
                .tabItem {
                    Label("Market", systemImage: "bag.fill")
                }

            ProfileScreen()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(FMColor.accent)
        .background(FMColor.background)
        .environmentObject(store)
        .task {
            await store.load()
        }
    }
}
