import unittest
from datetime import datetime, timezone

from fastapi import HTTPException

from app.api.dev.api import api_router
from app.api.dev.endpoints.analytics import (
    ANALYTICS_EVENT_TYPES,
    _empty_event_counts,
    _range_start,
)


class AnalyticsEndpointTests(unittest.TestCase):
    def test_analytics_routes_are_registered(self):
        paths = {getattr(route, "path", None) for route in api_router.routes}

        self.assertIn("/analytics/sensors", paths)
        self.assertIn("/analytics/events", paths)

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


if __name__ == "__main__":
    unittest.main()
