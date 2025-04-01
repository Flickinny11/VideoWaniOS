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
}