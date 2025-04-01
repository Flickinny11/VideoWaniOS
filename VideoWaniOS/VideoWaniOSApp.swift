import SwiftUI

@main
struct VideoWaniOSApp: App {
    @StateObject private var generationViewModel = GenerationViewModel()
    @State private var serverIsStarting = true
    @State private var serverStartError: Error?
    
    init() {
        // Register our custom URL protocol for the mock server
        URLProtocol.registerClass(MockServerURLProtocol.self)
    }
    
    var body: some Scene {
        WindowGroup {
            if serverIsStarting {
                LoadingView(error: serverStartError)
                    .onAppear {
                        startLocalServer()
                    }
            } else {
                ContentView()
                    .environmentObject(generationViewModel)
            }
        }
    }
    
    private func startLocalServer() {
        // Start the local server when app launches
        LocalServerManager.shared.startServer()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    serverStartError = error
                }
            } receiveValue: { success in
                if success {
                    // Update the service to set the local server as running
                    generationViewModel.wanVideoService.localServerIsRunning = true
                    
                    // Set server as configured
                    generationViewModel.checkServerConfiguration()
                    
                    // Allow UI to proceed
                    serverIsStarting = false
                }
            }
            .store(in: &generationViewModel.cancellables)
    }
}

// Loading view shown while server is starting
struct LoadingView: View {
    var error: Error?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.pencil.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            if let error = error {
                Text("Error Starting Server")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(error.localizedDescription)
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(.red)
            } else {
                Text("Starting Video Generator")
                    .font(.title2)
                    .fontWeight(.bold)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding()
                
                Text("Initializing local server...")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}