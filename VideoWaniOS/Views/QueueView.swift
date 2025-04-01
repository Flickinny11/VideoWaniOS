import SwiftUI

struct QueueView: View {
    @EnvironmentObject var viewModel: GenerationViewModel
    @State private var selectedVideo: VideoRequest?
    @State private var showingVideoSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Video Queue")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            Divider()
            
            if viewModel.videoRequests.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "film")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding()
                    Text("No videos in queue")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.videoRequests.sorted(by: { $0.createdAt > $1.createdAt })) { request in
                        VideoRequestCell(request: request)
                            .onTapGesture {
                                if request.status == .completed, let _ = request.resultVideoURL {
                                    selectedVideo = request
                                    showingVideoSheet = true
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteRequest(request)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingVideoSheet) {
            if let request = selectedVideo, let url = request.resultVideoURL {
                VideoDetailView(request: request, videoURL: url)
            }
        }
    }
}

struct VideoRequestCell: View {
    let request: VideoRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(request.modelType.displayName)
                        .font(.headline)
                    
                    Text(request.prompt)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                
                Spacer()
                
                statusView
            }
            
            if request.status == .processing {
                CustomProgressView(progress: request.progress, color: .blue)
                    .frame(height: 10)
                    .padding(.vertical, 5)
                
                Text("\(Int(request.progress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if request.status == .completed, let url = request.resultVideoURL {
                VideoThumbnailView(url: url)
            }
        }
        .padding(.vertical, 8)
    }
    
    var statusView: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            Text(request.status.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    var statusColor: Color {
        switch request.status {
        case .pending:
            return .orange
        case .processing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

struct VideoDetailView: View {
    let request: VideoRequest
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: GenerationViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .cornerRadius(12)
                    .aspectRatio(16/9, contentMode: .fit)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Model:")
                            .fontWeight(.bold)
                        Text(request.modelType.displayName)
                        Spacer()
                        Text("Resolution:")
                            .fontWeight(.bold)
                        Text(request.resolution.rawValue)
                    }
                    .font(.subheadline)
                    
                    Text("Prompt:")
                        .fontWeight(.bold)
                        .font(.subheadline)
                    
                    Text(request.prompt)
                        .font(.body)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal)
                
                Button(action: {
                    viewModel.downloadVideo(from: request)
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Download Video")
                    }
                    .frame(minWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Video Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}