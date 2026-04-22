import cv2 
from ultralytics import YOLO
import requests
import time
import os

os.environ['OPENCV_FFMPEG_CAPTURE_OPTIONS'] = 'rtsp_transport;udp'

RTSP_URL = "rtsp://ThomsonTea:Tyj030903@192.168.0.44:554/stream1"
# Load a pretrained YOLO model (nano - fastest)
model = YOLO("models/yolo26n.pt")

API_URL = "https://api.philous.me/ai_event"

def start_detection():
    # Use the RTSP URL instead of 0
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

        # AI Detection logic (keep your existing logic here)
        results = model(frame, imgsz=320, conf=0.5, classes=[0], verbose=False)
        
        cv2.imshow("Smart Home CCTV Feed", results[0].plot())
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    start_detection()


# # Train the model using the 'coco8.yaml' dataset for 3 epochs
# results = model.train(data="coco8.yaml", epochs=3)

# # Evaluate the model's performance on the validation set
# results = model.val()

# # Perform object detection on an image using the model
# results = model("https://ultralytics.com/images/bus.jpg")

# # Export the model to ONNX format
# success = model.export(format="onnx")