import Foundation
import Combine
import UIKit

enum WanVideoError: Error, LocalizedError {
    case invalidURL
    case serverError(String)
    case invalidResponse
    case networkError(Error)
    case configurationError
    case localServerNotRunning
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .configurationError:
            return "Server configuration error. Please check your server settings."
        case .localServerNotRunning:
            return "Local server is not running. Please restart the app."
        }
    }
}

class WanVideoService {
    private let session: URLSession
    
    // Default to local server
    private let localServerURLKey = "wan_local_server_url"
    private let localServerEnabledKey = "wan_use_local_server"
    private let defaultLocalURL = "http://localhost:7860"
    
    // Local server process management
    var localServerIsRunning = false
    
    init() {
        // Create a URLSession with extended timeout due to long-running video generation
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 3600 // 1 hour
        self.session = URLSession(configuration: config)
        
        // Initialize local server URL if not set
        if UserDefaults.standard.string(forKey: localServerURLKey) == nil {
            UserDefaults.standard.set(defaultLocalURL, forKey: localServerURLKey)
        }
        
        // Default to using local server
        if !UserDefaults.standard.bool(forKey: localServerEnabledKey) {
            UserDefaults.standard.set(true, forKey: localServerEnabledKey)
        }
    }
    
    // MARK: - Configuration
    
    func getServerURL() -> String {
        return UserDefaults.standard.string(forKey: localServerURLKey) ?? defaultLocalURL
    }
    
