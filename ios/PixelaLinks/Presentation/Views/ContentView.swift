import SwiftUI

struct ContentView: View {
    @State private var account = PixelaAccountConfig.load()
    @State private var showingAccountSetup = false

    var body: some View {
        if account.isConfigured {
            HomeView(
                account: account,
                onAccountTap: { showingAccountSetup = true }
            )
            .sheet(isPresented: $showingAccountSetup) {
                AccountSetupView(existing: account) { saved in
                    account = saved
                    showingAccountSetup = false
                }
            }
        } else {
            AccountSetupView(existing: nil) { saved in
                account = saved
            }
        }
    }
}
