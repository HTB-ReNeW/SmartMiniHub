"""Validate demo backfill using SQLite with PostgreSQL hash function equivalents."""
import hashlib
import pathlib
import sqlite3
import unittest

SQL = (pathlib.Path(__file__).resolve().parents[3] /
       'src/main/resources/db/migration/V9__complete_demo_booking_agreements.sql').read_text(encoding='utf-8')

class DemoAgreementMigrationTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.db.create_function('char_length', 1, len)
        self.db.create_function('convert_to', 2, lambda value, encoding: value.encode('utf-8'))
        self.db.create_function('sha256', 1, lambda value: hashlib.sha256(value).digest())
        self.db.create_function('encode', 2, lambda value, encoding: value.hex())
        self.db.execute('CREATE TABLE bookings (id TEXT, booking_code TEXT, terms_version TEXT, '
            'terms_content_snapshot TEXT, prohibited_items_snapshot TEXT, terms_hash TEXT, '
            'terms_accepted BOOLEAN, prohibited_items_accepted BOOLEAN, '
            'terms_accepted_at TEXT, created_at TEXT)')
        self.db.executemany('INSERT INTO bookings VALUES (?, ?, ?, ?, ?, ?, 1, 1, ?, ?)', [
            ('demo', 'BK-TEST-ACTIVE-01', 'v2026.1', None, None, None, '2026-10-24', '2026-10-24'),
            ('real', 'BK-REAL-01', 'v2026.1', None, None, None, '2026-10-24', '2026-10-24'),
            ('existing', 'BK-TEST-ACTIVE-02', 'v2026.1', 'Original terms', 'Original list', 'original-hash', '2026-10-24', '2026-10-24'),
            ('new-version', 'BK-TD-ACTIVE-01', 'v2027', None, None, None, '2026-10-24', '2026-10-24'),
        ])

    def run_migration(self):
        # Only syntax adaptation; execute the migration's actual CTE and predicates.
        self.db.executescript(SQL.replace('::text', ''))

    def test_fills_fixture_and_produces_application_compatible_hash(self):
        self.run_migration()
        row = self.db.execute("SELECT * FROM bookings WHERE id='demo'").fetchone()
        self.assertTrue(row['terms_content_snapshot'])
        self.assertTrue(row['prohibited_items_snapshot'])
        parts = [row['terms_version'], row['terms_content_snapshot'], row['prohibited_items_snapshot']]
        canonical = ''.join(str(len(v)) + ':' + v for v in parts)
        self.assertEqual(hashlib.sha256(canonical.encode('utf-8')).hexdigest(), row['terms_hash'])
        self.assertEqual('2026-10-24', row['terms_accepted_at'])

    def test_preserves_real_bookings_existing_snapshots_and_other_versions(self):
        before = list(self.db.execute("SELECT * FROM bookings WHERE id <> 'demo'"))
        self.run_migration()
        self.assertEqual(before, list(self.db.execute("SELECT * FROM bookings WHERE id <> 'demo'")))

    def test_repeat_is_idempotent(self):
        self.run_migration()
        before = list(self.db.execute('SELECT * FROM bookings'))
        self.run_migration()
        self.assertEqual(before, list(self.db.execute('SELECT * FROM bookings')))

if __name__ == '__main__':
    unittest.main()
