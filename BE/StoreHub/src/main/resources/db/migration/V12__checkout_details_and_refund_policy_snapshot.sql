ALTER TABLE bookings ADD COLUMN checkout_notes TEXT;
ALTER TABLE bookings ADD COLUMN return_notice_days INTEGER;
ALTER TABLE bookings ADD COLUMN refund_sla_days INTEGER;
ALTER TABLE bookings ADD COLUMN refund_policy_legacy BOOLEAN;

-- Historical values were not captured. Freeze the available policy once and disclose this in the contract.
UPDATE bookings b SET
    return_notice_days = GREATEST(0, COALESCE(p.return_notice_days, 0)),
    refund_sla_days = GREATEST(0, COALESCE(p.deposit_refund_sla_days, 5)),
    refund_policy_legacy = TRUE
FROM storage_units su LEFT JOIN facility_policies p ON p.facility_id = su.facility_id
WHERE b.storage_unit_id = su.id;
UPDATE bookings SET return_notice_days = COALESCE(return_notice_days, 0),
    refund_sla_days = COALESCE(refund_sla_days, 5), refund_policy_legacy = TRUE
WHERE refund_policy_legacy IS NULL;

-- Notes previously existed only in the audit history, so recover the most recent checkout request.
UPDATE bookings b SET checkout_notes = substring(a.description from '(?s)\(notes: (.*)\)$')
FROM (SELECT DISTINCT ON (resource_id) resource_id, description FROM activity_logs
      WHERE action = 'CHECKOUT_REQUEST' ORDER BY resource_id, created_at DESC, id DESC) a
WHERE a.resource_id = b.id;

-- A request already in progress has stronger historical evidence than the current facility policy.
UPDATE bookings b SET refund_sla_days = GREATEST(0, ROUND(EXTRACT(EPOCH FROM (r.due_at - r.created_at)) / 86400)::integer)
FROM (SELECT DISTINCT ON (booking_id) booking_id, due_at, created_at FROM refund_requests
      WHERE due_at >= created_at ORDER BY booking_id, created_at DESC, id DESC) r
WHERE r.booking_id = b.id;

ALTER TABLE bookings ALTER COLUMN return_notice_days SET NOT NULL;
ALTER TABLE bookings ALTER COLUMN refund_sla_days SET NOT NULL;
ALTER TABLE bookings ALTER COLUMN refund_policy_legacy SET NOT NULL;
ALTER TABLE bookings ADD CONSTRAINT ck_booking_return_notice_days CHECK (return_notice_days >= 0);
ALTER TABLE bookings ADD CONSTRAINT ck_booking_refund_sla_days CHECK (refund_sla_days >= 0);
