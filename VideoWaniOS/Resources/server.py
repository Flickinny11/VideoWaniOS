"""
Wan Video embedded server for iOS.

This script would normally be a Python server that communicates with the Wan Video
models. In the iOS app, this script is bundled but not actually executed since iOS
apps cannot spawn arbitrary Python processes. Instead, a mock server is implemented
in MockServerURLProtocol.swift to simulate the API functionality.
"""

import os
import json
import time
import uuid
import base64
import io
import re
import tempfile
from PIL import Image, ImageDraw
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Constants
UPLOADS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output')
REQUEST_DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'request_data')

# In-memory request tracking
requests_status = {}

def clean_prompt(prompt):
    """
    Sanitize and optimize the prompt to prevent issues
    """
    if not prompt:
        return "Empty prompt"
    
    # Remove excessive whitespace
    cleaned = re.sub(r'\s+', ' ', prompt.strip())
    
    # Fix common misspellings (could be extended)
    spelling_fixes = {
        'vidio': 'video',
        'camra': 'camera',
        'fotage': 'footage',
        'cinamatic': 'cinematic',
    }
    
    for misspelled, correct in spelling_fixes.items():
        cleaned = re.sub(r'\b' + misspelled + r'\b', correct, cleaned, flags=re.IGNORECASE)
    
    # Ensure prompt ends with a period or other sentence-ending punctuation
    if not cleaned[-1] in '.!?':
        cleaned += '.'
    
    return cleaned

