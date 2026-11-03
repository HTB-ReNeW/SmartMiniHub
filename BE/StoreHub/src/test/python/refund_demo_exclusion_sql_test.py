"""Execute the dispatcher's actual native queries against fixture tables, without a live DB."""
import re
import sqlite3
import unittest
from pathlib import Path


class RefundDemoExclusionTest(unittest.TestCase):
    def setUp(self):
        source = (Path(__file__).resolve().parents[2] / "main/java/com/storehub/repository/RefundRequestRepository.java").read_text(encoding="utf-8")
        self.queries = re.findall(r'@Query\(value = """([^"]*?)""", nativeQuery = true\)', source, re.S)
        self.db = sqlite3.connect(":memory:")
        self.db.executescript("""
            CREATE TABLE bookings(id TEXT PRIMARY KEY, booking_code TEXT NOT NULL);
            CREATE TABLE refund_requests(id TEXT PRIMARY KEY, booking_id TEXT NOT NULL,
                status TEXT, due_at TEXT, updated_status_at TEXT);
        """)
        for index in range(60):
            demo = index < 30
            code = f"DEMO-PG-{index}" if demo else f"BK-{index}"
            self.db.execute("INSERT INTO bookings VALUES (?,?)", (str(index), code))
            self.db.execute("INSERT INTO refund_requests VALUES (?,?,?,?,?)",
                            (str(index), str(index), "QUEUED", f"2026-10-{index % 28 + 1:02d}", "2026-10-01"))

    def tearDown(self):
        self.db.close()

    def test_demo_records_do_not_consume_twenty_dispatch_slots(self):
        self.assertEqual(2, len(self.queries))
        rows = self.db.execute(self.queries[0], {"status": "QUEUED"}).fetchall()
        self.assertEqual(20, len(rows))
        self.assertTrue(all(int(row[0]) >= 30 for row in rows))

    def test_recovery_excludes_demo_before_applying_limit(self):
        self.db.execute("UPDATE refund_requests SET status = 'SENDING'")
        query = self.queries[1].replace(":statuses", ":status1, :status2, :status3")
        rows = self.db.execute(query, {"status1": "SENDING", "status2": "NEEDS_REVIEW",
                                      "status3": "AWAITING_CONFIRMATION", "before": "2026-11-01"}).fetchall()
        self.assertEqual(20, len(rows))
        self.assertTrue(all(int(row[0]) >= 30 for row in rows))


if __name__ == "__main__":
    unittest.main()
