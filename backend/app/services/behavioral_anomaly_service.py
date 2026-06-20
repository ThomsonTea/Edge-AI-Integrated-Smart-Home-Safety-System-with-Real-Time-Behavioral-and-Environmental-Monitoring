import os
import time
from dataclasses import dataclass, field
from importlib import import_module
from math import atan2, degrees
from typing import Any


def _bool_from_env(name: str, default: bool) -> bool:
    raw_value = os.getenv(name)

    if raw_value is None:
        return default

    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def _float_from_env(name: str, default: float) -> float:
    raw_value = os.getenv(name)

    if raw_value is None or raw_value.strip() == "":
        return default

    try:
        return float(raw_value)
    except ValueError:
        print(f"⚠️ Ignoring invalid {name}={raw_value}")
        return default


def _int_from_env(name: str, default: int) -> int:
    raw_value = os.getenv(name)

    if raw_value is None or raw_value.strip() == "":
        return default

    try:
        return int(raw_value)
    except ValueError:
        print(f"⚠️ Ignoring invalid {name}={raw_value}")
        return default


@dataclass(frozen=True)
class BehavioralAnomalyConfig:
    enabled: bool = field(
        default_factory=lambda: _bool_from_env(
            "ENABLE_BEHAVIOR_DETECTION",
            False,
        )
    )
    fall_confirm_seconds: float = field(
        default_factory=lambda: _float_from_env("FALL_CONFIRM_SECONDS", 4.0)
    )
    inactivity_seconds: float = field(
        default_factory=lambda: _float_from_env(
            "INACTIVITY_SECONDS",
            _float_from_env("INACTIVITY_SECONDS", 60.0),
        )
    ) 
    emergency_cooldown_seconds: float = field(
        default_factory=lambda: _float_from_env(
            "EMERGENCY_EVENT_COOLDOWN_SECONDS",
            120.0,
        )
    )
    movement_threshold: float = 0.04
    enable_mediapipe_pose: bool = field(
        default_factory=lambda: _bool_from_env("ENABLE_MEDIAPIPE_POSE", False)
    )
    pose_process_every_n_frames: int = field(
        default_factory=lambda: max(_int_from_env("POSE_PROCESS_EVERY_N_FRAMES", 4), 1)
    )
    pose_min_interval_seconds: float = field(
        default_factory=lambda: _float_from_env("POSE_MIN_INTERVAL_SECONDS", 0.5)
    )
    pose_min_visibility: float = field(
        default_factory=lambda: _float_from_env("POSE_MIN_VISIBILITY", 0.5)
    )
    pose_movement_threshold: float = field(
        default_factory=lambda: _float_from_env("POSE_MOVEMENT_THRESHOLD", 0.025)
    )
    pose_angle_change_threshold: float = field(
        default_factory=lambda: _float_from_env("POSE_ANGLE_CHANGE_THRESHOLD", 8.0)
    )
    pose_horizontal_torso_degrees: float = field(
        default_factory=lambda: _float_from_env(
            "POSE_HORIZONTAL_TORSO_DEGREES",
            55.0,
        )
    )
    pose_drop_threshold: float = field(
        default_factory=lambda: _float_from_env("POSE_DROP_THRESHOLD", 0.08)
    )


@dataclass(frozen=True)
class BehavioralAnomalyResult:
    event_type: str
    confidence_score: float
    reason: str


@dataclass(frozen=True)
class PoseSummary:
    body_center: tuple[float, float]
    nose_y: float | None
    shoulder_y: float | None
    hip_y: float | None
    torso_angle_degrees: float
    visibility_score: float


