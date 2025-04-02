import Foundation
import UIKit
import AVFoundation

class VideoGenerator {
    // Generate MP4 video from a sequence of images
    static func generateMP4FromImages(_ images: [UIImage], frameRate: Float = 30, outputURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        // Set up video writer
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: images.first?.size.width ?? 640,
            AVVideoHeightKey: images.first?.size.height ?? 360,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]
        
        // Create asset writer
        var assetWriter: AVAssetWriter
        do {
            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            completion(false, error)
            return
        }
        
        // Create writer inputs
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false
        
        let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioWriterInput.expectsMediaDataInRealTime = false
        
        // Create pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: images.first?.size.width ?? 640,
            kCVPixelBufferHeightKey as String: images.first?.size.height ?? 360
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        // Add inputs to writer
        if assetWriter.canAdd(videoWriterInput) {
            assetWriter.add(videoWriterInput)
        } else {
            completion(false, NSError(domain: "VideoGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"]))
            return
        }
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        }
        
        // Start writing
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
        
        // Create a dispatch group to wait for all frames to be written
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        // Process frames in a background queue
        let processingQueue = DispatchQueue(label: "com.videowanios.videoprocessing")
        
        // Add video frames
        videoWriterInput.requestMediaDataWhenReady(on: processingQueue) {
            var frameCount: Int64 = 0
            let frameDuration = CMTimeMake(value: 1, timescale: CMTimeScale(frameRate))
            var presentationTime = CMTime.zero
            
            // Function to create a pixel buffer from UIImage
            func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
                let width = Int(image.size.width)
                let height = Int(image.size.height)
                
                var pixelBuffer: CVPixelBuffer?
                let status = CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    width,
                    height,
                    kCVPixelFormatType_32ARGB,
                    nil,
                    &pixelBuffer
                )
                
                guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                    return nil
                }
                
                CVPixelBufferLockBaseAddress(buffer, [])
                
                let pixelData = CVPixelBufferGetBaseAddress(buffer)
                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                
                let context = CGContext(
                    data: pixelData,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                    space: rgbColorSpace,
                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                )
                
                context?.translateBy(x: 0, y: CGFloat(height))
                context?.scaleBy(x: 1, y: -1)
                
                UIGraphicsPushContext(context!)
                image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
                UIGraphicsPopContext()
                
                CVPixelBufferUnlockBaseAddress(buffer, [])
                
                return buffer
            }
            
            // Process each image
            for image in images {
                while !videoWriterInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                if let buffer = pixelBuffer(from: image) {
                    let success = pixelBufferAdaptor.append(buffer, withPresentationTime: presentationTime)
                    if !success {
                        print("Error appending pixel buffer at time \(presentationTime)")
                    }
                    
                    presentationTime = CMTimeAdd(presentationTime, frameDuration)
                    frameCount += 1
                }
            }
            
            // Add extra still frames at the end to make the video longer
            let lastImage = images.last!
            let extraFrames = Int64(frameRate * 3) // 3 seconds of extra frames
            
            if let lastBuffer = pixelBuffer(from: lastImage) {
                for _ in 0..<extraFrames {
                    while !videoWriterInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    
                    let success = pixelBufferAdaptor.append(lastBuffer, withPresentationTime: presentationTime)
                    if !success {
                        print("Error appending last frame at time \(presentationTime)")
                    }
                    
                    presentationTime = CMTimeAdd(presentationTime, frameDuration)
                    frameCount += 1
                }
            }
            
            // Finish writing
            videoWriterInput.markAsFinished()
            
            // Generate a simple silent audio track
            if audioWriterInput.isReadyForMoreMediaData {
                // Create silent audio
                let audioBuffer = generateSilentAudioBuffer(duration: Double(frameCount) / Double(frameRate))
                audioWriterInput.append(audioBuffer)
                audioWriterInput.markAsFinished()
            }
            
            assetWriter.finishWriting {
                dispatchGroup.leave()
            }
        }
        
        // Wait for video processing to complete
        dispatchGroup.notify(queue: .main) {
            completion(assetWriter.status == .completed, assetWriter.error)
        }
    }
    
    // Generate a silent audio buffer
    private static func generateSilentAudioBuffer(duration: Double) -> CMSampleBuffer {
        // Create a silent audio buffer with the specified duration
        // This is a simplified implementation - in a real app you would create proper audio samples
        
        let audioBufferSize = Int(44100 * duration) * 2 * 2 // 44.1kHz, 2 channels, 2 bytes per sample
        var audioData = Data(count: audioBufferSize)
        
        // Create format description
        var formatDescription: CMAudioFormatDescription?
        var asbd = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        // Create timing info
        let sampleRate = 44100.0
        let sampleCount = Int64(duration * sampleRate)
        let presentationTimeStamp = CMTime(value: 0, timescale: CMTimeScale(sampleRate))
        let duration = CMTime(value: sampleCount, timescale: CMTimeScale(sampleRate))
        
        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        
        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        
        audioData.withUnsafeMutableBytes { bufferPtr in
            let baseAddress = bufferPtr.baseAddress
            
            var blockBuffer: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: baseAddress,
                blockLength: audioData.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: audioData.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            
            CMSampleBufferCreate(
                allocator: kCFAllocatorDefault,
                dataBuffer: blockBuffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: formatDescription,
                sampleCount: 1,
                sampleTimingEntryCount: 1,
                sampleTimingArray: &timing,
                sampleSizeEntryCount: 0,
                sampleSizeArray: nil,
                sampleBufferOut: &sampleBuffer
            )
        }
        
        return sampleBuffer!
    }
    
    // Function to generate a mock video file
    static func generateMockVideo(requestId: String, completion: @escaping (URL?) -> Void) {
        // Create a directory for videos if it doesn't exist
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoDir = docDir.appendingPathComponent("videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: videoDir, withIntermediateDirectories: true)
        
        // Create a file URL for our MP4
        let fileURL = videoDir.appendingPathComponent("\(requestId).mp4")
        
        // Create a sequence of images for the video
        let width = 640
        let height = 360
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
            
            // Draw an animated element
            let progress = CGFloat(i) / CGFloat(frameCount - 1)
            let xPos = Int(progress * CGFloat(width - 150))
            let yPos = Int(CGFloat(height) / 2 - 75)
            
            // Draw a blue rectangle that moves across the screen
            context.setFillColor(UIColor.blue.cgColor)
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2)
            context.addRect(CGRect(x: xPos, y: yPos, width: 150, height: 150))
            context.drawPath(using: .fillStroke)
            
            // Add text
            let text = "Frame \(i+1)/\(frameCount)"
            let textAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 14)
            ]
            (text as NSString).draw(at: CGPoint(x: 10, y: 20), withAttributes: textAttributes)
            
            // Add RequestID
            let requestText = "ID: \(requestId.prefix(8))"
            (requestText as NSString).draw(at: CGPoint(x: 10, y: height - 30), withAttributes: textAttributes)
            
            // Capture the image
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let image = image {
                images.append(image)
            }
        }
        
        // Generate the MP4 video
        generateMP4FromImages(images, frameRate: 30, outputURL: fileURL) { success, error in
            if success {
                completion(fileURL)
            } else {
                print("Error generating video: \(error?.localizedDescription ?? "unknown error")")
                completion(nil)
            }
        }
    }
}