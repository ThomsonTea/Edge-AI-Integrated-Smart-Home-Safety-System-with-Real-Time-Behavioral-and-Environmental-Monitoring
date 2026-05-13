import cv2 
from ultralytics import YOLO
import requests
import time
import os

# PERFORMANCE: Use UDP to reduce lag on the RTSP stream
os.environ['OPENCV_FFMPEG_CAPTURE_OPTIONS'] = 'rtsp_transport;udp'

RTSP_URL = "rtsp://ThomsonTea:Tyj030903@192.168.137.176:554/stream1"
API_URL = "https://api.philous.me/ai_event"

model = YOLO("models/yolo26n.pt")

def start_detection():
    last_send_time = 0
    
    cap = cv2.VideoCapture(RTSP_URL)

    if not cap.isOpened():
        print("❌ Error: Could not connect to Tapo CCTV. Check IP/Password.")
        return

    print("🚀 Connected to Tapo CCTV. AI Engine active...")

    while cap.isOpened():
        success, frame = cap.read()
        if not success:
            print("⚠️ Dropped frame... reconnecting.")
            continue

        # 1. Run AI Detection
        results = model(frame, imgsz=320, conf=0.7, classes=[0], verbose=False)
        
        # 2. Check if a person is in the frame
        for r in results:
            if len(r.boxes) > 0:
                current_time = time.time()
                
                # Only execute this block if 5 seconds have passed since the last alert
                if current_time - last_send_time > 5:  
                    conf = float(r.boxes.conf[0])
                    print(f"⚠️ [DETECTED] Person found with {conf:.2f} confidence")
                    
                    # 3. Prepare the data for your Database
                    payload = {
                        "event_type": "Person Detected",
                        "confidence_score": conf,
                        "image_path": "storage/alerts/latest.jpg" 
                    }
                    
                    # 4. Send the Request
                    try:
                        # Short timeout keeps the video from freezing
                        resp = requests.post(API_URL, json=payload, timeout=1) 
                        print(f"✅ Database Update: {resp.status_code} - {resp.json()}")
                        
                        # Reset the timer ONLY if the request was successful
                        last_send_time = current_time 
                    except Exception as e:
                        print(f"❌ Failed to send to database: {e}")

        # Show the video feed (Will update smoothly now!)
        cv2.imshow("Smart Home CCTV Feed", results[0].plot())
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    start_detection()