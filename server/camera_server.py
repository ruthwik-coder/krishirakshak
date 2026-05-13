import cv2
import torch
import numpy as np
from ultralytics import YOLO
import psycopg2
import subprocess
import time
import threading
import io
import base64
from datetime import datetime
from flask import Flask, Response, request
from pydub import AudioSegment
from pydub.playback import play
import struct
import wave

SUPABASE_URL = "https://cnbrwbibvlbzzztenfzr.supabase.co"
SUPABASE_PUBLIC = "https://cnbrwbibvlbzzztenfzr.supabase.co/storage/v1/object/public"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzY2NDQsImV4cCI6MjA4ODIxMjY0NH0.quKfAnBY8FDxPkvuQbtz3PTVjC77VNvAYMaKUkLJ7Uo"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"

DEVICE_CODE = "LAPTOP001"
DEVICE_PASSWORD = "krishi2024"

MODEL_PATH = "best.pt"

CAMERA_INDEX = 0
CONFIDENCE_THRESHOLD = 0.6
ALERT_COOLDOWN = 10

SIREN_URL = f"{SUPABASE_PUBLIC}/assets/siren.mp3"

PREDATOR_SOUNDS = {
    "goat": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "buffalo": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "elephant": f"{SUPABASE_PUBLIC}/assets/sounds/elephant/Bee_1.mp3",
    "zebra": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "bird": f"{SUPABASE_PUBLIC}/assets/sounds/elephant/Bee_1.mp3",
    "pig": f"{SUPABASE_PUBLIC}/assets/sounds/pig/dog_1.wav",
    "leopard": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "cheetah": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "bear": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "bull": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "horse": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "deer": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "monkey": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "sheep": f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "person": f"{SUPABASE_PUBLIC}/assets/sounds/person/siren.mp3",
}

supabase_headers = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

