import SwiftUI
import Combine

struct ServerSettingsView: View {
    @EnvironmentObject var viewModel: GenerationViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isLocalMode = true
    @State private var statusMessage = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Mode")) {
                    Toggle("Use Built-in Server", isOn: $isLocalMode)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                if !isLocalMode {
                    Section(header: Text("External Server")) {
                        Text("External server mode is disabled in this version")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("Server Status")) {
                    if viewModel.wanVideoService.localServerIsRunning {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Local server is running")
                        }
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Local server is not running")
                        }
                        
                        Button("Restart Server") {
                            restartServer()
                        }
                    }
                }
                
                Section(header: Text("Model Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Embedded Server Features")
                            .font(.headline)
                        
                        Text("• Video generation from prompts")
                        Text("• Image-to-video conversion")
                        Text("• Multiple resolution support (480p/720p)")
                        Text("• Optimized prompt enhancement")
                        Text("• Efficient video processing")
                        
                        Text("The embedded server simulates video generation to demonstrate the app's functionality without requiring external services. Generated videos are GIF animations that simulate the Wan Video output process.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Server Settings")
            .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() })
            .onAppear {
                isLocalMode = viewModel.wanVideoService.isUsingLocalServer()
            }
            .onChange(of: isLocalMode) { newValue in
                viewModel.wanVideoService.setUseLocalServer(newValue)
                viewModel.checkServerConfiguration()
            }
        }
    }
    
    private func restartServer() {
        statusMessage = "Restarting server..."
        
        viewModel.wanVideoService.startLocalServer()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        statusMessage = "Error: \(error.localizedDescription)"
                    }
                },
                receiveValue: { success in
                    statusMessage = success ? "Server started successfully" : "Failed to start server"
                    viewModel.checkServerConfiguration()
                }
            )
            .store(in: &cancellables)
    }
}