# VideoWaniOS: Self-Contained iOS App for Wan Video

VideoWaniOS is a fully self-contained iOS application for creating videos from text prompts or images. It simulates a Wan Video backend directly on your iPad, eliminating the need for server setup.

## No Xcode? No Problem!

Since you don't have access to the App Store to download Xcode, we've provided several different ways for you to get this app on your iPad:

1. **Read SIMPLE_TRANSFER.md**: For the easiest options using third-party tools like Sideloadly or AltStore
2. **Read DOCKER_BUILD.md**: For using Docker on Google Cloud to build the app
3. **Use GitHub Actions**: Push this code to GitHub to automatically build using the included workflow file

## Features

- **Self-contained operation**: No external server required
- **Text-to-Video**: Generate MP4 videos from text prompts
- **Image-to-Video**: Transform static images into animated videos
- **Multiple models**: Choose from different model sizes and capabilities
- **Prompt enhancement**: Automatic optimization of text prompts
- **Resolution options**: Generate videos in 480p or 720p
- **Progress tracking**: Monitor video generation progress in real-time
- **Video library**: Manage and replay all your generated videos

## MP4 Video Generation

This app now generates true MP4 video files rather than animated GIFs. The video generation process:

1. Creates a sequence of high-quality image frames
2. Applies smooth transitions and animations based on your prompt
3. Encodes the frames into an MP4 video file with H.264 codec
4. Adds a silent audio track for compatibility
5. Stores the video in the app's documents directory
6. Makes the video available for sharing and downloading

## Usage

1. **Launch the app**: The app will automatically start its embedded server
2. **Create a video**:
   - Select a model type (Text-to-Video or Image-to-Video)
   - Choose a resolution (480p or 720p)
   - If using Image-to-Video, select an image from your photo library or camera
   - Enter a descriptive prompt for the video you want to generate
   - Click the "Generate Video" button
3. **Monitor progress**: Go to the Videos tab to see generation progress
4. **View and share**: Tap on a completed video to view, download, or share it

## Technical Details

VideoWaniOS uses a unique approach to simulate server operations directly on iOS:

- **Custom URL Protocol**: Intercepts requests to "localhost" and handles them internally
- **Mock Server Implementation**: Simulates the Wan Video API endpoints
- **MP4 Generation**: Uses AVFoundation to create real MP4 videos on-device
- **Reactive Programming**: Uses Combine for asynchronous operations and data flow

## Requirements

- iOS 15.0 or later
- iPad with A12 Bionic chip or newer (for optimal performance)
- At least 1GB of free storage space

## Privacy

All operations occur locally on your device. The app does not send any data to external servers. Camera and photo library access is only used to select source images for video generation.

## Troubleshooting

- **App won't install**: Make sure your iPad is trusted on your Mac and that your Apple ID is allowed to install apps
- **App crashes on launch**: Try restarting your iPad
- **Can't generate videos**: Check that you've granted camera and photo permissions when prompted
- **Videos not showing**: The app needs storage permissions to save generated videos