ALTER TABLE refund_requests ADD COLUMN confirmed_by_manager_id UUID REFERENCES users(id);
ALTER TABLE refund_requests ADD COLUMN transfer_notes TEXT;
