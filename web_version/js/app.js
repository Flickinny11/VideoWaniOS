document.addEventListener('DOMContentLoaded', function() {
    // Elements
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');
    const modelOptions = document.querySelectorAll('[data-model]');
    const resolutionOptions = document.querySelectorAll('[data-resolution]');
    const imageSection = document.getElementById('image-upload-section');
    const imageInput = document.getElementById('image-input');
    const imagePreview = document.getElementById('image-preview');
    const promptInput = document.getElementById('prompt-input');
    const promptExtension = document.getElementById('prompt-extension');
    const generateBtn = document.getElementById('generate-btn');
    const loadingOverlay = document.getElementById('loading-overlay');
    const progressElement = document.getElementById('progress');
    const videoList = document.querySelector('.video-list');
    const noVideosMsg = document.getElementById('no-videos-msg');
    
    // State
    let selectedModel = 't2v14B';
    let selectedResolution = '480p';
    let selectedImage = null;
    let videoRequests = JSON.parse(localStorage.getItem('videoRequests')) || [];
    
    // Initialize
    updateUI();
    renderVideoList();
    
    // Tab switching
    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const tabName = btn.getAttribute('data-tab');
            
            // Update tab buttons
            tabBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            
            // Update tab content
            tabContents.forEach(content => {
                content.classList.remove('active');
                if (content.id === `${tabName}-tab`) {
                    content.classList.add('active');
                }
            });
        });
    });
    
    // Model selection
    modelOptions.forEach(option => {
        option.addEventListener('click', () => {
            selectedModel = option.getAttribute('data-model');
            modelOptions.forEach(opt => opt.classList.remove('active'));
            option.classList.add('active');
            
            // Show/hide image upload based on model
            updateUI();
        });
    });
    
    // Resolution selection
    resolutionOptions.forEach(option => {
        option.addEventListener('click', () => {
            selectedResolution = option.getAttribute('data-resolution');
            resolutionOptions.forEach(opt => opt.classList.remove('active'));
            option.classList.add('active');
        });
    });
    
    // Image upload
    imageInput.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = (e) => {
                selectedImage = e.target.result;
                imagePreview.style.backgroundImage = `url(${selectedImage})`;
                imagePreview.innerHTML = '';
            };
            reader.readAsDataURL(file);
        }
    });
    
    // Generate button
    generateBtn.addEventListener('click', () => {
        if (!validateInput()) return;
        
        const prompt = promptInput.value.trim();
        const usePromptExtension = promptExtension.checked;
        
        // Show loading overlay
        loadingOverlay.style.display = 'flex';
        
        // Generate a unique ID for this request
        const requestId = 'req_' + Math.random().toString(36).substr(2, 9);
        
        // Create a new request object
        const request = {
            id: requestId,
            prompt: prompt,
            modelType: selectedModel,
            resolution: selectedResolution,
            image: selectedImage,
            status: 'processing',
            progress: 0,
            createdAt: new Date().toISOString(),
            resultVideoURL: null
        };
        
        // Add to requests array
        videoRequests.push(request);
        saveRequests();
        
        // Simulate video generation
        simulateVideoGeneration(requestId, prompt);
    });
    
    function updateUI() {
        // Show/hide image upload based on selected model
        if (selectedModel.startsWith('i2v')) {
            imageSection.style.display = 'block';
        } else {
            imageSection.style.display = 'none';
            selectedImage = null;
            imagePreview.style.backgroundImage = '';
            imagePreview.innerHTML = '<p>Select an image</p>';
        }
        
        // Enable/disable resolution options based on selected model
        if (selectedModel === 't2v1_3B' || selectedModel === 'i2v14B480P') {
            // Only 480p is available
            resolutionOptions.forEach(opt => {
                if (opt.getAttribute('data-resolution') === '480p') {
                    opt.classList.add('active');
                    opt.disabled = false;
                } else {
                    opt.classList.remove('active');
                    opt.disabled = true;
                }
            });
            selectedResolution = '480p';
        } else if (selectedModel === 'i2v14B720P') {
            // Only 720p is available
            resolutionOptions.forEach(opt => {
                if (opt.getAttribute('data-resolution') === '720p') {
                    opt.classList.add('active');
                    opt.disabled = false;
                } else {
                    opt.classList.remove('active');
                    opt.disabled = true;
                }
            });
            selectedResolution = '720p';
        } else {
            // Both resolutions are available
            resolutionOptions.forEach(opt => {
                opt.disabled = false;
            });
        }
    }
    
    function validateInput() {
        if (!promptInput.value.trim()) {
            alert('Please enter a prompt');
            return false;
        }
        
        if (selectedModel.startsWith('i2v') && !selectedImage) {
            alert('Please select an image for Image-to-Video generation');
            return false;
        }
        
        return true;
    }
    
    function simulateVideoGeneration(requestId, prompt) {
        let progress = 0;
        const interval = setInterval(() => {
            progress += 0.1;
            progressElement.textContent = `${Math.round(progress * 100)}%`;
            
            // Update request progress
            const requestIndex = videoRequests.findIndex(r => r.id === requestId);
            if (requestIndex !== -1) {
                videoRequests[requestIndex].progress = progress;
                saveRequests();
            }
            
            if (progress >= 1) {
                clearInterval(interval);
                finishVideoGeneration(requestId, prompt);
            }
        }, 500);
    }
    
    function finishVideoGeneration(requestId, prompt) {
        // Generate a simple animated GIF
        const frameCount = 10;
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = selectedResolution === '480p' ? 640 : 1280;
        canvas.height = selectedResolution === '480p' ? 360 : 720;
        
        // Create frames for animation
        const frames = [];
        for (let i = 0; i < frameCount; i++) {
            ctx.fillStyle = '#101020';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            const progress = i / (frameCount - 1);
            const xPos = progress * (canvas.width - 100);
            const yPos = canvas.height / 2 - 50;
            
            ctx.fillStyle = '#2040c0';
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.rect(xPos, yPos, 100, 100);
            ctx.fill();
            ctx.stroke();
            
            ctx.fillStyle = '#ffffff';
            ctx.font = '14px Arial';
            ctx.fillText(`Frame ${i+1}/${frameCount}`, 10, 20);
            ctx.fillText(prompt.substring(0, 40) + (prompt.length > 40 ? '...' : ''), 10, canvas.height - 20);
            
            frames.push(canvas.toDataURL('image/jpeg', 0.8));
        }
        
        // Update request
        const requestIndex = videoRequests.findIndex(r => r.id === requestId);
        if (requestIndex !== -1) {
            videoRequests[requestIndex].status = 'completed';
            videoRequests[requestIndex].progress = 1;
            videoRequests[requestIndex].resultVideoURL = frames;
            saveRequests();
        }
        
        // Hide loading overlay
        loadingOverlay.style.display = 'none';
        
        // Clear form
        promptInput.value = '';
        selectedImage = null;
        imagePreview.style.backgroundImage = '';
        imagePreview.innerHTML = '<p>Select an image</p>';
        
        // Render video list
        renderVideoList();
        
        // Switch to videos tab
        document.querySelector('[data-tab="videos"]').click();
    }
    
    function renderVideoList() {
        if (videoRequests.length === 0) {
            noVideosMsg.style.display = 'block';
            videoList.innerHTML = '';
            return;
        }
        
        noVideosMsg.style.display = 'none';
        videoList.innerHTML = '';
        
        // Sort by creation date (newest first)
        const sortedRequests = [...videoRequests].sort((a, b) => {
            return new Date(b.createdAt) - new Date(a.createdAt);
        });
        
        sortedRequests.forEach(request => {
            const videoCard = document.createElement('div');
            videoCard.className = 'video-card';
            
            if (request.status === 'completed' && request.resultVideoURL) {
                // Get the last frame for thumbnail
                const thumbnailUrl = Array.isArray(request.resultVideoURL) ? 
                                    request.resultVideoURL[request.resultVideoURL.length - 1] : 
                                    request.resultVideoURL;
                
                videoCard.innerHTML = `
                    <div class="video-thumbnail" style="background-image: url(${thumbnailUrl})">
                        <div class="play-icon"></div>
                    </div>
                    <div class="video-info">
                        <h3>${getModelDisplayName(request.modelType)}</h3>
                        <p>${request.prompt}</p>
                    </div>
                `;
                
                videoCard.addEventListener('click', () => {
                    openVideoViewer(request);
                });
            } else {
                videoCard.innerHTML = `
                    <div class="video-thumbnail" style="background-color: #f0f0f0">
                        <div style="position: absolute; top: 0; left: 0; width: ${request.progress * 100}%; height: 5px; background-color: #0066cc;"></div>
                    </div>
                    <div class="video-info">
                        <h3>${getModelDisplayName(request.modelType)}</h3>
                        <p>${request.prompt}</p>
                        <p style="color: ${getStatusColor(request.status)};">${request.status} - ${Math.round(request.progress * 100)}%</p>
                    </div>
                `;
            }
            
            videoList.appendChild(videoCard);
        });
    }
    
    function openVideoViewer(request) {
        // Create modal for viewing the video/animation
        const modal = document.createElement('div');
        modal.style.position = 'fixed';
        modal.style.top = '0';
        modal.style.left = '0';
        modal.style.width = '100%';
        modal.style.height = '100%';
        modal.style.backgroundColor = 'rgba(0,0,0,0.8)';
        modal.style.display = 'flex';
        modal.style.justifyContent = 'center';
        modal.style.alignItems = 'center';
        modal.style.zIndex = '1000';
        
        // Close button
        const closeBtn = document.createElement('button');
        closeBtn.textContent = '×';
        closeBtn.style.position = 'absolute';
        closeBtn.style.top = '20px';
        closeBtn.style.right = '20px';
        closeBtn.style.backgroundColor = 'transparent';
        closeBtn.style.border = 'none';
        closeBtn.style.color = 'white';
        closeBtn.style.fontSize = '30px';
        closeBtn.style.cursor = 'pointer';
        closeBtn.addEventListener('click', () => {
            document.body.removeChild(modal);
        });
        
        modal.appendChild(closeBtn);
        
        // If it's an array of frames, create an animation
        if (Array.isArray(request.resultVideoURL)) {
            const container = document.createElement('div');
            container.style.maxWidth = '90%';
            container.style.maxHeight = '90%';
            container.style.position = 'relative';
            
            const img = document.createElement('img');
            img.style.maxWidth = '100%';
            img.style.maxHeight = '100%';
            img.style.display = 'block';
            img.style.borderRadius = '10px';
            
            container.appendChild(img);
            modal.appendChild(container);
            
            // Animate through frames
            let currentFrame = 0;
            const frameRate = 100; // ms per frame
            
            function updateFrame() {
                img.src = request.resultVideoURL[currentFrame];
                currentFrame = (currentFrame + 1) % request.resultVideoURL.length;
            }
            
            updateFrame(); // Show first frame
            const animInterval = setInterval(updateFrame, frameRate);
            
            // Clean up interval when modal is closed
            closeBtn.addEventListener('click', () => {
                clearInterval(animInterval);
            });
        } else {
            // Single image/URL
            const img = document.createElement('img');
            img.src = request.resultVideoURL;
            img.style.maxWidth = '90%';
            img.style.maxHeight = '90%';
            img.style.borderRadius = '10px';
            modal.appendChild(img);
        }
        
        document.body.appendChild(modal);
    }
    
    function getModelDisplayName(modelType) {
        switch (modelType) {
            case 't2v14B': return 'Text-to-Video 14B';
            case 't2v1_3B': return 'Text-to-Video 1.3B';
            case 'i2v14B480P': return 'Image-to-Video 14B (480p)';
            case 'i2v14B720P': return 'Image-to-Video 14B (720p)';
            default: return modelType;
        }
    }
    
    function getStatusColor(status) {
        switch (status) {
            case 'pending': return '#f5a623';
            case 'processing': return '#0066cc';
            case 'completed': return '#34c759';
            case 'failed': return '#ff3b30';
            default: return '#6e6e73';
        }
    }
    
    function saveRequests() {
        localStorage.setItem('videoRequests', JSON.stringify(videoRequests));
    }
});
