import SwiftUI

struct PromptInputView: View {
    @Binding var prompt: String
    @Binding var selectedModel: ModelType
    @Binding var selectedResolution: VideoResolution
    @Binding var usePromptExtension: Bool
    @Binding var selectedImage: UIImage?
    
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var imageSource: ImageSource?
    
    enum ImageSource {
        case library, camera
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Type")
                    .font(.headline)
                
                Picker("Select Model", selection: $selectedModel) {
                    ForEach(ModelType.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.headline)
                
                Picker("Select Resolution", selection: $selectedResolution) {
                    ForEach(selectedModel.supportedResolutions, id: \.self) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedModel) { newModel in
                    if !newModel.supportedResolutions.contains(selectedResolution) {
                        selectedResolution = newModel.supportedResolutions.first ?? .r480p
                    }
                }
            }
            
            if selectedModel.requiresImage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Image")
                        .font(.headline)
                    
                    if let image = selectedImage {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                            
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        selectedImage = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                            .padding(8)
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                    } else {
                        HStack(spacing: 20) {
                            Button(action: {
                                imageSource = .library
                                showImagePicker = true
                            }) {
                                VStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 30))
                                    Text("Gallery")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                imageSource = .camera
                                showCameraPicker = true
                            }) {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 30))
                                    Text("Camera")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePickerView(selectedImage: $selectedImage)
                }
                .sheet(isPresented: $showCameraPicker) {
                    CameraPickerView(selectedImage: $selectedImage)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What would you like to generate?")
                    .font(.headline)
                
                TextEditor(text: $prompt)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(8)
            }
            
            Toggle("Use Prompt Extension (Recommended)", isOn: $usePromptExtension)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding()
    }
}