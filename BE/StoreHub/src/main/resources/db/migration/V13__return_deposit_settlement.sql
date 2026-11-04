ALTER TABLE bookings ADD COLUMN return_late_fee_deduction NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE handover_records ADD COLUMN deposit_before_return NUMERIC(12,2);
ALTER TABLE handover_records ADD COLUMN late_fee_deduction NUMERIC(12,2);
ALTER TABLE handover_records ADD COLUMN deposit_refund_amount NUMERIC(12,2);
ALTER TABLE handover_records ADD COLUMN additional_payment_amount NUMERIC(12,2);

-- Earlier Hibernate schema updates can have added an extra single-column unique constraint.
DO $$
DECLARE constraint_name TEXT;
BEGIN
    FOR constraint_name IN
        SELECT c.conname FROM pg_constraint c
        JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
        WHERE c.conrelid = 'deposit_deductions'::regclass AND c.contype = 'u'
          AND array_length(c.conkey, 1) = 1 AND a.attname = 'original_payment_id'
    LOOP
        EXECUTE format('ALTER TABLE deposit_deductions DROP CONSTRAINT %I', constraint_name);
    END LOOP;
END $$;
ALTER TABLE deposit_deductions DROP CONSTRAINT IF EXISTS deposit_deductions_deduction_type_check;
ALTER TABLE deposit_deductions ADD CONSTRAINT uq_deposit_deduction_source_type UNIQUE (original_payment_id, deduction_type);
ALTER TABLE deposit_deductions ADD CONSTRAINT ck_deposit_deduction_type
    CHECK (deduction_type IN ('DAMAGE', 'CANCELLATION', 'LATE_FEE'));
