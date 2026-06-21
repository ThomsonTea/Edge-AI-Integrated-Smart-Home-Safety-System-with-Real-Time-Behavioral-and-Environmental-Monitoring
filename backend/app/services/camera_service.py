import cv2
import os
import time
import threading
from datetime import datetime
from pathlib import Path

from ultralytics import YOLO

from app.db.database import SessionLocal
from app.models.event import AIEvent
from app.models.profile import Premise
from app.services.ai_event_service import (
    create_ai_event,
    create_ai_event_from_classification,
)
from app.services.behavioral_anomaly_service import BehavioralAnomalyService
from app.services.face_service import FaceService

os.environ["OPENCV_FFMPEG_CAPTURE_OPTIONS"] = "rtsp_transport;tcp"

BASE_DIR = Path(__file__).resolve().parents[2]
ALERT_STORAGE_DIR = BASE_DIR / "storage" / "alerts"


class CameraService:
    def __init__(self):
        self.rtsp_url = os.getenv(
            "CAMERA_RTSP_URL",
            "rtsp://ThomsonTea:Tyj030903@192.168.0.32/stream1"
        )

        self.camera_premise_id = self._read_camera_premise_id()

        print("⏳ Loading YOLOv8 Model...")
        self.model = YOLO("models/yolo26n.pt")

        self.last_send_time = 0
        self.latest_frame = None
        self.annotated_frame = None
        self.last_detection_time = 0

        self.person_present = False
        self.last_person_seen_time = 0
        self.clear_after_seconds = 10
        self.active_unknown_person_event_id = None
        self.active_unknown_person_image_path = None
        self.best_unknown_person_snapshot_score = 0
        self.last_snapshot_evaluation_time = 0
        self.snapshot_evaluation_interval_seconds = 4
        self.behavior_detector = BehavioralAnomalyService()

        self.lock = threading.Lock()
        self.is_camera_running = False
        self.is_ai_running = False

    def start_camera_loop(self):
        if self.is_camera_running:
            return

        self.is_camera_running = True

        thread = threading.Thread(
            target=self._camera_loop,
            daemon=True
        )
        thread.start()

    def start_ai_detection_loop(self):
        if self.is_ai_running:
            return

        self.is_ai_running = True

        thread = threading.Thread(
            target=self._ai_detection_loop,
            daemon=True
        )
        thread.start()

    def get_runtime_status(self) -> dict:
        with self.lock:
            has_latest_frame = self.latest_frame is not None
            last_detection_time = self.last_detection_time

        model_loaded = self.model is not None

        return {
            "camera_online": bool(self.is_camera_running and has_latest_frame),
            "ai_detection_active": bool(self.is_ai_running and model_loaded),
            "camera_running": bool(self.is_camera_running),
            "ai_loop_running": bool(self.is_ai_running),
            "has_latest_frame": bool(has_latest_frame),
            "last_detection_time": last_detection_time or None,
        }

    def _camera_loop(self):
        cap = cv2.VideoCapture(self.rtsp_url)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        if not cap.isOpened():
            print("❌ Error: Could not connect to CCTV.")
            return

        print("🚀 Camera loop started.")

        while True:
            success, frame = cap.read()

            if not success:
                print("⚠️ Camera frame dropped. Reconnecting...")
                cap.release()
                time.sleep(1)
                cap = cv2.VideoCapture(self.rtsp_url)
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                continue

            preview_frame = cv2.resize(frame, (480, 270))

            with self.lock:
                self.latest_frame = preview_frame

    def _ai_detection_loop(self):
        print("🧠 AI detection loop started.")

        while True:
            time.sleep(0.5)

            with self.lock:
                if self.latest_frame is None:
                    continue

                frame_for_detection = self.latest_frame.copy()

            results = self.model(
                frame_for_detection,
                imgsz=320,
                conf=0.7,
                classes=[0],
                verbose=False,
            )

            current_time = time.time()
            person_detected = len(results[0].boxes) > 0

            if person_detected:
                detection = self._best_person_detection(
                    result=results[0],
                    frame=frame_for_detection,
                )
                conf = detection["confidence"]
                quality_score = detection["quality_score"]
                self._process_behavior_detection(
                    detection=detection,
                    frame=frame_for_detection,
                    current_time=current_time,
                )

                if not self.person_present:
                    print(
                        "🚨 [NEW EVENT] Person detected with "
                        f"{conf:.2f} confidence"
                    )

                    event_data = self._record_detection_event(
                        confidence_score=conf,
                        frame=frame_for_detection,
                    )

                    if event_data is not None:
                        self.active_unknown_person_event_id = event_data["id"]
                        self.active_unknown_person_image_path = event_data["image_path"]
                        self.best_unknown_person_snapshot_score = quality_score
                        self.last_snapshot_evaluation_time = current_time
                        self.person_present = True

                elif self._should_evaluate_snapshot(current_time):
                    self.last_snapshot_evaluation_time = current_time

                    if quality_score > self.best_unknown_person_snapshot_score:
                        updated_image_path = self._update_detection_snapshot(
                            event_id=self.active_unknown_person_event_id,
                            confidence_score=conf,
                            frame=frame_for_detection,
                            previous_image_path=self.active_unknown_person_image_path,
                        )

                        if updated_image_path is not None:
                            self.active_unknown_person_image_path = updated_image_path
                            self.best_unknown_person_snapshot_score = quality_score
                            print(
                                "✅ Person snapshot improved "
                                f"(score={quality_score:.3f})"
                            )

                annotated = results[0].plot()

                with self.lock:
                    self.annotated_frame = annotated
                    self.last_detection_time = current_time

                self.last_person_seen_time = current_time

            else:
                # Reset only after the area is clear for 10 seconds
                if (
                    self.person_present
                    and current_time - self.last_person_seen_time > self.clear_after_seconds
                ):
                    print("✅ Area clear. Ready for next person event.")
                    self.person_present = False
                    self.active_unknown_person_event_id = None
                    self.active_unknown_person_image_path = None
                    self.best_unknown_person_snapshot_score = 0
                    self.last_snapshot_evaluation_time = 0

                    with self.lock:
                        self.annotated_frame = None
                    self.behavior_detector.reset_person_state()

    def generate_frames(self):
        show_box_seconds = 1.5

        while True:
            with self.lock:
                if self.latest_frame is None:
                    frame_to_send = None
                else:
                    current_time = time.time()

                    if (
                        self.annotated_frame is not None
                        and current_time - self.last_detection_time <= show_box_seconds
                    ):
                        frame_to_send = self.annotated_frame.copy()
                    else:
                        frame_to_send = self.latest_frame.copy()

            if frame_to_send is None:
                time.sleep(0.1)
                continue

            ret, buffer = cv2.imencode(
                ".jpg",
                frame_to_send,
                [int(cv2.IMWRITE_JPEG_QUALITY), 45],
            )

            if not ret:
                continue

            yield (
                b"--frame\r\n"
                b"Content-Type: image/jpeg\r\n\r\n"
                + buffer.tobytes()
                + b"\r\n"
            )

            time.sleep(0.03)

    def _record_detection_event(self, confidence_score: float, frame):
        db = SessionLocal()

        try:
            premise_id = self._resolve_premise_id(db)

            if premise_id is None:
                print("⚠️ AI event skipped: no premise configured or found.")
                return None

            image_path = self._save_unknown_person_snapshot(frame)

            if image_path is None:
                print("⚠️ AI event skipped: snapshot could not be saved.")
                return None

            event = create_ai_event_from_classification(
                db,
                premise_id=premise_id,
                classification=self._classify_detected_person(
                    db=db,
                    premise_id=premise_id,
                    frame=frame,
                    yolo_confidence=confidence_score,
                ),
                image_path=image_path,
                is_acknowledged=False,
            )

            print(f"✅ AI event saved: {event.id}")
            return {
                "id": event.id,
                "image_path": event.image_path,
            }

        except Exception as e:
            db.rollback()
            print(f"❌ Failed to save AI event: {e}")
            return None

        finally:
            db.close()

    def _update_detection_snapshot(
        self,
        event_id,
        confidence_score: float,
        frame,
        previous_image_path,
    ):
        if event_id is None:
            return None

        db = SessionLocal()

        try:
            event = db.query(AIEvent).filter(AIEvent.id == event_id).first()

            if event is None:
                return None

            image_path = self._save_unknown_person_snapshot(frame)

            if image_path is None:
                return None

            classification = self._classify_detected_person(
                db=db,
                premise_id=event.premise_id,
                frame=frame,
                yolo_confidence=confidence_score,
            )

            event.event_type = classification["event_type"]
            event.profile_id = classification["profile_id"]
            event.image_path = image_path
            event.confidence_score = classification["confidence_score"]
            db.commit()

            self._delete_snapshot_file(previous_image_path)

            return image_path

        except Exception as e:
            db.rollback()
            print(f"❌ Failed to update AI event snapshot: {e}")
            return None

        finally:
            db.close()

    def _process_behavior_detection(self, detection, frame, current_time: float):
        try:
            anomaly = self.behavior_detector.process_person_bbox(
                bbox=detection.get("bbox"),
                frame_shape=frame.shape,
                confidence=detection.get("confidence", 0.0),
                frame=frame,
                now=current_time,
            )

            if anomaly is None:
                return

            self._record_behavior_event(
                event_type=anomaly.event_type,
                confidence_score=anomaly.confidence_score,
                frame=frame,
                reason=anomaly.reason,
            )

        except Exception as e:
            print(f"⚠️ Behavior detection skipped: {e}")

    def _record_behavior_event(
        self,
        *,
        event_type: str,
        confidence_score: float,
        frame,
        reason: str,
    ):
        db = SessionLocal()

        try:
            premise_id = self._resolve_premise_id(db)

            if premise_id is None:
                print("⚠️ Behavior event skipped: no premise configured or found.")
                return None

            image_path = self._save_alert_snapshot(frame, event_type)

            if image_path is None:
                print("⚠️ Behavior event skipped: snapshot could not be saved.")
                return None

            event = create_ai_event(
                db,
                premise_id=premise_id,
                event_type=event_type,
                confidence_score=confidence_score,
                image_path=image_path,
                is_acknowledged=False,
            )

            print(
                "🚨 Behavior AI event saved: "
                f"id={event.id} type={event_type} reason={reason}"
            )
            return event

        except Exception as e:
            db.rollback()
            print(f"❌ Failed to save behavior AI event: {e}")
            return None

        finally:
            db.close()

    def _should_evaluate_snapshot(self, current_time: float) -> bool:
        elapsed = current_time - self.last_snapshot_evaluation_time
        return elapsed >= self.snapshot_evaluation_interval_seconds

    def _classify_detected_person(
        self,
        db,
        premise_id: int,
        frame,
        yolo_confidence: float,
    ):
        classification = {
            "event_type": "unknown_person",
            "profile_id": None,
            "confidence_score": self._to_confidence_percentage(yolo_confidence),
        }

        try:
            recognition = FaceService(db).recognize_face(
                image=frame,
                premise_id=premise_id,
                db=db,
            )

            recognition_confidence = float(recognition.get("confidence") or 0.0)

            if recognition.get("matched") and recognition.get("profile_id") is not None:
                classification.update(
                    {
                        "event_type": "known_person",
                        "profile_id": recognition["profile_id"],
                        "confidence_score": self._to_confidence_percentage(
                            recognition_confidence
                        ),
                    }
                )
                print(
                    "✅ known_person detected: "
                    f"profile_id={recognition['profile_id']} "
                    f"confidence={recognition_confidence:.3f}"
                )
            else:
                classification["confidence_score"] = (
                    self._to_confidence_percentage(recognition_confidence)
                    if recognition_confidence > 0
                    else self._to_confidence_percentage(yolo_confidence)
                )
                print(
                    "🚨 Unknown person detected "
                    f"(face_confidence={recognition_confidence:.3f}, "
                    f"yolo_confidence={yolo_confidence:.3f})"
                )

        except Exception as e:
            print(f"⚠️ Face recognition failed. Falling back to unknown_person: {e}")

        return classification

    def _to_confidence_percentage(self, value: float) -> float:
        confidence = max(float(value or 0), 0.0)

        if confidence <= 1:
            confidence *= 100

        return min(confidence, 100.0)

    def _best_person_detection(self, result, frame):
        frame_height, frame_width = frame.shape[:2]
        frame_area = max(frame_width * frame_height, 1)

        best_detection = {
            "confidence": 0.0,
            "quality_score": 0.0,
            "bbox": None,
        }

        for box in result.boxes:
            confidence = float(box.conf[0])
            x1, y1, x2, y2 = [float(value) for value in box.xyxy[0]]

            x1 = max(0, min(int(x1), frame_width - 1))
            y1 = max(0, min(int(y1), frame_height - 1))
            x2 = max(0, min(int(x2), frame_width))
            y2 = max(0, min(int(y2), frame_height))

            box_width = max(x2 - x1, 0)
            box_height = max(y2 - y1, 0)
            box_area_ratio = min((box_width * box_height) / frame_area, 1.0)
            blur_score = self._blur_score(frame[y1:y2, x1:x2])

            quality_score = (
                (confidence * 0.6)
                + (box_area_ratio * 0.3)
                + (blur_score * 0.1)
            )

            if quality_score > best_detection["quality_score"]:
                best_detection = {
                    "confidence": confidence,
                    "quality_score": quality_score,
                    "bbox": (x1, y1, x2, y2),
                }

        return best_detection

    def _blur_score(self, image) -> float:
        if image.size == 0:
            return 0.0

        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        variance = cv2.Laplacian(gray, cv2.CV_64F).var()
        return min(variance / 1000, 1.0)

    def _save_unknown_person_snapshot(self, frame):
        return self._save_alert_snapshot(frame, "unknown_person")

    def _save_alert_snapshot(self, frame, event_type: str):
        ALERT_STORAGE_DIR.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{event_type}_{timestamp}.jpg"
        file_path = ALERT_STORAGE_DIR / filename

        saved = cv2.imwrite(str(file_path), frame)

        if not saved:
            return None

        return f"/storage/alerts/{filename}"

    def _delete_snapshot_file(self, image_path):
        if not image_path:
            return

        if not image_path.startswith("/storage/alerts/"):
            return

        file_name = Path(image_path).name
        file_path = ALERT_STORAGE_DIR / file_name

        try:
            if file_path.exists():
                file_path.unlink()
        except OSError as e:
            print(f"⚠️ Failed to delete old snapshot {file_path}: {e}")

    def _resolve_premise_id(self, db):
        if self.camera_premise_id is not None:
            premise = (
                db.query(Premise)
                .filter(Premise.id == self.camera_premise_id)
                .first()
            )

            if premise:
                return premise.id

        premise = db.query(Premise).order_by(Premise.id.asc()).first()
        return premise.id if premise else None

    def _read_camera_premise_id(self):
        raw_value = os.getenv("CAMERA_PREMISE_ID")

        if raw_value is None or raw_value.strip() == "":
            return None

        try:
            return int(raw_value)
        except ValueError:
            print(f"⚠️ Ignoring invalid CAMERA_PREMISE_ID={raw_value}")
            return None
