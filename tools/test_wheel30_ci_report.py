import unittest
from wheel30_ci_report import parse, build_record, EXPECTED_VERSION

SAMPLE="odin_wheel30;105302;5.0001;1;algorithm=wheel,faithful=yes,bits=1\n"
HOST={"cpu_model":"AMD EPYC", "logical_cpus":2, "affinity_cpus":2}

class Wheel30CITests(unittest.TestCase):
    def test_valid(self):
        record=build_record(SAMPLE,EXPECTED_VERSION,"a"*40,"123",HOST)
        self.assertEqual(record["track"],"wheel-30")
        self.assertEqual(record["source"],"github-actions")
        self.assertEqual(record["lanes"][0]["workers"],1)
        self.assertEqual(len(record["lanes"]),1)
        self.assertEqual(record["build_variant"],"Wheel-30 B2 (CI-selected)")
        self.assertEqual(len(record["source_sha256"]),64)
    def test_missing(self):
        with self.assertRaises(ValueError):parse("")
    def test_duplicate(self):
        with self.assertRaises(ValueError):parse(SAMPLE+SAMPLE)
    def test_bad_tags(self):
        with self.assertRaises(ValueError):parse(SAMPLE.replace("algorithm=wheel","algorithm=base"))
    def test_invalid_time(self):
        with self.assertRaises(ValueError):parse(SAMPLE.replace("5.0001","4.0"))
    def test_wrong_workers(self):
        with self.assertRaises(ValueError):parse(SAMPLE.replace(";1;algorithm",";2;algorithm"))
    def test_bad_compiler(self):
        with self.assertRaises(ValueError):build_record(SAMPLE,"odin version old","a"*40,"123",HOST)
    def test_bad_sha(self):
        with self.assertRaises(ValueError):build_record(SAMPLE,EXPECTED_VERSION,"bad","123",HOST)
