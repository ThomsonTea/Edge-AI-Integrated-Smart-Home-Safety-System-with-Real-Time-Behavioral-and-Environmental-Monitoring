import cv2
import os
import time
import requests
from ultralytics import YOLO

# PERFORMANCE: Use UDP to reduce lag on the RTSP stream
os.environ['OPENCV_FFMPEG_CAPTURE_OPTIONS'] = 'rtsp_transport;udp'

class CameraService:
    def __init__(self):
        self.rtsp_url = "rtsp://ThomsonTea:Tyj030903@10.42.0.195:554/stream1"
        self.api_url = "https://api.philous.me/ai_event"
        
        # Load the model ONCE when the service starts, not every frame
        print("⏳ Loading YOLOv8 Model...")
        self.model = YOLO("models/yolo26n.pt") 
        self.last_send_time = 0

    def generate_frames(self):
        """
        Connects to the CCTV, runs AI, and yields JPEG frames.
        """
        cap = cv2.VideoCapture(self.rtsp_url)

        if not cap.isOpened():
            print("❌ Error: Could not connect to Tapo CCTV.")
            return

        print("🚀 Connected to Tapo CCTV. AI Engine active...")

        while cap.isOpened():
            success, frame = cap.read()
            if not success:
                print("⚠️ Dropped frame... reconnecting.")
                time.sleep(1) # Prevent CPU overload on disconnect
                cap = cv2.VideoCapture(self.rtsp_url) # Attempt to reconnect
                continue

            # 1. Run AI Detection
            results = self.model(frame, imgsz=320, conf=0.7, classes=[0], verbose=False)
            
            # 2. Check for intruders
            for r in results:
                if len(r.boxes) > 0:
                    current_time = time.time()
                    
                    if current_time - self.last_send_time > 5:  
                        conf = float(r.boxes.conf[0])
                        print(f"⚠️ [DETECTED] Person found with {conf:.2f} confidence")
                        
                        payload = {
                            "event_type": "Person Detected",
                            "confidence_score": conf,
                            "image_path": "storage/alerts/latest.jpg" 
                        }
                        
                        try:
                            # 💡 FYP Note: Since this code now runs INSIDE your FastAPI server,
                            # making an external HTTP request to yourself is slightly inefficient.
                            # In the future, you could just call your DatabaseService directly here!
                            resp = requests.post(self.api_url, json=payload, timeout=1) 
                            print(f"✅ Database Update: {resp.status_code}")
                            self.last_send_time = current_time 
                        except Exception as e:
                            print(f"❌ Failed to send to database: {e}")

            # 3. Draw bounding boxes on the frame
            annotated_frame = results[0].plot()

            # 4. Compress the frame to JPEG
            ret, buffer = cv2.imencode('.jpg', annotated_frame)
            if not ret:
                continue
            
            frame_bytes = buffer.tobytes()
            
            # 5. Yield the frame using the multipart/x-mixed-replace format
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

        cap.release()