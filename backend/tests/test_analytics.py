import unittest
from datetime import datetime, timezone

from fastapi import HTTPException

from app.api.dev.api import api_router
from app.api.dev.endpoints.analytics import (
    ANALYTICS_EVENT_TYPES,
    _empty_event_counts,
    _event_trend_buckets,
    _event_trend_response,
    _range_start,
)


class AnalyticsEndpointTests(unittest.TestCase):
    def test_analytics_routes_are_registered(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}

        self.assertIn("/analytics/sensors", paths)
        self.assertIn("/analytics/events", paths)
        self.assertIn("/analytics/event-trends", paths)

    def test_supported_ranges_return_datetime(self):
        for range_value in ("24h", "7d", "30d"):
            with self.subTest(range=range_value):
                self.assertIsInstance(_range_start(range_value), datetime)
                self.assertIsNotNone(_range_start(range_value).tzinfo)

    def test_invalid_range_raises_400(self):
        with self.assertRaises(HTTPException) as context:
            _range_start("1y")

        self.assertEqual(context.exception.status_code, 400)

    def test_empty_event_counts_include_all_analytics_event_types(self):
        counts = _empty_event_counts()

        self.assertEqual(
            [item["event_type"] for item in counts],
            ANALYTICS_EVENT_TYPES,
        )
        self.assertTrue(all(item["count"] == 0 for item in counts))

    def test_24h_event_trend_uses_hourly_zero_count_buckets(self):
        now = datetime(2026, 6, 22, 12, 30, tzinfo=timezone.utc)
        buckets = _event_trend_buckets(range_value="24h", now=now)

        self.assertEqual(len(buckets), 24)
        self.assertEqual(buckets[0]["label"], "13:00")
        self.assertEqual(buckets[-1]["label"], "12:00")
        self.assertTrue(
            all(bucket[event_type] == 0 for bucket in buckets for event_type in ANALYTICS_EVENT_TYPES)
        )

    def test_7d_event_trend_uses_daily_zero_count_buckets(self):
        now = datetime(2026, 6, 22, 12, 30, tzinfo=timezone.utc)
        buckets = _event_trend_buckets(range_value="7d", now=now)

        self.assertEqual(len(buckets), 7)
        self.assertEqual(buckets[-1]["label"], "Mon")

    def test_event_trend_response_counts_events_by_bucket(self):
        event = type(
            "Event",
            (),
            {
                "timestamp": datetime(2026, 6, 22, 10, 15, tzinfo=timezone.utc),
                "event_type": "unknown_person",
            },
        )()
        response = _event_trend_response(
            range_value="24h",
            events=[event],
            now=datetime(2026, 6, 22, 12, 30, tzinfo=timezone.utc),
        )

        bucket = next(item for item in response["points"] if item["label"] == "10:00")
        self.assertEqual(response["bucket"], "hourly")
        self.assertEqual(bucket["unknown_person"], 1)


if __name__ == "__main__":
    unittest.main()
