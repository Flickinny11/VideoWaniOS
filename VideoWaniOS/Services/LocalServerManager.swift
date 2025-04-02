import Foundation
import Combine

class LocalServerManager {
    // Singleton instance
    static let shared = LocalServerManager()
    
    // Server status
    private(set) var isRunning = false
    private var serverProcess: Any? = nil  // Changed from Process to Any
    private var serverURL = "http://localhost:7860"
    
    // Document directories
    private var documentsURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var serverDirectoryURL: URL {
        return documentsURL.appendingPathComponent("server", isDirectory: true)
    }
    
    // Initialization
    private init() {
        setupServerEnvironment()
    }
    
    // Ensure server files are in place
    private func setupServerEnvironment() {
        // Create server directory if needed
        try? FileManager.default.createDirectory(at: serverDirectoryURL, withIntermediateDirectories: true)
        
        // Check if server files exist, if not, extract them from the bundle
        let serverPyPath = serverDirectoryURL.appendingPathComponent("server.py")
        if !FileManager.default.fileExists(atPath: serverPyPath.path) {
            if let bundledServerPath = Bundle.main.path(forResource: "server", ofType: "py") {
                try? FileManager.default.copyItem(atPath: bundledServerPath, toPath: serverPyPath.path)
            }
        }
        
        // Create needed directories
        let serverPaths = ["uploads", "output", "logs", "request_data"]
        for path in serverPaths {
            let dirURL = serverDirectoryURL.appendingPathComponent(path, isDirectory: true)
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
    }
    
    // Start the server
    func startServer() -> AnyPublisher<Bool, Error> {
        // If server is already running, just return success
        if isRunning {
            return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        // For iOS, we'll simulate the server since we can't actually run Python
        // In a real implementation, this would use something like PythonKit or a compiled Python interpreter
        
        // Mark server as running
        isRunning = true
        
        // Create a sample video generator function
        createMockServerFunctionality()
        
        // Simulate a short delay for server startup
        return Just(true)
            .delay(for: .seconds(1), scheduler: DispatchQueue.global())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // Stop the server
    func stopServer() {
        isRunning = false
        // We don't use Process in this implementation
        serverProcess = nil
    }
    
    // Setup mock server functionality (since we can't run an actual Python server on iOS)
    private func createMockServerFunctionality() {
        // In a real implementation, this would start a local Python server
        // For this demo, we'll set up mock data for video generation
        
        // Create a sample output directory structure
        let outputDir = serverDirectoryURL.appendingPathComponent("output")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // We'll handle the actual mock server logic in a custom URLProtocol that 
        // intercepts requests to localhost:7860 and provides appropriate responses
        // This is implemented in MockServerURLProtocol.swift
    }
    
    // Get server URL
    func getServerURL() -> String {
        return serverURL
    }
}
