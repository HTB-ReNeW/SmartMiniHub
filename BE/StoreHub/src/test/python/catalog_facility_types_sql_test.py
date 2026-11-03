"""Exercise the catalog query on SQLite after translating JPQL entity paths."""
import pathlib
import re
import sqlite3
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[3] / 'src/main/java/com/storehub/repository/UnitTypeRepository.java'

def catalog_sql():
    source = SOURCE.read_text(encoding='utf-8')
    query = re.search(r'@Query\("""(.*?)"""\)', source, re.S).group(1)
    query = query.replace('SELECT ut,', 'SELECT ut.id,')
    query = query.replace('su.unitType = ut', 'su.unit_type_id = ut.id')
    query = query.replace('offered.unitType = ut', 'offered.unit_type_id = ut.id')
    query = query.replace('su.facility.id', 'su.facility_id').replace('offered.facility.id', 'offered.facility_id')
    query = query.replace('com.storehub.enums.UnitStatus.AVAILABLE', "'AVAILABLE'")
    query = query.replace('com.storehub.enums.FacilityStatus.ACTIVE', "'ACTIVE'")
    for entity, table in [('UnitType', 'unit_types'), ('StorageUnit', 'storage_units'), ('Facility', 'facilities')]:
        query = re.sub(r'\b' + entity + r'\b', table, query)
    return query

class CatalogFacilityTypesTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.executescript("""
            CREATE TABLE facilities(id TEXT PRIMARY KEY, status TEXT);
            CREATE TABLE unit_types(id TEXT PRIMARY KEY, typeName TEXT, dimensions TEXT,
              areaSqm REAL, basePricePerMonth REAL, depositAmount REAL);
            CREATE TABLE storage_units(id TEXT PRIMARY KEY, unit_type_id TEXT, facility_id TEXT, status TEXT);
            INSERT INTO facilities VALUES ('f1','ACTIVE'),('f2','ACTIVE');
            INSERT INTO unit_types VALUES
              ('small','Small','1x1x1',1,500000,500000),
              ('large','Large','3x3x3',9,2500000,2500000),
              ('soldout','Medium','2x2x2',4,1200000,1200000),
              ('unused','Unused','5x5x5',25,9000000,9000000);
            INSERT INTO storage_units VALUES
              ('a','small','f1','AVAILABLE'),('b','small','f2','AVAILABLE'),
              ('c','large','f2','AVAILABLE'),('d','soldout','f1','OCCUPIED');
        """)
    def test_only_types_present_at_requested_facility_are_returned(self):
        rows = dict(self.db.execute(catalog_sql(), {'facilityId': 'f1'}))
        self.assertEqual({'small': 1, 'soldout': 0}, rows)
    def test_other_facility_does_not_inherit_absent_cheaper_or_soldout_types(self):
        rows = dict(self.db.execute(catalog_sql(), {'facilityId': 'f2'}))
        self.assertEqual({'small': 1, 'large': 1}, rows)
    def test_global_catalog_still_lists_all_types(self):
        rows = dict(self.db.execute(catalog_sql(), {'facilityId': None}))
        self.assertEqual({'small': 2, 'large': 1, 'soldout': 0, 'unused': 0}, rows)

if __name__ == '__main__':
    unittest.main()