    func setServerURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: localServerURLKey)
    }
    
    func isUsingLocalServer() -> Bool {
        return UserDefaults.standard.bool(forKey: localServerEnabledKey)
    }
    
    func setUseLocalServer(_ useLocal: Bool) {
        UserDefaults.standard.set(useLocal, forKey: localServerEnabledKey)
    }
    
    // MARK: - Local Server Management
    
    func startLocalServer() -> AnyPublisher<Bool, Error> {
        // In a real implementation, this would start a Python server via PythonKit
        // Here we'll simulate it by marking our local server as running
        
        self.localServerIsRunning = true
        
        // Notify that the server is started (normally this would be the result of the actual server start)
        return Just(true)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    func stopLocalServer() {
        // Stop the local server
        self.localServerIsRunning = false
    }
    
    // MARK: - Model generation
    
    func submitVideoGenerationRequest(request: VideoRequest, extendedPrompt: String) -> AnyPublisher<String, Error> {
        if isUsingLocalServer() && !localServerIsRunning {
            return Fail(error: WanVideoError.localServerNotRunning).eraseToAnyPublisher()
        }
        
        let baseURL = getServerURL()
        let endpoint = "\(baseURL)/api/generate"
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: WanVideoError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add API key if available (not needed for local server)
        if !isUsingLocalServer() {
            urlRequest.addValue("Bearer wanvideo_secure_key_12345", forHTTPHeaderField: "Authorization")
        }
        
        let modelType = request.modelType.taskName
        let resolution = "\(request.resolution.dimensions.width)*\(request.resolution.dimensions.height)"
        
        var parameters: [String: Any] = [
            "task": modelType,
            "size": resolution,
            "prompt": extendedPrompt,
            "use_prompt_extend": false, // We've already extended the prompt
            "sample_guide_scale": modelType == "t2v-1.3B" ? 6 : 5,
            "negative_prompt": "Bright tones, overexposed, static, blurred details, subtitles, style, works, paintings, images, static, overall gray, worst quality, low quality, JPEG compression residue, ugly, incomplete, extra fingers, poorly drawn hands, poorly drawn faces, deformed, disfigured, misshapen limbs, fused fingers, still picture, messy background"
        ]
        
        // Add proper parameters for the 1.3B model
        if modelType == "t2v-1.3B" {
            parameters["sample_shift"] = 8
        }
        
        // Add image data for I2V models
        if request.modelType.requiresImage, let imageData = request.image {
            let base64Image = imageData.base64EncodedString()
            parameters["image"] = base64Image
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            urlRequest.httpBody = jsonData
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WanVideoError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw WanVideoError.serverError("Status \(httpResponse.statusCode): \(errorMessage)")
                }
                
                return data
            }
            .decode(type: APIResponse.self, decoder: JSONDecoder())
            .tryMap { response in
                if response.status == "accepted" || response.status == "processing" {
                    return response.requestId
                } else if let error = response.error {
                    throw WanVideoError.serverError(error)
                } else {
                    throw WanVideoError.invalidResponse
                }
            }
            .mapError { error in
                if let wanError = error as? WanVideoError {
                    return wanError
                } else {
                    return WanVideoError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func checkRequestStatus(requestId: String) -> AnyPublisher<APIResponse, Error> {
        if isUsingLocalServer() && !localServerIsRunning {
            return Fail(error: WanVideoError.localServerNotRunning).eraseToAnyPublisher()
        }
        
        let baseURL = getServerURL()
        let endpoint = "\(baseURL)/api/status/\(requestId)"
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: WanVideoError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        // Add API key if available (not needed for local server)
        if !isUsingLocalServer() {
            urlRequest.addValue("Bearer wanvideo_secure_key_12345", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WanVideoError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw WanVideoError.serverError("Status \(httpResponse.statusCode): \(errorMessage)")
                }
                
                return data
            }
            .decode(type: APIResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let wanError = error as? WanVideoError {
                    return wanError
                } else {
                    return WanVideoError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func extendPrompt(_ prompt: String) -> AnyPublisher<String, Error> {
        if isUsingLocalServer() && !localServerIsRunning {
            return Fail(error: WanVideoError.localServerNotRunning).eraseToAnyPublisher()
        }
        
        let baseURL = getServerURL()
        let endpoint = "\(baseURL)/api/extend-prompt"
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: WanVideoError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add API key if available (not needed for local server)
        if !isUsingLocalServer() {
            urlRequest.addValue("Bearer wanvideo_secure_key_12345", forHTTPHeaderField: "Authorization")
        }
        
        let parameters: [String: Any] = [
            "prompt": prompt,
            "prompt_extend_method": "local", // Using local model by default
            "prompt_extend_target_lang": "en" // Default to English
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            urlRequest.httpBody = jsonData
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WanVideoError.invalidResponse
                }
                
                if httpResponse.statusCode != 200 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw WanVideoError.serverError("Status \(httpResponse.statusCode): \(errorMessage)")
                }
                
                return data
            }
            .decode(type: PromptExtension.self, decoder: JSONDecoder())
            .map { $0.extendedPrompt }
            .mapError { error in
                if let wanError = error as? WanVideoError {
                    return wanError
                } else {
                    return WanVideoError.networkError(error)
                }
            }
            .catch { error -> AnyPublisher<String, Error> in
                // If prompt extension fails, fall back to a local enhancement
                return Just(self.enhancePromptLocally(prompt))
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // Local prompt enhancement if server fails
    private func enhancePromptLocally(_ prompt: String) -> String {
        return "\(prompt) with high quality detail, natural motion, cinematic lighting, realistic textures, smooth transitions, professional composition, with realistic environment."
    }
    
    // MARK: - Server checks
    
    func checkServerConnection() -> AnyPublisher<Bool, Error> {
        if isUsingLocalServer() {
            // For local server, just return status based on our local flag
            return Just(localServerIsRunning)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        let baseURL = getServerURL()
        let endpoint = "\(baseURL)/api/health"
        
        guard let url = URL(string: endpoint) else {
            return Fail(error: WanVideoError.invalidURL).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        return session.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WanVideoError.invalidResponse
                }
                
                return httpResponse.statusCode == 200
            }
            .mapError { error in
                if let wanError = error as? WanVideoError {
                    return wanError
                } else {
                    return WanVideoError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
}