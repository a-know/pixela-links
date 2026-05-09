import SwiftUI

struct AccountSetupView: View {
    let existing: PixelaAccountConfig?
    let onSave: (PixelaAccountConfig) -> Void

    @State private var viewModel = AccountSetupViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Pixelaアカウント") {
                    TextField("ユーザー名", text: $viewModel.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("APIトークン", text: $viewModel.token)
                }

                Section {
                    Button {
                        Task { await viewModel.validate() }
                    } label: {
                        HStack {
                            Text("接続を確認する")
                            if viewModel.isValidating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!viewModel.canValidate)

                    if let message = viewModel.validationMessage {
                        Label(message, systemImage: viewModel.validationIsSuccess ? "checkmark.circle" : "xmark.circle")
                            .foregroundStyle(viewModel.validationIsSuccess ? Color.green : Color.red)
                            .font(.footnote)
                    }
                }

                if viewModel.canSave {
                    Section {
                        Button("保存する") {
                            onSave(viewModel.save())
                        }
                        .bold()
                    }
                }
            }
            .navigationTitle("Pixelaアカウント設定")
            .onAppear {
                if let existing { viewModel.prefill(with: existing) }
            }
        }
    }
}
