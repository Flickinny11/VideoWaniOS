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
        
        if path == "/api/health" {
            // Health check endpoint
            handleHealthCheck(client: client)
        } else if path == "/api/extend-prompt" {
            // Prompt extension endpoint
            handlePromptExtension(request: request, client: client)
        } else if path == "/api/generate" {
            // Video generation endpoint
            handleGeneration(request: request, client: client)
        } else if path.hasPrefix("/api/status/") {
            // Status check endpoint
            let requestId = path.replacingOccurrences(of: "/api/status/", with: "")
            handleStatusCheck(requestId: requestId, client: client)
        } else if path.hasPrefix("/api/video/") {
            // Video retrieval endpoint
            let requestId = path.replacingOccurrences(of: "/api/video/", with: "")
            handleVideoRetrieval(requestId: requestId, client: client)
        } else {
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
                let enhancedPrompt = "\(prompt) with high-quality detail, natural motion, cinematic lighting, realistic textures, smooth transitions, professional composition, with realistic environment."
                
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
            let responseDict: [String: Any] = [
                "requestId": requestId,
                "status": videoRequest.status.rawValue.lowercased(),
                "progress": videoRequest.progress
            ]
            
            // Add video URL if completed
            if videoRequest.status == .completed {
                if let videoURL = MockServerURLProtocol.generatedVideos[requestId] {
                    let videoUrlString = "http://localhost:7860/api/video/\(requestId)"
                    var responseDictWithURL = responseDict
                    responseDictWithURL["videoUrl"] = videoUrlString
                    
                    let responseData = try! JSONSerialization.data(withJSONObject: responseDictWithURL, options: [])
                    
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
                    return
                }
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
                
                // Create successful response
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "image/gif"] // Using GIF as our video format
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
                        
                        // Create successful response
                        let response = HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "image/gif"]
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
    
    // Generate a mock video (animated GIF)
    private func generateMockVideo(requestId: String, completion: @escaping (URL?) -> Void) {
        // Get the video request
        guard let request = MockServerURLProtocol.activeRequests[requestId] else {
            completion(nil)
            return
        }
        
        // Create an animated GIF
        DispatchQueue.global().async {
            // Create a directory for videos if it doesn't exist
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoDir = docDir.appendingPathComponent("videos", isDirectory: true)
            try? FileManager.default.createDirectory(at: videoDir, withIntermediateDirectories: true)
            
            // Create a file URL for our GIF
            let fileURL = videoDir.appendingPathComponent("\(requestId).gif")
            
            // Create a simple animated GIF
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
            
            // Create frames
            var images: [UIImage] = []
            let frameCount = 10
            
            for i in 0..<frameCount {
                // Create a UIImage for this frame
                UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 1.0)
                let context = UIGraphicsGetCurrentContext()!
                
                // Draw background
                context.setFillColor(UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0).cgColor)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                
                // Draw animated element
                let progress = CGFloat(i) / CGFloat(frameCount - 1)
                let xPos = Int(progress * CGFloat(width - 100))
                let yPos = height / 2 - 50
                
                context.setFillColor(UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).cgColor)
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(2.0)
                context.addRect(CGRect(x: xPos, y: yPos, width: 100, height: 100))
                context.drawPath(using: .fillStroke)
                
                // Add text showing the prompt
                let promptText = request.prompt
                let promptAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.white,
                    .font: UIFont.systemFont(ofSize: 14)
                ]
                let promptRect = CGRect(x: 10, y: height - 30, width: width - 20, height: 20)
                (promptText as NSString).draw(in: promptRect, withAttributes: promptAttributes)
                
                // Add frame number
                let frameText = "Frame \(i+1)/\(frameCount)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.white,
                    .font: UIFont.systemFont(ofSize: 12)
                ]
                let textRect = CGRect(x: 10, y: 10, width: 100, height: 20)
                (frameText as NSString).draw(in: textRect, withAttributes: attributes)
                
                // Get the image and add to our array
                let image = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext()
                
                images.append(image)
            }
            
            // Create the animated GIF data
            let gifData = self.createGIFFromImages(images, delayTime: 0.2)
            
            // Save to file
            do {
                try gifData.write(to: fileURL)
                completion(fileURL)
            } catch {
                print("Error saving GIF: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    // Create a GIF from a sequence of images
    private func createGIFFromImages(_ images: [UIImage], delayTime: TimeInterval) -> Data {
        let data = NSMutableData()
        
        // Add GIF header
        if let gifHeader = try? Data(contentsOf: Bundle.main.url(forResource: "gif_header", ofType: "data")!) {
            data.append(gifHeader)
        } else {
            // Simplified GIF creation - not a complete implementation
            // In a real app, you would use a proper GIF creation library
            
            // Create a simple static image as fallback
            if let firstImage = images.first,
               let jpegData = firstImage.jpegData(compressionQuality: 0.8) {
                return jpegData
            }
        }
        
        return data as Data
    }
}