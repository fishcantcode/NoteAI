import SwiftUI

@main
struct NoteAiApp: App {
    var body: some Scene {
        WindowGroup {
            FolderListView(apiManager: APIManager.shared)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Background").ignoresSafeArea())
        }
    }
}
