ALTER TABLE bookings ADD COLUMN payment_deferred BOOLEAN NOT NULL DEFAULT FALSE;
-- Before this feature, unpaid reservations could be left by the existing Pay later button.
UPDATE bookings SET payment_deferred = TRUE
WHERE status = 'PENDING_PAYMENT' AND expires_at > LOCALTIMESTAMP;
CREATE INDEX idx_bookings_deferred_customer ON bookings(customer_id, expires_at)
WHERE payment_deferred = TRUE AND status = 'PENDING_PAYMENT';