class BehavioralAnomalyService:
    """Lightweight one-person bbox anomaly detector for the camera loop."""

    def __init__(self, config: BehavioralAnomalyConfig | None = None):
        self.config = config or BehavioralAnomalyConfig()
        self._last_center: tuple[float, float] | None = None
        self._inactive_since: float | None = None
        self._fall_candidate_since: float | None = None
        self._cooldown_until: dict[str, float] = {}
        self._active_anomalies: set[str] = set()
        self._tracking_started = False
        self._mp_pose_module: Any | None = None
        self._pose_estimator: Any | None = None
        self._pose_init_failed = False
        self._pose_frame_counter = 0
        self._last_pose_process_time = 0.0
        self._last_pose_summary: PoseSummary | None = None
        self._pose_tracking_started = False

        if self.config.enabled:
            print(
                "✅ Behavior detection enabled "
                f"(fall_confirm={self.config.fall_confirm_seconds}s, "
                f"inactivity={self.config.inactivity_seconds}s, "
                f"cooldown={self.config.emergency_cooldown_seconds}s)"
            )
            if self.config.enable_mediapipe_pose:
                self._log_mediapipe_diagnostics()
                print(
                    "ℹ️ MediaPipe pose mode requested "
                    f"(every_n={self.config.pose_process_every_n_frames}, "
                    f"min_interval={self.config.pose_min_interval_seconds}s)"
                )
        else:
            print("ℹ️ Behavior detection disabled.")

    def _log_mediapipe_diagnostics(self) -> None:
        try:
            mediapipe = import_module("mediapipe")
            solutions_exists = hasattr(mediapipe, "solutions")
            print(
                "[POSE] MediaPipe diagnostic: "
                f"version={getattr(mediapipe, '__version__', 'unknown')} "
                f"solutions_exists={solutions_exists} "
                f"pose_enabled={self.config.enable_mediapipe_pose}"
            )
        except Exception as exc:
            print(
                "[POSE] MediaPipe diagnostic: "
                f"version=unavailable solutions_exists=False "
                f"pose_enabled={self.config.enable_mediapipe_pose} "
                f"error={exc}"
            )

    def process_person_bbox(
        self,
        *,
        bbox: tuple[float, float, float, float] | None,
        frame_shape,
        confidence: float,
        frame=None,
        now: float | None = None,
    ) -> BehavioralAnomalyResult | None:
        if not self.config.enabled or bbox is None:
            return None

        current_time = now if now is not None else time.time()
        frame_height, frame_width = frame_shape[:2]
        bbox_center, bbox_width, bbox_height = self._normalize_bbox(
            bbox=bbox,
            frame_width=max(frame_width, 1),
            frame_height=max(frame_height, 1),
        )
        bbox_ratio = self._bbox_ratio(bbox_width, bbox_height)
        pose_summary = self._pose_summary_if_available(
            frame=frame,
            current_time=current_time,
        )

        if pose_summary is not None:
            return self._process_pose_summary(
                summary=pose_summary,
                confidence=confidence,
                current_time=current_time,
                bbox_width=bbox_width,
                bbox_height=bbox_height,
                bbox_ratio=bbox_ratio,
            )

        return self._process_bbox_summary(
            center=bbox_center,
            width=bbox_width,
            height=bbox_height,
            ratio=bbox_ratio,
            confidence=confidence,
            current_time=current_time,
        )

    def _process_bbox_summary(
        self,
        *,
        center: tuple[float, float],
        width: float,
        height: float,
        ratio: float,
        confidence: float,
        current_time: float,
    ) -> BehavioralAnomalyResult | None:
        if not self._tracking_started:
            print("ℹ️ Behavior bbox tracking started.")
            self._tracking_started = True

        movement_delta = self._movement_delta(center)
        moved_significantly = movement_delta > self.config.movement_threshold
        is_fall_like = width >= height

        if moved_significantly:
            self._inactive_since = current_time
            self._active_anomalies.discard("prolonged_inactivity")
        elif self._inactive_since is None:
            self._inactive_since = current_time

        if is_fall_like:
            if self._fall_candidate_since is None:
                self._fall_candidate_since = current_time
                print("⚠️ Fall candidate detected from horizontal bbox.")
        else:
            self._fall_candidate_since = None
            self._active_anomalies.discard("fall_detected")

        self._last_center = center

        fall_result = self._confirmed_fall(
            current_time=current_time,
            confidence=confidence,
            source="BBOX",
        )
        if fall_result is not None:
            self._log_fall_diagnostics(
                source="BBOX",
                bbox_width=width,
                bbox_height=height,
                bbox_ratio=ratio,
                torso_angle=None,
                is_fall_candidate=is_fall_like,
                current_time=current_time,
                decision=fall_result.event_type,
            )
            return fall_result

        inactivity_result = self._confirmed_inactivity(
            current_time=current_time,
            confidence=confidence,
            source="BBOX",
        )
        self._log_fall_diagnostics(
            source="BBOX",
            bbox_width=width,
            bbox_height=height,
            bbox_ratio=ratio,
            torso_angle=None,
            is_fall_candidate=is_fall_like,
            current_time=current_time,
            decision=(
                inactivity_result.event_type
                if inactivity_result is not None
                else "no_emergency_event"
            ),
        )
        return inactivity_result

    def _process_pose_summary(
        self,
        *,
        summary: PoseSummary,
        confidence: float,
        current_time: float,
        bbox_width: float = 0.0,
        bbox_height: float = 0.0,
        bbox_ratio: float = 0.0,
    ) -> BehavioralAnomalyResult | None:
        if not self._pose_tracking_started:
            print("[POSE] person detected")
            self._pose_tracking_started = True

        movement_delta = self._pose_movement_delta(summary)
        angle_delta = self._pose_angle_delta(summary)
        dropped_significantly = self._pose_drop_delta(summary) >= (
            self.config.pose_drop_threshold
        )
        posture_changed = angle_delta > self.config.pose_angle_change_threshold
        moved_significantly = movement_delta > self.config.pose_movement_threshold
        is_fall_like = self._is_pose_fall_like(summary, dropped_significantly)

        if moved_significantly or posture_changed:
            self._inactive_since = current_time
            self._active_anomalies.discard("prolonged_inactivity")
        elif self._inactive_since is None:
            self._inactive_since = current_time
            print("[POSE] inactivity candidate")

        if is_fall_like:
            if self._fall_candidate_since is None:
                self._fall_candidate_since = current_time
                print("[POSE] fall candidate")
        else:
            self._fall_candidate_since = None
            self._active_anomalies.discard("fall_detected")

        self._last_pose_summary = summary

        fall_result = self._confirmed_fall(
            current_time=current_time,
            confidence=confidence,
            source="POSE",
        )
        if fall_result is not None:
            self._log_fall_diagnostics(
                source="POSE",
                bbox_width=bbox_width,
                bbox_height=bbox_height,
                bbox_ratio=bbox_ratio,
                torso_angle=summary.torso_angle_degrees,
                is_fall_candidate=is_fall_like,
                current_time=current_time,
                decision=fall_result.event_type,
            )
            return fall_result

        inactivity_result = self._confirmed_inactivity(
            current_time=current_time,
            confidence=confidence,
            source="POSE",
        )
        self._log_fall_diagnostics(
            source="POSE",
            bbox_width=bbox_width,
            bbox_height=bbox_height,
            bbox_ratio=bbox_ratio,
            torso_angle=summary.torso_angle_degrees,
            is_fall_candidate=is_fall_like,
            current_time=current_time,
            decision=(
                inactivity_result.event_type
                if inactivity_result is not None
                else "no_emergency_event"
            ),
        )
        return inactivity_result

    def reset_person_state(self) -> None:
        if self._tracking_started:
            print("ℹ️ Behavior tracking reset: no person detected.")

        self._last_center = None
        self._inactive_since = None
        self._fall_candidate_since = None
        self._active_anomalies.clear()
        self._tracking_started = False
        self._last_pose_summary = None
        self._pose_tracking_started = False

    def _confirmed_fall(
        self,
        *,
        current_time: float,
        confidence: float,
        source: str = "BBOX",
    ) -> BehavioralAnomalyResult | None:
        if self._fall_candidate_since is None:
            return None

        duration = current_time - self._fall_candidate_since
        if duration < self.config.fall_confirm_seconds:
            return None

        return self._result_if_allowed(
            event_type="fall_detected",
            confidence=confidence,
            current_time=current_time,
            reason=f"fall-like posture held for {duration:.1f}s",
            source=source,
        )

    def _confirmed_inactivity(
        self,
        *,
        current_time: float,
        confidence: float,
        source: str = "BBOX",
    ) -> BehavioralAnomalyResult | None:
        if self._inactive_since is None:
            return None

        duration = current_time - self._inactive_since
        if duration < self.config.inactivity_seconds:
            return None

        movement_description = (
            "minimal pose landmark movement"
            if source == "POSE"
            else "minimal bbox movement"
        )

        return self._result_if_allowed(
            event_type="prolonged_inactivity",
            confidence=confidence,
            current_time=current_time,
            reason=f"{movement_description} for {duration:.1f}s",
            source=source,
        )

    def _result_if_allowed(
        self,
        *,
        event_type: str,
        confidence: float,
        current_time: float,
        reason: str,
        source: str = "BBOX",
    ) -> BehavioralAnomalyResult | None:
        if event_type in self._active_anomalies:
            if source == "POSE":
                print(f"[POSE] cooldown active for {event_type}")
            return None

        if current_time < self._cooldown_until.get(event_type, 0.0):
            if source == "POSE":
                print(f"[POSE] cooldown active for {event_type}")
            return None

        self._active_anomalies.add(event_type)
        self._cooldown_until[event_type] = (
            current_time + self.config.emergency_cooldown_seconds
        )
        if source == "POSE":
            print(f"[POSE] confirmed {event_type}")
        else:
            print(f"🚨 Behavior anomaly confirmed: {event_type} ({reason})")

        return BehavioralAnomalyResult(
            event_type=event_type,
            confidence_score=self._to_confidence_percentage(confidence),
            reason=reason,
        )

    def _log_fall_diagnostics(
        self,
        *,
        source: str,
        bbox_width: float,
        bbox_height: float,
        bbox_ratio: float,
        torso_angle: float | None,
        is_fall_candidate: bool,
        current_time: float,
        decision: str,
    ) -> None:
        confirmation_elapsed = (
            0.0
            if self._fall_candidate_since is None
            else current_time - self._fall_candidate_since
        )
        torso_value = (
            f"{torso_angle:.1f}"
            if torso_angle is not None
            else "n/a"
        )
        print(
            "[FALL_DIAG] "
            f"source={source} "
            f"bbox_width={bbox_width:.3f} "
            f"bbox_height={bbox_height:.3f} "
            f"width_height_ratio={bbox_ratio:.3f} "
            f"torso_angle={torso_value} "
            f"fall_candidate={is_fall_candidate} "
            f"fall_timer={confirmation_elapsed:.1f}/"
            f"{self.config.fall_confirm_seconds:.1f}s "
            f"decision={decision}"
        )

    def _pose_summary_if_available(
        self,
        *,
        frame,
        current_time: float,
    ) -> PoseSummary | None:
        if (
            not self.config.enable_mediapipe_pose
            or frame is None
            or not self._should_process_pose(current_time)
            or not self._ensure_pose_initialized()
        ):
            return None

        try:
            import cv2

            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = self._pose_estimator.process(rgb_frame)
            landmarks = getattr(results, "pose_landmarks", None)

            if landmarks is None:
                return None

            return self._pose_summary_from_landmarks(landmarks.landmark)

        except Exception as exc:
            print(f"[POSE] failed, using bbox fallback: {exc}")
            return None

    def _should_process_pose(self, current_time: float) -> bool:
        self._pose_frame_counter += 1

        if (
            current_time - self._last_pose_process_time
            < self.config.pose_min_interval_seconds
        ):
            return False

        if self._pose_frame_counter % self.config.pose_process_every_n_frames != 0:
            return False

        self._last_pose_process_time = current_time
        return True

    def _ensure_pose_initialized(self) -> bool:
        if self._pose_estimator is not None:
            return True

        if self._pose_init_failed:
            return False

        try:
            mediapipe = import_module("mediapipe")
            solutions = getattr(mediapipe, "solutions", None)

            if solutions is None:
                self._pose_init_failed = True
                print(
                    "[POSE] MediaPipe classic API unavailable "
                    f"(version={getattr(mediapipe, '__version__', 'unknown')}, "
                    "solutions_exists=False); using bbox fallback."
                )
                return False

            pose_module = getattr(solutions, "pose", None)

            if pose_module is None:
                self._pose_init_failed = True
                print(
                    "[POSE] MediaPipe pose API unavailable "
                    f"(version={getattr(mediapipe, '__version__', 'unknown')}); "
                    "using bbox fallback."
                )
                return False

            self._mp_pose_module = pose_module
            self._pose_estimator = self._mp_pose_module.Pose(
                static_image_mode=False,
                model_complexity=0,
                smooth_landmarks=True,
                enable_segmentation=False,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5,
            )
            print("[POSE] MediaPipe BlazePose initialized.")
            return True

        except Exception as exc:
            self._pose_init_failed = True
            print(f"[POSE] MediaPipe unavailable, using bbox fallback: {exc}")
            return False

    def _pose_summary_from_landmarks(self, landmarks) -> PoseSummary | None:
        pose_landmark = self._mp_pose_module.PoseLandmark

        nose = self._landmark_point(landmarks, pose_landmark.NOSE)
        left_shoulder = self._landmark_point(landmarks, pose_landmark.LEFT_SHOULDER)
        right_shoulder = self._landmark_point(landmarks, pose_landmark.RIGHT_SHOULDER)
        left_hip = self._landmark_point(landmarks, pose_landmark.LEFT_HIP)
        right_hip = self._landmark_point(landmarks, pose_landmark.RIGHT_HIP)
        left_knee = self._landmark_point(landmarks, pose_landmark.LEFT_KNEE)
        right_knee = self._landmark_point(landmarks, pose_landmark.RIGHT_KNEE)
        left_ankle = self._landmark_point(landmarks, pose_landmark.LEFT_ANKLE)
        right_ankle = self._landmark_point(landmarks, pose_landmark.RIGHT_ANKLE)

        shoulder_mid = self._midpoint(left_shoulder, right_shoulder)
        hip_mid = self._midpoint(left_hip, right_hip)

        if shoulder_mid is None or hip_mid is None:
            return None

        body_points = [
            point
            for point in [
                nose,
                left_shoulder,
                right_shoulder,
                left_hip,
                right_hip,
                left_knee,
                right_knee,
                left_ankle,
                right_ankle,
            ]
            if point is not None
        ]

        if len(body_points) < 5:
            return None

        center = (
            sum(point[0] for point in body_points) / len(body_points),
            sum(point[1] for point in body_points) / len(body_points),
        )
        visibility_score = sum(point[2] for point in body_points) / len(body_points)
        torso_angle = abs(
            degrees(
                atan2(
                    hip_mid[1] - shoulder_mid[1],
                    hip_mid[0] - shoulder_mid[0],
                )
            )
        )
        torso_angle_from_horizontal = min(torso_angle, 180 - torso_angle)

        return PoseSummary(
            body_center=center,
            nose_y=nose[1] if nose is not None else None,
            shoulder_y=shoulder_mid[1],
            hip_y=hip_mid[1],
            torso_angle_degrees=torso_angle_from_horizontal,
            visibility_score=visibility_score,
        )

    def _landmark_point(self, landmarks, landmark_id) -> tuple[float, float, float] | None:
        landmark = landmarks[landmark_id.value]
        visibility = float(getattr(landmark, "visibility", 1.0))

        if visibility < self.config.pose_min_visibility:
            return None

        return float(landmark.x), float(landmark.y), visibility

    def _midpoint(
        self,
        first: tuple[float, float, float] | None,
        second: tuple[float, float, float] | None,
    ) -> tuple[float, float, float] | None:
        if first is None or second is None:
            return None

        return (
            (first[0] + second[0]) / 2,
            (first[1] + second[1]) / 2,
            (first[2] + second[2]) / 2,
        )

    def _pose_movement_delta(self, summary: PoseSummary) -> float:
        previous = self._last_pose_summary

        if previous is None:
            return 0.0

        return (
            (summary.body_center[0] - previous.body_center[0]) ** 2
            + (summary.body_center[1] - previous.body_center[1]) ** 2
        ) ** 0.5

    def _pose_angle_delta(self, summary: PoseSummary) -> float:
        previous = self._last_pose_summary

        if previous is None:
            return 0.0

        return abs(summary.torso_angle_degrees - previous.torso_angle_degrees)

    def _pose_drop_delta(self, summary: PoseSummary) -> float:
        previous = self._last_pose_summary

        if previous is None:
            return 0.0

        current_y_values = [
            value
            for value in [summary.nose_y, summary.shoulder_y, summary.hip_y]
            if value is not None
        ]
        previous_y_values = [
            value
            for value in [previous.nose_y, previous.shoulder_y, previous.hip_y]
            if value is not None
        ]

        if not current_y_values or not previous_y_values:
            return 0.0

        return (
            sum(current_y_values) / len(current_y_values)
            - sum(previous_y_values) / len(previous_y_values)
        )

    def _is_pose_fall_like(
        self,
        summary: PoseSummary,
        dropped_significantly: bool,
    ) -> bool:
        torso_horizontal = (
            summary.torso_angle_degrees
            <= self.config.pose_horizontal_torso_degrees
        )
        body_low = max(
            value
            for value in [summary.nose_y, summary.shoulder_y, summary.hip_y]
            if value is not None
        ) >= 0.58

        return torso_horizontal and (dropped_significantly or body_low)

    def _movement_delta(self, center: tuple[float, float]) -> float:
        if self._last_center is None:
            return 0.0

        return (
            (center[0] - self._last_center[0]) ** 2
            + (center[1] - self._last_center[1]) ** 2
        ) ** 0.5

    def _normalize_bbox(
        self,
        *,
        bbox: tuple[float, float, float, float],
        frame_width: int,
        frame_height: int,
    ) -> tuple[tuple[float, float], float, float]:
        x1, y1, x2, y2 = bbox
        width = max((x2 - x1) / frame_width, 0.0)
        height = max((y2 - y1) / frame_height, 0.0)
        center = (
            ((x1 + x2) / 2) / frame_width,
            ((y1 + y2) / 2) / frame_height,
        )

        return center, width, height

    def _bbox_ratio(self, width: float, height: float) -> float:
        if height <= 0:
            return 0.0

        return width / height

    def _to_confidence_percentage(self, value: float) -> float:
        confidence = max(float(value or 0), 0.0)

        if confidence <= 1:
            confidence *= 100

        return min(confidence, 100.0)
