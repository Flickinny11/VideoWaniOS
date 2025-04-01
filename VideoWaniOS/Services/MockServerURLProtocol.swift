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
        // Get the video request
        guard let request = MockServerURLProtocol.activeRequests[requestId] else {
            completion(nil)
            return
        }
        
        // Create an MP4 video
        DispatchQueue.global().async {
            // Create a directory for videos if it doesn't exist
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoDir = docDir.appendingPathComponent("videos", isDirectory: true)
            try? FileManager.default.createDirectory(at: videoDir, withIntermediateDirectories: true)
            
            // Create a file URL for our MP4
            let fileURL = videoDir.appendingPathComponent("\(requestId).mp4")
            
            // Create a video with proper dimensions
            let width: Int
            let height: Int
            
            // Set dimensions based on resolution
            switch request.resolution {
            case .r480p:
                width = 640
                height = 360
            case .r720p:
                width = 1280
                height = 720
            }
            
            // Create more frames for smoother video (30fps)
            var images: [UIImage] = []
            let frameCount = 30 // 1 second at 30fps
            
            for i in 0..<frameCount {
                UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 1.0)
                guard let context = UIGraphicsGetCurrentContext() else {
                    UIGraphicsEndImageContext()
                    continue
                }
                
                // Draw background - dark gradient
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0).cgColor,
                        UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0).cgColor
                    ] as CFArray,
                    locations: [0.0, 1.0]
                )!
                
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: width, y: height),
                    options: []
                )
                
                // Draw a more sophisticated animated element
                let progress = CGFloat(i) / CGFloat(frameCount - 1)
                
                // Motion path - object moves across screen in a wave pattern
                let xPos = Int(progress * CGFloat(width - 150))
                let amplitude = CGFloat(height) * 0.2
                let frequency = 3.0 // Higher values make more wave cycles
                let yOffset = sin(progress * .pi * frequency) * amplitude
                let yPos = Int(CGFloat(height) / 2 - 75 + yOffset)
                
                // Draw a more interesting shape - gradient-filled circle with shadow
                context.setShadow(offset: CGSize(width: 5, height: 5), blur: 5, color: UIColor.black.withAlphaComponent(0.5).cgColor)
                
                let objectRect = CGRect(x: xPos, y: yPos, width: 150, height: 150)
                let objectPath = UIBezierPath(ovalIn: objectRect)
                
                // Create a 3D-like gradient for the object
                let objectGradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0).cgColor,
                        UIColor(red: 0.2, green: 0.3, blue: 0.8, alpha: 1.0).cgColor
                    ] as CFArray,
                    locations: [0.0, 1.0]
                )!
                
                context.saveGState()
                context.addPath(objectPath.cgPath)
                context.clip()
                context.drawLinearGradient(
                    objectGradient,
                    start: CGPoint(x: xPos, y: yPos),
                    end: CGPoint(x: xPos + 150, y: yPos + 150),
                    options: []
                )
                context.restoreGState()
                
                // Add highlight to simulate lighting
                context.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
                let highlightPath = UIBezierPath(ovalIn: CGRect(
                    x: xPos + 30,
                    y: yPos + 30,
                    width: 50,
                    height: 50
                ))
                context.addPath(highlightPath.cgPath)
                context.fillPath()
                
                // Add text showing the prompt with a nicer style
                let promptText = request.prompt
                
                // Add background for text readability
                let textBgRect = CGRect(x: 0, y: height - 50, width: width, height: 40)
                context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
                context.fill(textBgRect)
                
                // Draw text with shadow
                context.setShadow(offset: CGSize(width: 1, height: 1), blur: 2, color: UIColor.black.cgColor)
                
                let promptAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.white,
                    .font: UIFont.systemFont(ofSize: 18, weight: .medium)
                ]
                let promptRect = CGRect(x: 20, y: height - 40, width: width - 40, height: 30)
                (promptText as NSString).draw(in: promptRect, withAttributes: promptAttributes)
                
                // Add timestamp
                let frameText = String(format: "%.2f sec", Double(i) / Double(frameCount))
                let timestampAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.white,
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
                ]
                let timestampRect = CGRect(x: width - 100, y: 10, width: 90, height: 20)
                (frameText as NSString).draw(in: timestampRect, withAttributes: timestampAttributes)
                
                // Capture the image
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let image = image {
                    images.append(image)
                }
            }
            
            // Generate the MP4 video
            VideoGenerator.generateMP4FromImages(images, frameRate: 30, outputURL: fileURL) { success, error in
                if success {
                    completion(fileURL)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
