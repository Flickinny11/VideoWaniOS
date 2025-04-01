import SwiftUI
import AVKit
import WebKit

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var isGIF = false
    
    var body: some View {
        ZStack {
            if let error = loadError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .padding()
                    
                    Text("Error loading video")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("Loading video...")
                        .font(.headline)
                }
            } else if isGIF {
                // Use WebView for GIFs
                GIFWebView(url: videoURL)
                    .cornerRadius(12)
                    .aspectRatio(16/9, contentMode: .fit)
            } else if let player = player {
                VideoPlayer(player: player)
                    .cornerRadius(12)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onDisappear {
                        // Stop and cleanup player when view disappears
                        player.pause()
                    }
            }
        }
        .cornerRadius(12)
        .aspectRatio(16/9, contentMode: .fit)
        .onAppear {
            checkMediaType()
        }
    }
    
    private func checkMediaType() {
        isLoading = true
        loadError = nil
        
        // Check if it's a GIF by extension
        if videoURL.pathExtension.lowercased() == "gif" {
            isGIF = true
            isLoading = false
            return
        }
        
        // Otherwise try to load as video
        loadVideo()
    }
    
    private func loadVideo() {
        // Create an asset for inspection
        let asset = AVAsset(url: videoURL)
        
        // Check if the asset is a valid video
        asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            DispatchQueue.main.async {
                var error: NSError?
                let status = asset.statusOfValue(forKey: "playable", error: &error)
                
                if status == .loaded && asset.isPlayable {
                    // Valid video, create a player
                    let playerItem = AVPlayerItem(asset: asset)
                    self.player = AVPlayer(playerItem: playerItem)
                    
                    // Add observer for when playback ends
                    NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: playerItem,
                        queue: .main
                    ) { _ in
                        // Loop playback
                        self.player?.seek(to: CMTime.zero)
                        self.player?.play()
                    }
                    
                    self.isLoading = false
                    self.player?.play()
                    self.isPlaying = true
                } else {
                    // Not a valid video - try treating as GIF
                    if videoURL.pathExtension.lowercased() == "gif" || 
                       videoURL.absoluteString.contains("gif") {
                        self.isGIF = true
                        self.isLoading = false
                    } else {
                        // Not a valid video or GIF
                        self.loadError = error ?? NSError(
                            domain: "VideoPlayerView",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Unable to load media"]
                        )
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

// WebView wrapper for displaying GIFs
struct GIFWebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.contentMode = .scaleAspectFit
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                    .frame(height: 120)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            } else if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .cornerRadius(10)
                    .clipped()
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    )
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .cornerRadius(10)
                        .frame(height: 120)
                    
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Thumbnail unavailable")
                            .font(.caption)
                    }
                }
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    func generateThumbnail() {
        isLoading = true
        
        // Handle GIFs differently
        if url.pathExtension.lowercased() == "gif" {
            // For GIFs, try to load directly as an image
            DispatchQueue.global().async {
                do {
                    let imageData = try Data(contentsOf: url)
                    if let image = UIImage(data: imageData) {
                        DispatchQueue.main.async {
                            self.thumbnail = image
                            self.isLoading = false
                        }
                    } else {
                        createPlaceholder()
                    }
                } catch {
                    createPlaceholder()
                }
            }
            return
        }
        
        // For videos, use AVAsset
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Request a less exact time to speed up thumbnail generation
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 60)
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 60)
        
        // Get thumbnail at 1 second
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        // Use the async API
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
            if let cgImage = cgImage, result == .succeeded {
                DispatchQueue.main.async {
                    self.thumbnail = UIImage(cgImage: cgImage)
                    self.isLoading = false
                }
            } else {
                createPlaceholder()
            }
        }
    }
    
    private func createPlaceholder() {
        DispatchQueue.main.async {
            self.thumbnail = createPlaceholderImage()
            self.isLoading = false
        }
    }
    
    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 320, height: 180)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Fill background
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw play icon
            let iconRect = CGRect(x: size.width/2 - 30, y: size.height/2 - 30, width: 60, height: 60)
            UIColor.white.setFill()
            
            // Create a triangle path for play icon
            let path = UIBezierPath()
            path.move(to: CGPoint(x: iconRect.minX + 15, y: iconRect.minY))
            path.addLine(to: CGPoint(x: iconRect.maxX, y: iconRect.midY))
            path.addLine(to: CGPoint(x: iconRect.minX + 15, y: iconRect.maxY))
            path.close()
            path.fill()
        }
    }
}