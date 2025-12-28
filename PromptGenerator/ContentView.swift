import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PromptGeneratorViewModel()
    @State private var selectedFramework: PromptFramework = .auto
    
    var body: some View {
        HSplitView {
            // Input Panel
            VStack(alignment: .leading, spacing: 16) {
                Text("AI Prompt Generator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("Create optimized prompts using professional AI engineering frameworks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
                
                // Framework Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Framework")
                        .font(.headline)
                    
                    Picker("Framework", selection: $selectedFramework) {
                        Text("Auto-detect").tag(PromptFramework.auto)
                        Text("RISE").tag(PromptFramework.rise)
                        Text("CREATE").tag(PromptFramework.create)
                        Text("RACE").tag(PromptFramework.race)
                        Text("CREO").tag(PromptFramework.creo)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.bottom, 8)
                
                // Task Description Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("What do you want to accomplish?")
                        .font(.headline)
                    
                    TextEditor(text: $viewModel.userInput)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Additional Context (Optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Context (Optional)")
                        .font(.headline)
                    
                    TextEditor(text: $viewModel.additionalContext)
                        .font(.body)
                        .frame(minHeight: 80)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Generate Button
                Button(action: {
                    viewModel.generatePrompt(framework: selectedFramework)
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate Prompt")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 350, idealWidth: 400)
            
            // Output Panel
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Generated Prompt")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if !viewModel.generatedPrompt.isEmpty {
                        Button(action: {
                            viewModel.copyToClipboard()
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if viewModel.isGenerating {
                    ProgressView("Generating prompt...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.generatedPrompt.isEmpty {
                    VStack {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Enter your task description and click Generate to create an optimized prompt")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // Framework Info
                            if let framework = viewModel.usedFramework {
                                HStack {
                                    Label(framework.displayName, systemImage: "brain.head.profile")
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                            
                            // Generated Prompt
                            Text(viewModel.generatedPrompt)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding()
            .frame(minWidth: 400)
        }
        .alert("Copied!", isPresented: $viewModel.showCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Prompt copied to clipboard")
        }
    }
}

#Preview {
    ContentView()
}

