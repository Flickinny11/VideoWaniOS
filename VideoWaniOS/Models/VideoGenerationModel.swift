import Foundation
import SwiftUI

struct VideoRequest: Identifiable, Codable {
    var id = UUID()
    var prompt: String
    var image: Data?
    var imageURL: URL?
    var status: VideoStatus
    var progress: Double
    var resultVideoURL: URL?
    var createdAt: Date
    var resolution: VideoResolution
    var modelType: ModelType
    
    init(prompt: String, image: Data? = nil, imageURL: URL? = nil, status: VideoStatus = .pending, progress: Double = 0.0, createdAt: Date = Date(), resolution: VideoResolution = .r480p, modelType: ModelType = .t2v14B) {
        self.prompt = prompt
        self.image = image
        self.imageURL = imageURL
        self.status = status
        self.progress = progress
        self.createdAt = createdAt
        self.resolution = resolution
        self.modelType = modelType
    }
}

enum VideoStatus: String, Codable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
}

enum VideoResolution: String, Codable, CaseIterable {
    case r480p = "480p"
    case r720p = "720p"
    
    var dimensions: (width: Int, height: Int) {
        switch self {
        case .r480p:
            return (832, 480)
        case .r720p:
            return (1280, 720)
        }
    }
}

enum ModelType: String, Codable, CaseIterable {
    case t2v14B = "T2V-14B"
    case t2v1_3B = "T2V-1.3B"
    case i2v14B480P = "I2V-14B-480P"
    case i2v14B720P = "I2V-14B-720P"
    
    var displayName: String {
        switch self {
        case .t2v14B:
            return "Text-to-Video 14B"
        case .t2v1_3B:
            return "Text-to-Video 1.3B"
        case .i2v14B480P:
            return "Image-to-Video 14B (480p)"
        case .i2v14B720P:
            return "Image-to-Video 14B (720p)"
        }
    }
    
    var requiresImage: Bool {
        return self == .i2v14B480P || self == .i2v14B720P
    }
    
    var supportedResolutions: [VideoResolution] {
        switch self {
        case .t2v14B:
            return [.r480p, .r720p]
        case .t2v1_3B:
            return [.r480p]
        case .i2v14B480P:
            return [.r480p]
        case .i2v14B720P:
            return [.r720p]
        }
    }
    
    var taskName: String {
        switch self {
        case .t2v14B:
            return "t2v-14B"
        case .t2v1_3B:
            return "t2v-1.3B"
        case .i2v14B480P:
            return "i2v-14B"
        case .i2v14B720P:
            return "i2v-14B"
        }
    }
}

struct APIResponse: Codable {
    let requestId: String
    let status: String
    let progress: Double?
    let videoUrl: String?
    let error: String?
}

struct PromptExtension: Codable {
    let originalPrompt: String
    let extendedPrompt: String
}
