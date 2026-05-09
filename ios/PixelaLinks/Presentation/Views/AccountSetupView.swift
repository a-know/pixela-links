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
                        .onChange(of: viewModel.username) { _, _ in viewModel.resetValidation() }

                    SecureField("APIトークン", text: $viewModel.token)
                        .onChange(of: viewModel.token) { _, _ in viewModel.resetValidation() }
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
                        Label(message, systemImage: viewModel.validationIsSuccess
                              ? "checkmark.circle" : "xmark.circle")
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