def create_test_video(request_id, prompt):
    """
    Create a sequence of images to simulate a video
    """
    # Generate a mock MP4 file in memory
    width, height = 640, 360
    frames = []
    frames_count = 16  # 1 second at 16fps
    
    # Create a video title from the prompt (truncate if too long)
    title = prompt[:50] + "..." if len(prompt) > 50 else prompt
    
    # Generate frames
    for i in range(frames_count):
        img = Image.new('RGB', (width, height), color=(0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Draw a moving rectangle (simple animation)
        progress = i / (frames_count - 1)  # 0.0 to 1.0
        x_pos = int(progress * (width - 100))
        y_pos = height // 2 - 50
        
        # Draw background
        draw.rectangle([(0, 0), (width, height)], fill=(20, 20, 40))
        
        # Draw moving element
        draw.rectangle([(x_pos, y_pos), (x_pos + 100, y_pos + 100)], 
                    fill=(50, 100, 200), outline=(255, 255, 255))
        
        # Add frame information
        draw.text((10, 10), f"Frame {i+1}/{frames_count}", fill=(255, 255, 255))
        draw.text((10, 30), f"Request ID: {request_id[:8]}", fill=(255, 255, 255))
        
        # Add prompt at the bottom
        draw.text((10, height - 30), title, fill=(255, 255, 255))
        
        # Add timestamp
        draw.text((width - 100, 10), time.strftime("%H:%M:%S"), fill=(255, 255, 255))
        
        frames.append(img)
    
    # Create animated GIF (as a fallback since we can't create MP4 without ffmpeg)
    output_path = os.path.join(OUTPUT_DIR, f"{request_id}.gif")
    frames[0].save(
        output_path,
        format='GIF',
        append_images=frames[1:],
        save_all=True,
        duration=1000//16,  # 16fps
        loop=0  # Loop forever
    )
    
    # Also save a JPEG for apps that can't handle GIFs well
    jpeg_path = os.path.join(OUTPUT_DIR, f"{request_id}.jpg")
    frames[-1].save(jpeg_path, format='JPEG')
    
    return output_path

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok'})

@app.route('/api/extend-prompt', methods=['POST'])
def extend_prompt():
    data = request.json
    if not data or 'prompt' not in data:
        return jsonify({'error': 'Missing prompt parameter'}), 400
    
    original_prompt = data['prompt']
    
    # Clean and optimize the prompt
    cleaned_prompt = clean_prompt(original_prompt)
    
    # Simple prompt extension for testing
    extended_prompt = f"{cleaned_prompt} High-quality detail, natural motion, cinematic lighting, realistic textures, smooth transitions, professional composition, with realistic environment."
    
    return jsonify({
        'originalPrompt': original_prompt,
        'extendedPrompt': extended_prompt
    })

@app.route('/api/generate', methods=['POST'])
def generate_video():
    data = request.json
    if not data or 'prompt' not in data or 'task' not in data or 'size' not in data:
        return jsonify({'error': 'Missing required parameters'}), 400
    
    # Clean and optimize the prompt
    original_prompt = data['prompt']
    cleaned_prompt = clean_prompt(original_prompt)
    
    # Extract parameters
    task = data['task']
    size = data['size']
    image_base64 = data.get('image')
    
    # Generate a unique request ID
    request_id = str(uuid.uuid4())
    
    # Store initial request information
    requests_status[request_id] = {
        'requestId': request_id,
        'status': 'processing',
        'progress': 0.0,
        'task': task,
        'prompt': cleaned_prompt,  # Store cleaned prompt
        'timestamp': time.time()
    }
    
    # Save image if provided
    if image_base64 and ('i2v' in task):
        try:
            # Decode base64 image
            image_data = base64.b64decode(image_base64)
            image = Image.open(io.BytesIO(image_data))
            
            # Save the image
            image_path = os.path.join(UPLOADS_DIR, f"{request_id}.jpg")
            image.save(image_path)
            requests_status[request_id]['imagePath'] = image_path
        except Exception as e:
            print(f"Error processing image: {str(e)}")
            return jsonify({'error': f"Image processing error: {str(e)}"}), 400
    
    return jsonify({
        'requestId': request_id,
        'status': 'accepted'
    })

@app.route('/api/status/<request_id>', methods=['GET'])
def check_status(request_id):
    if request_id not in requests_status:
        return jsonify({'error': 'Request not found'}), 404
    
    # For testing: increment progress on each status check
    current_progress = requests_status[request_id]['progress']
    if current_progress < 1.0:
        requests_status[request_id]['progress'] = min(current_progress + 0.1, 1.0)
    
    # Mark as completed when progress reaches 100%
    if requests_status[request_id]['progress'] >= 1.0 and requests_status[request_id]['status'] != 'completed':
        requests_status[request_id]['status'] = 'completed'
        requests_status[request_id]['videoUrl'] = f"/api/video/{request_id}"
        
        # Create the simulated video
        create_test_video(request_id, requests_status[request_id]['prompt'])
    
    return jsonify(requests_status[request_id])

@app.route('/api/video/<request_id>', methods=['GET'])
def get_video(request_id):
    # First check if we have a GIF we created
    gif_path = os.path.join(OUTPUT_DIR, f"{request_id}.gif")
    jpeg_path = os.path.join(OUTPUT_DIR, f"{request_id}.jpg")
    
    # If GIF file exists, return it
    if os.path.exists(gif_path):
        return send_file(gif_path, mimetype='image/gif', as_attachment=False)
    
    # If JPEG exists, return it as a fallback
    if os.path.exists(jpeg_path):
        return send_file(jpeg_path, mimetype='image/jpeg', as_attachment=False)
    
    # If neither exists, create a new video
    output_path = create_test_video(request_id, "Generated video")
    
    return send_file(output_path, mimetype='image/gif', as_attachment=False)

if __name__ == '__main__':
    # Ensure directories exist
    for dir_path in [UPLOADS_DIR, OUTPUT_DIR, REQUEST_DATA_DIR]:
        os.makedirs(dir_path, exist_ok=True)
    
    # In production, use waitress
    from waitress import serve
    port = int(os.environ.get('PORT', 7860))
    print(f"Starting test server on port {port}")
    serve(app, host='0.0.0.0', port=port)