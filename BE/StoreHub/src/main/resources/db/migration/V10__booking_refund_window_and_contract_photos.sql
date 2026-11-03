-- Cancellation window is measured from booking creation; rent is refunded in full before handover.
ALTER TABLE facility_policies
    ADD COLUMN cancellation_within24h_percent DOUBLE PRECISION NOT NULL DEFAULT 100 CHECK (cancellation_within24h_percent BETWEEN 0 AND 100),
    ADD COLUMN cancellation_after24h_percent DOUBLE PRECISION NOT NULL DEFAULT 50 CHECK (cancellation_after24h_percent BETWEEN 0 AND 100);
ALTER TABLE bookings
    ADD COLUMN cancellation_within24h_percent DOUBLE PRECISION,
    ADD COLUMN cancellation_after24h_percent DOUBLE PRECISION,
    ADD COLUMN contract_photos TEXT;
UPDATE bookings SET cancellation_within24h_percent = 100, cancellation_after24h_percent = 50;
