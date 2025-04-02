import Foundation
import UIKit

// Custom URL protocol to handle requests to our mock server
class MockServerURLProtocol: URLProtocol {
    // Dictionary to store active requests
    static var activeRequests: [String: VideoRequest] = [:]
    static var generatedVideos: [String: URL] = [:]
    
    // Intercept only requests to our local server
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return url.host == "localhost" && url.port == 7860
    }
    
    // Use the URL as the request identifier
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    // Handle the request
    override func startLoading() {
        guard let url = request.url, let client = client else {
            fatalError("Missing URL or client")
        }
        
        // Determine which API endpoint we're accessing
        let path = url.path
        
        switch path {
        case "/api/health":
            // Health check endpoint
            handleHealthCheck(client: client)
        case "/api/extend-prompt":
            // Prompt extension endpoint
            handlePromptExtension(request: request, client: client)
        case "/api/generate":
            // Video generation endpoint
            handleGeneration(request: request, client: client)
        case let path where path.hasPrefix("/api/status/"):
            // Status check endpoint
            let requestId = path.replacingOccurrences(of: "/api/status/", with: "")
            handleStatusCheck(requestId: requestId, client: client)
        case let path where path.hasPrefix("/api/video/"):
            // Video retrieval endpoint
            let requestId = path.replacingOccurrences(of: "/api/video/", with: "")
            handleVideoRetrieval(requestId: requestId, client: client)
        default:
            // Unknown endpoint
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            let errorData = try! JSONSerialization.data(withJSONObject: ["error": "Not found"], options: [])
            client.urlProtocol(self, didLoad: errorData)
            client.urlProtocolDidFinishLoading(self)
        }
    }
    
    // Required implementation - no cleanup needed
    override func stopLoading() {}
    
    // MARK: - API Endpoint handlers
    
    private func handleHealthCheck(client: URLProtocolClient) {
        guard let url = request.url else { return }
        
        // Create a success response
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        // Create response data
        let responseData = try! JSONSerialization.data(
            withJSONObject: ["status": "ok"],
            options: []
        )
        
        // Send response
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: responseData)
        client.urlProtocolDidFinishLoading(self)
    }
    
    private func handlePromptExtension(request: URLRequest, client: URLProtocolClient) {
        guard let url = request.url,
              let body = request.httpBody else {
            sendErrorResponse(client: client, statusCode: 400, error: "Missing request body")
            return
        }
        
        do {
            // Parse request body
            if let requestDict = try JSONSerialization.jsonObject(with: body) as? [String: Any],
               let prompt = requestDict["prompt"] as? String {
                
                // Enhanced prompt
                let enhancedPrompt = "\(prompt) with high-quality detail, natural motion, cinematic lighting, realistic textures, smooth transitions, professional composition, with realistic environments"
                
                // Create response data
                let responseDict: [String: Any] = [
                    "originalPrompt": prompt,
                    "extendedPrompt": enhancedPrompt
                ]
                
                let responseData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
                
                // Create successful response
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                
                // Send response
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self, didLoad: responseData)
                client.urlProtocolDidFinishLoading(self)
            } else {
                sendErrorResponse(client: client, statusCode: 400, error: "Invalid request body")
            }
        } catch {
            sendErrorResponse(client: client, statusCode: 400, error: "Error parsing request: \(error.localizedDescription)")
        }
    }
    
    private func handleGeneration(request: URLRequest, client: URLProtocolClient) {
        guard let url = request.url,
              let body = request.httpBody else {
            sendErrorResponse(client: client, statusCode: 400, error: "Missing request body")
            return
        }
        
        do {
            // Parse request body
            if let requestDict = try JSONSerialization.jsonObject(with: body) as? [String: Any],
               let prompt = requestDict["prompt"] as? String,
               let task = requestDict["task"] as? String,
               let size = requestDict["size"] as? String {
                
                // Create a request ID
                let requestId = UUID().uuidString
                
                // Store request for later status checks
                let videoRequest = VideoRequest(
                    prompt: prompt,
                    status: .processing,
                    progress: 0.0,
                    createdAt: Date(),
                    resolution: size.contains("720") ? .r720p : .r480p,
                    modelType: task.contains("1.3B") ? .t2v1_3B : .t2v14B
                )
                
                MockServerURLProtocol.activeRequests[requestId] = videoRequest
                
                // Start async processing
                DispatchQueue.global().async {
                    self.processVideoGeneration(requestId: requestId)
                }
                
                // Create response data
                let responseDict: [String: Any] = [
                    "requestId": requestId,
                    "status": "accepted"
                ]
                
                let responseData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
                
                // Create successful response
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                
                // Send response
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self, didLoad: responseData)
                client.urlProtocolDidFinishLoading(self)
            } else {
                sendErrorResponse(client: client, statusCode: 400, error: "Invalid request body")
            }
        } catch {
            sendErrorResponse(client: client, statusCode: 400, error: "Error parsing request: \(error.localizedDescription)")
        }
    }
    
    private func handleStatusCheck(requestId: String, client: URLProtocolClient) {
        guard let url = request.url else { return }
        
        // Look up the request
        if let videoRequest = MockServerURLProtocol.activeRequests[requestId] {
            // Create response data
            var responseDict: [String: Any] = [
                "requestId": requestId,
                "status": videoRequest.status.rawValue.lowercased(),
                "progress": videoRequest.progress
            ]
            
            // Add video URL if completed
            if videoRequest.status == .completed, let videoURL = MockServerURLProtocol.generatedVideos[requestId] {
                responseDict["videoUrl"] = "http://localhost:7860/api/video/\(requestId)"
            }
            
            let responseData = try! JSONSerialization.data(withJSONObject: responseDict, options: [])
            
            // Create successful response
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            
            // Send response
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: responseData)
            client.urlProtocolDidFinishLoading(self)
        } else {
            sendErrorResponse(client: client, statusCode: 404, error: "Request not found")
        }
    }
    
    private func handleVideoRetrieval(requestId: String, client: URLProtocolClient) {
        guard let url = request.url else { return }
        
        // Check if we have a video for this request
        if let videoFilePath = MockServerURLProtocol.generatedVideos[requestId] {
            do {
                // Read the video data
                let videoData = try Data(contentsOf: videoFilePath)
                
                // Create successful response with proper content type for MP4
                let contentType = videoFilePath.pathExtension.lowercased() == "mp4" ? "video/mp4" : "image/gif"
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": contentType]
                )!
                
                // Send response
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client.urlProtocol(self, didLoad: videoData)
                client.urlProtocolDidFinishLoading(self)
            } catch {
                sendErrorResponse(client: client, statusCode: 500, error: "Error reading video: \(error.localizedDescription)")
            }
        } else {
            // If we don't have a video, generate one on the fly
            generateMockVideo(requestId: requestId) { fileURL in
                if let fileURL = fileURL {
                    // Store for future reference
                    MockServerURLProtocol.generatedVideos[requestId] = fileURL
                    
                    do {
                        // Read the video data
                        let videoData = try Data(contentsOf: fileURL)
                        
                        // Create successful response with proper content type for MP4
                        let contentType = fileURL.pathExtension.lowercased() == "mp4" ? "video/mp4" : "image/gif"
                        let response = HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": contentType]
                        )!
                        
                        // Send response
                        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                        client.urlProtocol(self, didLoad: videoData)
                        client.urlProtocolDidFinishLoading(self)
                    } catch {
                        self.sendErrorResponse(client: client, statusCode: 500, error: "Error reading video: \(error.localizedDescription)")
                    }
                } else {
                    self.sendErrorResponse(client: client, statusCode: 500, error: "Error generating video")
                }
            }
        }
    }
    
    // MARK: - Helper methods
    
    private func sendErrorResponse(client: URLProtocolClient, statusCode: Int, error: String) {
        guard let url = request.url else { return }
        
        // Create error response
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        // Create error response data
        let errorData = try! JSONSerialization.data(
            withJSONObject: ["error": error],
            options: []
        )
        
        // Send response
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: errorData)
        client.urlProtocolDidFinishLoading(self)
    }
    
    // Simulate async video generation process
    private func processVideoGeneration(requestId: String) {
        // Simulate processing delay
        for progress in stride(from: 0.1, through: 1.0, by: 0.1) {
            // Update progress
            if var request = MockServerURLProtocol.activeRequests[requestId] {
                request.progress = progress
                MockServerURLProtocol.activeRequests[requestId] = request
                
                // When complete, mark as completed
                if progress >= 1.0 {
                    request.status = .completed
                    MockServerURLProtocol.activeRequests[requestId] = request
                    
                    // Generate the video
                    generateMockVideo(requestId: requestId) { fileURL in
                        if let fileURL = fileURL {
                            MockServerURLProtocol.generatedVideos[requestId] = fileURL
                        }
                    }
                }
            }
            
            // Sleep to simulate processing time
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
    
    // Generate a mock video (MP4)
    private func generateMockVideo(requestId: String, completion: @escaping (URL?) -> Void) {
        // Use the implementation from VideoGenerator
        VideoGenerator.generateMockVideo(requestId: requestId, completion: completion)
    }
}
