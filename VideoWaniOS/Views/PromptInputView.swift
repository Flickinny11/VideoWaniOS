import SwiftUI

struct PromptInputView: View {
    @Binding var prompt: String
    @Binding var selectedModel: ModelType
    @Binding var selectedResolution: VideoResolution
    @Binding var usePromptExtension: Bool
    @Binding var selectedImage: UIImage?
    
    @State private var showImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showSourceOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create New Video")
                .font(.headline)
                .padding(.top, 8)
            
            // Model selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Type")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Model", selection: $selectedModel) {
                    ForEach(ModelType.allCases, id: \.self) { model in
                        Text(model.displayName)
                            .tag(model)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Resolution selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Resolution", selection: $selectedResolution) {
                    // Only show resolutions supported by the selected model
                    ForEach(selectedModel.supportedResolutions, id: \.self) { resolution in
                        Text(resolution.rawValue)
                            .tag(resolution)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedModel) { newModel in
                    // Make sure to pick a supported resolution when model changes
                    if !newModel.supportedResolutions.contains(selectedResolution) {
                        selectedResolution = newModel.supportedResolutions.first ?? .r480p
                    }
                }
            }
            
            // Image picker (only for Image-to-Video models)
            if selectedModel.requiresImage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Image")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let image = selectedImage {
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 90)
                                .clipped()
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading) {
                                Text("Image Selected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                
                                Button(action: {
                                    showSourceOptions = true
                                }) {
                                    Text("Change Image")
                                        .font(.caption)
                                }
                                
                                Button(action: {
                                    selectedImage = nil
                                }) {
                                    Text("Remove")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    } else {
                        Button(action: {
                            showSourceOptions = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Select Image")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                }
                .actionSheet(isPresented: $showSourceOptions) {
                    ActionSheet(
                        title: Text("Select Image Source"),
                        buttons: [
                            .default(Text("Photo Library")) {
                                self.imageSource = .photoLibrary
                                self.showImagePicker = true
                            },
                            .default(Text("Camera")) {
                                self.imageSource = .camera
                                self.showImagePicker = true
                            },
                            .cancel()
                        ]
                    )
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(selectedImage: $selectedImage, sourceType: imageSource)
                }
            }
            
            // Prompt input
            VStack(alignment: .leading, spacing: 8) {
                Text("Video Prompt")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $prompt)
                    .frame(minHeight: 100)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                // Placeholder
                if prompt.isEmpty {
                    Text("Describe the video you want to create...")
                        .foregroundColor(.gray)
                        .padding(.leading, 12)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
                
                // Prompt extension option
                Toggle("Enhance prompt with AI", isOn: $usePromptExtension)
                    .font(.subheadline)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}

// Helper for image picking
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}