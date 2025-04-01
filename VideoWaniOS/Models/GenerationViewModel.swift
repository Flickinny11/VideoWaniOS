import Foundation
import SwiftUI
import Combine
import Photos

class GenerationViewModel: ObservableObject {
    @Published var videoRequests: [VideoRequest] = []
    @Published var selectedImage: UIImage?
    @Published var prompt: String = ""
    @Published var selectedResolution: VideoResolution = .r720p
    @Published var selectedModel: ModelType = .t2v14B
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var usePromptExtension: Bool = true
    @Published var isServerConfigured: Bool = false
    @Published var showSettingsView: Bool = false
    
    let wanVideoService = WanVideoService()
    var cancellables = Set<AnyCancellable>()
    private var pollingTimers: [UUID: Timer] = [:]
    
    init() {
        loadSavedRequests()
        startPollingForAllProcessingRequests()
        checkServerConfiguration()
    }
    
    func checkServerConfiguration() {
        // If using local server, configuration is based on our local server status
        if wanVideoService.isUsingLocalServer() {
            isServerConfigured = wanVideoService.localServerIsRunning
            return
        }
        
        // Otherwise check remote server
        let serverURL = wanVideoService.getServerURL()
        isServerConfigured = serverURL != "http://localhost:7860"
        
        // If configured, verify connection
        if isServerConfigured {
            wanVideoService.checkServerConnection()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure = completion {
                            self?.isServerConfigured = false
                        }
                    },
                    receiveValue: { [weak self] isConnected in
                        self?.isServerConfigured = isConnected
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    func loadSavedRequests() {
        if let data = UserDefaults.standard.data(forKey: "videoRequests"),
           let decoded = try? JSONDecoder().decode([VideoRequest].self, from: data) {
            self.videoRequests = decoded
        }
    }
    
    func saveRequests() {
        if let encoded = try? JSONEncoder().encode(videoRequests) {
            UserDefaults.standard.set(encoded, forKey: "videoRequests")
        }
    }
    
    // Clean and sanitize prompt
    private func sanitizePrompt(_ input: String) -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Empty prompt"
        }
        
        // Remove excessive whitespace
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
                          .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Ensure prompt ends with a period or other sentence-ending punctuation
        if !".!?".contains(cleaned.last ?? " ") {
            cleaned += "."
        }
        
        return cleaned
    }
    
    func submitVideoRequest() {
        guard isServerConfigured else {
            self.errorMessage = "Please configure your Wan Video server first"
            self.showSettingsView = true
            return
        }
        
        let cleanedPrompt = sanitizePrompt(prompt)
        
        guard !cleanedPrompt.isEmpty && cleanedPrompt != "Empty prompt" else {
            self.errorMessage = "Please enter a valid prompt"
            return
        }
        
        if selectedModel.requiresImage && selectedImage == nil {
            self.errorMessage = "Please select an image for Image-to-Video generation"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var imageData: Data?
        if let image = selectedImage {
            if let data = image.jpegData(compressionQuality: 0.8) {
                imageData = data
            }
        }
        
        let request = VideoRequest(
            prompt: cleanedPrompt,
            image: imageData,
            resolution: selectedResolution,
            modelType: selectedModel
        )
        
        videoRequests.append(request)
        saveRequests()
        
        // Process the prompt extension if needed
        let processPrompt = usePromptExtension ? 
            wanVideoService.extendPrompt(cleanedPrompt) : 
            Just(cleanedPrompt).setFailureType(to: Error.self).eraseToAnyPublisher()
        
        processPrompt
            .flatMap { extendedPrompt in
                return self.wanVideoService.submitVideoGenerationRequest(
                    request: request,
                    extendedPrompt: extendedPrompt
                )
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.updateRequestStatus(id: request.id, status: .failed)
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] requestId in
                    guard let self = self else { return }
                    self.updateRequestStatus(id: request.id, status: .processing)
                    self.startPollingForRequestStatus(requestId: requestId, requestUUID: request.id)
                    self.prompt = ""
                    self.selectedImage = nil
                }
            )
            .store(in: &cancellables)
    }
    
    private func startPollingForRequestStatus(requestId: String, requestUUID: UUID) {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollRequestStatus(requestId: requestId, requestUUID: requestUUID)
        }
        pollingTimers[requestUUID] = timer
    }
    
    private func startPollingForAllProcessingRequests() {
        for request in videoRequests where request.status == .processing {
            // For simplicity, we'll restart processing requests when the app launches
            // In a real app, we would store the requestId and resume polling
            updateRequestStatus(id: request.id, status: .pending)
        }
    }
    
    private func pollRequestStatus(requestId: String, requestUUID: UUID) {
        wanVideoService.checkRequestStatus(requestId: requestId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.updateRequestStatus(id: requestUUID, status: .failed)
                        self?.stopPollingForRequest(id: requestUUID)
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    
                    if response.status == "completed" {
                        if let urlString = response.videoUrl, let url = URL(string: urlString) {
                            self.updateRequest(id: requestUUID) { request in
                                request.resultVideoURL = url
                                request.status = .completed
                                request.progress = 1.0
                            }
                        }
                        self.stopPollingForRequest(id: requestUUID)
                    } else if response.status == "failed" {
                        self.updateRequestStatus(id: requestUUID, status: .failed)
                        self.stopPollingForRequest(id: requestUUID)
                    } else if let progress = response.progress {
                        self.updateRequestProgress(id: requestUUID, progress: progress)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func stopPollingForRequest(id: UUID) {
        pollingTimers[id]?.invalidate()
        pollingTimers.removeValue(forKey: id)
    }
    
    private func updateRequestStatus(id: UUID, status: VideoStatus) {
        updateRequest(id: id) { $0.status = status }
    }
    
    private func updateRequestProgress(id: UUID, progress: Double) {
        updateRequest(id: id) { $0.progress = progress }
    }
    
    private func updateRequest(id: UUID, update: (inout VideoRequest) -> Void) {
        if let index = videoRequests.firstIndex(where: { $0.id == id }) {
            var request = videoRequests[index]
            update(&request)
            videoRequests[index] = request
            saveRequests()
        }
    }
    
    func downloadVideo(from request: VideoRequest) {
        guard let videoURL = request.resultVideoURL else { return }
        
        // Check if it's a local file URL that we can save to Photos
        if videoURL.isFileURL && (videoURL.pathExtension.lowercased() == "mp4" || videoURL.pathExtension.lowercased() == "mov") {
            saveVideoToPhotoLibrary(videoURL: videoURL)
        } else {
            // Just open the URL if it's not a local video file
            UIApplication.shared.open(videoURL)
        }
    }
    
    func saveVideoToPhotoLibrary(videoURL: URL) {
        // Import the Photos framework in your project
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    // Add the video as an asset to the photo library
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.errorMessage = "Video saved to Photos library"
                        } else if let error = error {
                            self.errorMessage = "Error saving video: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Permission to save to Photos denied"
                }
            }
        }
    }
    
    func deleteRequest(_ request: VideoRequest) {
        videoRequests.removeAll { $0.id == request.id }
        stopPollingForRequest(id: request.id)
        saveRequests()
    }
}