class CameraServer:
    def __init__(self):
        self.app = Flask(__name__)
        self.model = None
        self.cap = None
        self.is_running = False
        
        self.stream_url = ""
        self.ngrok_process = None
        
        self.siren_active = False
        self.auto_deterrence = False
        self.is_live_requested = False
        self.is_talking = False
        
        self.last_alert_time = 0
        self.detected_classes = [
            "goat", "buffalo", "elephant", "zebra", "bird", "pig", 
            "leopard", "cheetah", "bear", "bull", "horse", 
            "deer", "monkey", "sheep", "person"
        ]
        
        self.audio_buffer = io.BytesIO()
        self.siren_thread = None
        
        self.supabase_headers = {
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        }
        
        self._setup_routes()
        self._load_model()
        self._start_camera()
    
    def _start_detection_loop(self):
        def run_loop():
            print("[DETECT] Starting detection loop (24/7 monitoring)")
            while self.is_running:
                if self.cap is None or not self.cap.isOpened():
                    time.sleep(1)
                    continue
                
                ret, frame = self.cap.read()
                if not ret:
                    time.sleep(0.5)
                    continue
                
                detections = self._detect_objects(frame)
                
                for det in detections:
                    class_name = det['class']
                    confidence = det['confidence']
                    
                    print(f"[DETECT] {class_name} ({confidence:.2f})")
                    
                    if class_name in self.detected_classes:
                        frame_copy = frame.copy()
                        self._capture_and_alert(frame_copy, det)
                
                time.sleep(0.5)
        
        thread = threading.Thread(target=run_loop, daemon=True)
        thread.start()
        print("[DETECT] Detection loop started")
    
    def _load_model(self):
        print(f"[MODEL] Loading {MODEL_PATH}...")
        try:
            self.model = YOLO(MODEL_PATH)
            print("[MODEL] YOLOv8 loaded successfully")
        except Exception as e:
            print(f"[MODEL] Failed to load model: {e}")
            print("[MODEL] Using dummy detection for testing")
            self.model = None
    
    def _start_camera(self):
        print("[CAMERA] Initializing...")
        self.cap = cv2.VideoCapture(CAMERA_INDEX)
        if not self.cap.isOpened():
            print("[CAMERA] WARNING: Could not open camera, using test mode")
        else:
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.cap.set(cv2.CAP_PROP_FPS, 25)
            print("[CAMERA] Camera initialized")
    
    def _setup_routes(self):
        @self.app.route('/video_feed')
        def video_feed():
            return Response(
                self._generate_frames(),
                mimetype='multipart/x-mixed-replace; boundary=--jpgboundary'
            )
        
        @self.app.route('/audio_stream', methods=['POST'])
        def audio_stream():
            if request.content_type != 'application/octet-stream':
                return Response(status=415)
            
            audio_data = request.data
            self._process_incoming_audio(audio_data)
            return Response(status=200)
        
        @self.app.route('/status')
        def status():
            return {
                "device_code": DEVICE_CODE,
                "siren_active": self.siren_active,
                "auto_deterrence": self.auto_deterrence,
                "is_live_requested": self.is_live_requested,
                "is_talking": self.is_talking
            }
        
        @self.app.route('/health')
        def health():
            return {"status": "ok", "timestamp": datetime.now().isoformat()}
    
    def _generate_frames(self):
        while self.is_running or self.is_live_requested:
            if not self.is_live_requested:
                time.sleep(0.1)
                continue
            
            if self.cap is None or not self.cap.isOpened():
                blank_frame = np.zeros((480, 640, 3), np.uint8)
                cv2.putText(blank_frame, "Camera Not Available", (150, 240), 
                           cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
                ret, buffer = cv2.imencode('.jpg', blank_frame)
            else:
                ret, frame = self.cap.read()
                if not ret:
                    break
                
                detections = self._detect_objects(frame)
                frame = self._draw_detections(frame, detections)
                
                for det in detections:
                    class_name = det['class']
                    confidence = det['confidence']
                    print(f"[DETECT] {class_name} ({confidence:.2f})")
                    if class_name in self.detected_classes:
                        self._capture_and_alert(frame, det)
                
                ret, buffer = cv2.imencode('.jpg', frame)
            
            if ret:
                yield (b'--jpgboundary\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
    
    def _detect_objects(self, frame):
        if self.model is None:
            return []
        
        results = self.model(frame, conf=CONFIDENCE_THRESHOLD, verbose=False)
        detections = []
        
        for r in results:
            boxes = r.boxes
            for box in boxes:
                cls_id = int(box.cls[0])
                cls_name = self.model.names[cls_id]
                conf = float(box.conf[0])
                
                detections.append({
                    "class": cls_name,
                    "confidence": conf,
                    "bbox": box.xyxy[0].tolist()
                })
        
        return detections
    
    def _draw_detections(self, frame, detections):
        for det in detections:
            x1, y1, x2, y2 = map(int, det["bbox"])
            label = f"{det['class']} {det['confidence']:.2f}"
            
            color = (0, 255, 0) if det['class'] in self.detected_classes else (128, 128, 128)
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            cv2.putText(frame, label, (x1, y1 - 10), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
        
        cv2.putText(frame, f"Siren: {'ON' if self.siren_active else 'OFF'}", 
                   (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        cv2.putText(frame, f"Auto-Deter: {'ON' if self.auto_deterrence else 'OFF'}", 
                   (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        
        return frame
    
    def _process_incoming_audio(self, audio_data):
        self.is_talking = True
        print(f"[AUDIO] Received {len(audio_data)} bytes of audio data")
        
        try:
            pyaudio = __import__('pyaudio')
            player = pyaudio.PyAudio()
            stream = player.open(format=pyaudio.paInt16, channels=1, rate=16000, output=True)
            stream.write(audio_data)
            stream.close()
            player.terminate()
        except:
            pass
        
        self.is_talking = False
    
    def _capture_and_alert(self, frame, detection):
        current_time = time.time()
        if current_time - self.last_alert_time < ALERT_COOLDOWN:
            return
        
        self.last_alert_time = current_time
        
        intruder_type = detection["class"]
        confidence = detection["confidence"]
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"captures/intruder_{timestamp}.jpg"
        
        cv2.imwrite(filename, frame)
        print(f"[ALERT] Captured {intruder_type} ({confidence:.2f}): {filename}")
        
        self._post_alert_to_supabase(
            intruder_type=intruder_type,
            confidence=confidence,
            image_path=filename
        )
        
        if self.auto_deterrence:
            print(f"[AUDIO] Auto-deterrence ON - playing predator sound for {intruder_type}")
            self._play_predator_sound(intruder_type)
        
        if self.siren_active:
            print("[SIREN] Siren ON - playing alarm")
            self._activate_siren()
    
    def _post_alert_to_supabase(self, intruder_type, confidence, image_path):
        import httpx
        
        image_url = self._upload_image(image_path)
        
        payload = {
            "device_code": DEVICE_CODE,
            "intruder_type": intruder_type,
            "image_url": image_url,
            "owner_id": "1394378f-581f-4a69-9367-7d46b72649c3"
        }
        
        try:
            response = httpx.post(
                f"{SUPABASE_URL}/rest/v1/alerts",
                headers=self.supabase_headers,
                json=payload,
                timeout=10
            )
            if response.status_code in [200, 201]:
                print(f"[ALERT] Logged to Supabase: {intruder_type}")
            else:
                print(f"[ALERT] Failed: {response.status_code} - {response.text}")
        except Exception as e:
            print(f"[ALERT] Error: {e}")
    
    def _upload_image(self, image_path):
        import httpx
        
        with open(image_path, 'rb') as f:
            image_data = f.read()
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{DEVICE_CODE}/{timestamp}.jpg"
        
        try:
            response = httpx.post(
                f"{SUPABASE_URL}/storage/v1/object/detections/{filename}",
                headers={
                    "apikey": SERVICE_ROLE_KEY,
                    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
                    "Content-Type": "image/jpeg"
                },
                content=image_data,
                timeout=30
            )
            if response.status_code in [200, 201]:
                print(f"[STORAGE] Uploaded: detections/{filename}")
                return f"{SUPABASE_URL}/storage/v1/object/public/detections/{filename}"
            else:
                print(f"[STORAGE] Upload failed: {response.status_code}")
        except Exception as e:
            print(f"[STORAGE] Upload error: {e}")
        
        return ""
    
    def _play_predator_sound(self, detected_class):
        class_lower = detected_class.lower()
        sound_url = PREDATOR_SOUNDS.get(class_lower)
        
        if not sound_url:
            print(f"[AUDIO] No sound mapped for: {detected_class}")
            return
        
        print(f"[AUDIO] Playing predator sound for {detected_class}: {sound_url}")
        
        try:
            import httpx
            import platform
            
            response = httpx.get(sound_url, timeout=10, follow_redirects=True)
            if response.status_code == 200:
                audio_data = response.content
                
                system = platform.system()
                if system == "Windows":
                    import tempfile
                    import os
                    import subprocess
                    
                    ext = '.mp3' if '.mp3' in sound_url else '.wav'
                    with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as f:
                        f.write(audio_data)
                        temp_path = f.name
                    
                    os.system(f'start "" "{temp_path}"')
                    print(f"[AUDIO] Playing: {temp_path}")
                    
                elif system == "Linux":
                    import tempfile
                    import subprocess
                    
                    ext = '.mp3' if '.mp3' in sound_url else '.wav'
                    with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as f:
                        f.write(audio_data)
                        temp_path = f.name
                    
                    subprocess.Popen(['mpg123', '-q', temp_path] if ext == '.mp3' else ['aplay', temp_path], 
                                   stderr=subprocess.DEVNULL)
                    print("[AUDIO] Playing via Linux player")
                else:
                    print(f"[AUDIO] Unsupported platform: {system}")
            else:
                print(f"[AUDIO] Failed to download: {response.status_code}")
        except Exception as e:
            print(f"[AUDIO] Error: {e}")
    
    def _activate_siren(self):
        print("[SIREN] Playing alarm from Supabase storage!")
        
        try:
            import httpx
            import platform
            
            response = httpx.get(SIREN_URL, timeout=10, follow_redirects=True)
            if response.status_code == 200:
                audio_data = response.content
                
                system = platform.system()
                if system == "Windows":
                    import tempfile
                    import os
                    import subprocess
                    
                    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as f:
                        f.write(audio_data)
                        temp_path = f.name
                    
                    os.system(f'start "" "{temp_path}"')
                    
                elif system == "Linux":
                    import subprocess
                    import tempfile
                    
                    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as f:
                        f.write(audio_data)
                        temp_path = f.name
                    
                    subprocess.Popen(['mpg123', '-q', temp_path], stderr=subprocess.DEVNULL)
                    print("[SIREN] Playing via mpg123")
                else:
                    print(f"[SIREN] Unsupported platform: {system}")
            else:
                print(f"[SIREN] Failed to download: {response.status_code}")
        except Exception as e:
            print(f"[SIREN] Error: {e}")
    
    def _poll_commands(self):
        import httpx
        
        while self.is_running:
            try:
                response = httpx.get(
                    f"{SUPABASE_URL}/rest/v1/device_registrations?device_code=eq.{DEVICE_CODE}",
                    headers=self.supabase_headers,
                    timeout=10
                )
                
                if response.status_code == 200:
                    data = response.json()
                    if data:
                        device = data[0]
                        
                        new_siren = device.get('siren_active', False)
                        new_auto = device.get('auto_deterrence', False)
                        new_live = device.get('is_live_requested', False)
                        new_talking = device.get('is_talking', False)
                        
                        if new_siren != self.siren_active:
                            self.siren_active = new_siren
                            if self.siren_active:
                                print("[SIREN] Activated from app!")
                                self._activate_siren()
                            else:
                                print("[SIREN] Deactivated")
                        
                        self.auto_deterrence = new_auto
                        self.is_live_requested = new_live
                        
                        if self.is_talking != new_talking:
                            self.is_talking = new_talking
                
            except Exception as e:
                print(f"[POLL] Error: {e}")
            
            time.sleep(1)
    
    def _register_device(self):
        import httpx
        
        payload = {
            "device_code": DEVICE_CODE,
            "password": DEVICE_PASSWORD,
            "is_activated": True,
            "stream_url": f"{self.stream_url}/video_feed",
            "siren_active": False,
            "auto_deterrence": False,
            "is_live_requested": False,
            "is_talking": False
        }
        
        try:
            response = httpx.post(
                f"{SUPABASE_URL}/rest/v1/device_registrations",
                headers={
                    **self.supabase_headers,
                    "Prefer": "resolution=merge-duplicates"
                },
                json=payload,
                timeout=10
            )
            print(f"[REGISTER] Device registration: {response.status_code}")
        except Exception as e:
            print(f"[REGISTER] Error: {e}")
    
    def _start_ngrok(self):
        print("[NGROK] Starting ngrok tunnel...")
        try:
            self.ngrok_process = subprocess.Popen(
                ["ngrok", "http", "5000"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            time.sleep(3)
            
            result = subprocess.run(
                ["curl", "-s", "http://localhost:4040/api/tunnels"],
                capture_output=True, text=True, timeout=5
            )
            
            import json
            tunnels = json.loads(result.stdout)
            for tunnel in tunnels.get('tunnels', []):
                if tunnel.get('proto') == 'https':
                    self.stream_url = tunnel.get('public_url')
                    print(f"[NGROK] Tunnel active: {self.stream_url}")
                    self._update_stream_url()
                    break
                    
        except Exception as e:
            print(f"[NGROK] Error: {e}")
            print("[NGROK] Make sure ngrok is installed and authenticated")
            print("[NGROK] Get auth token from: https://dashboard.ngrok.com/get-started")
    
    def _update_stream_url(self):
        import httpx
        
        try:
            response = httpx.patch(
                f"{SUPABASE_URL}/rest/v1/device_registrations?device_code=eq.{DEVICE_CODE}",
                headers=self.supabase_headers,
                json={"stream_url": f"{self.stream_url}/video_feed"}
            )
            print(f"[UPDATE] Stream URL updated: {response.status_code}")
        except Exception as e:
            print(f"[UPDATE] Error: {e}")
    
    def start(self):
        self.is_running = True
        
        self._register_device()
        
        self._start_ngrok()
        
        poll_thread = threading.Thread(target=self._poll_commands, daemon=True)
        poll_thread.start()
        
        detect_thread = threading.Thread(target=self._start_detection_loop, daemon=True)
        detect_thread.start()
        
        print("\n" + "="*50)
        print("  KRISHI RAKSHAK - Camera Server")
        print("="*50)
        print(f"  Device Code: {DEVICE_CODE}")
        print(f"  Stream URL: {self.stream_url}")
        print(f"  Model: {MODEL_PATH}")
        print("  Detection: 24/7 ACTIVE")
        print("="*50 + "\n")
        
        self.app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)

if __name__ == "__main__":
    import os
    os.makedirs("captures", exist_ok=True)
    os.makedirs("sounds", exist_ok=True)
    
    server = CameraServer()
    server.start()