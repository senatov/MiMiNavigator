// MultiRenameRulesView.swift
// MiMiNavigator

import SwiftUI

// MARK: - Multi Rename Rules View

struct MultiRenameRulesView: View {
    @Bindable var viewModel: MultiRenameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Scope", selection: $viewModel.scope) {
                ForEach(MultiRenameScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                        .disabled(scope == .selection && !viewModel.canUseSelection)
                }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 12) {
                labeledField("Name mask", text: $viewModel.nameMask, hint: "[N]")
                labeledField("Extension", text: $viewModel.extensionMask, hint: "[E]")
            }
            HStack(spacing: 12) {
                labeledField("Search for", text: $viewModel.searchText, hint: "Text or expression")
                labeledField("Replace with", text: $viewModel.replacementText, hint: "Replacement")
            }
            HStack(spacing: 16) {
                Toggle("Regular expression", isOn: $viewModel.useRegex)
                Toggle("Case sensitive", isOn: $viewModel.caseSensitive)
                Spacer()
                Text("Case")
                Picker("", selection: $viewModel.caseMode) {
                    ForEach(MultiRenameCaseMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                .labelsHidden()
                .frame(width: 150)
            }
            HStack(spacing: 10) {
                Text("Counter")
                numericField("Start", value: $viewModel.counterStart)
                numericField("Step", value: $viewModel.counterStep)
                Stepper("Digits: \(viewModel.counterDigits)", value: $viewModel.counterDigits, in: 1 ... 8)
                Spacer()
                Menu("Insert token") {
                    Button("Name [N]") { viewModel.nameMask += "[N]" }
                    Button("Extension [E]") { viewModel.nameMask += "[E]" }
                    Button("Counter [C]") { viewModel.nameMask += "[C]" }
                }
            }
            Text("Tokens: [N] original name, [E] extension, [C] counter")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private func labeledField(_ title: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(hint, text: text).textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity)
    }

    private func numericField(_ title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            TextField(title, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
        }
    }
}
