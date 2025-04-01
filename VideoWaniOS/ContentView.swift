import SwiftUI
import AVKit

struct ContentView: View {
    @EnvironmentObject var viewModel: GenerationViewModel
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TabView {
                    creatorView
                        .tabItem {
                            Label("Create", systemImage: "wand.and.stars")
                        }
                    
                    QueueView()
                        .tabItem {
                            Label("Videos", systemImage: "film")
                        }
                }
            }
            .navigationBarTitle("Wan Video", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showSettingsView = true
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettingsView) {
                ServerSettingsView()
                    .environmentObject(viewModel)
            }
            .alert(isPresented: $showError, content: {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            })
            .onChange(of: viewModel.errorMessage) { newError in
                showError = newError != nil
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    var creatorView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Server status banner
                if !viewModel.isServerConfigured {
                    serverStatusBanner
                }
                
                // Hero section
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 150)
                    
                    VStack {
                        Text("Wan Video")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Turn images into stunning videos with AI")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, 5)
                    }
                }
                .padding(.horizontal)
                
                // Input section
                PromptInputView(
                    prompt: $viewModel.prompt,
                    selectedModel: $viewModel.selectedModel,
                    selectedResolution: $viewModel.selectedResolution,
                    usePromptExtension: $viewModel.usePromptExtension,
                    selectedImage: $viewModel.selectedImage
                )
                .padding(.horizontal)
                
                // Generate button
                Button(action: {
                    viewModel.submitVideoRequest()
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 10)
                        } else {
                            Image(systemName: "play.fill")
                                .padding(.trailing, 5)
                        }
                        
                        Text(viewModel.isLoading ? "Processing..." : "Generate Video")
                            .fontWeight(.medium)
                    }
                    .frame(minWidth: 200, minHeight: 50)
                    .background(buttonBackground)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 30)
                }
                .disabled(isGenerateButtonDisabled)
                .padding(.top, 10)
            }
        }
    }
    
    private var serverStatusBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Server Setup Required")
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("You need to configure your Wan Video server before generating videos.")
                .font(.caption)
                .multilineTextAlignment(.leading)
            
            Button("Configure Server") {
                viewModel.showSettingsView = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var isGenerateButtonDisabled: Bool {
        viewModel.isLoading || 
        viewModel.prompt.isEmpty || 
        (viewModel.selectedModel.requiresImage && viewModel.selectedImage == nil) ||
        !viewModel.isServerConfigured
    }
    
    private var buttonBackground: Color {
        if viewModel.isLoading {
            return Color.gray
        }
        
        if isGenerateButtonDisabled {
            return Color.gray.opacity(0.7)
        }
        
        return Color.blue
    }
}