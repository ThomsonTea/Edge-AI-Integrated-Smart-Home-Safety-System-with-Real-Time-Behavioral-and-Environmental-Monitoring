BEGIN;

ALTER TABLE premise_settings
    ADD COLUMN IF NOT EXISTS event_retention_days INTEGER NOT NULL DEFAULT 90,
    ADD COLUMN IF NOT EXISTS sensor_retention_days INTEGER NOT NULL DEFAULT 30,
    ADD COLUMN IF NOT EXISTS preserve_unacknowledged BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS preserve_critical BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE premise_settings
    DROP CONSTRAINT IF EXISTS ck_premise_settings_event_retention,
    ADD CONSTRAINT ck_premise_settings_event_retention
        CHECK (event_retention_days BETWEEN 1 AND 3650),
    DROP CONSTRAINT IF EXISTS ck_premise_settings_sensor_retention,
    ADD CONSTRAINT ck_premise_settings_sensor_retention
        CHECK (sensor_retention_days BETWEEN 1 AND 3650);

ALTER TABLE ai_events
    ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS ix_ai_events_retention_cleanup
    ON ai_events(premise_id, timestamp)
    WHERE is_pinned = FALSE AND is_acknowledged = TRUE;

COMMIT;
