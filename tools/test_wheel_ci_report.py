import unittest
from wheel_ci_report import parse, build_record, EXPECTED_VERSION
SAMPLE="odin_wheel210;87707;5.000053733;1;algorithm=wheel,faithful=yes,bits=1\nodin_wheel210_mt;87694;5.000428332;2;algorithm=wheel,faithful=yes,bits=1\n"
HOST={"cpu_model":"AMD EPYC","logical_cpus":2,"affinity_cpus":2}
class WheelCITests(unittest.TestCase):
    def test_valid(self):
        d=build_record(SAMPLE,EXPECTED_VERSION,"a"*40,"123",HOST)
        self.assertEqual(d["status"],"passed")
        self.assertEqual(len(d["lanes"]),2)
    def test_missing(self):
        with self.assertRaises(ValueError):parse(SAMPLE.splitlines()[0])
    def test_duplicate(self):
        with self.assertRaises(ValueError):parse(SAMPLE+SAMPLE.splitlines()[0])
    def test_bad_tag(self):
        with self.assertRaises(ValueError):parse(SAMPLE.replace("algorithm=wheel","algorithm=base"))
    def test_bad_time(self):
        with self.assertRaises(ValueError):parse(SAMPLE.replace("5.000053733","4.0"))
    def test_bad_threads(self):
        with self.assertRaises(ValueError):parse(SAMPLE.replace(";1;algorithm",";2;algorithm"))
    def test_bad_compiler(self):
        with self.assertRaises(ValueError):build_record(SAMPLE,"odin version old","a"*40,"123",HOST)
    def test_bad_sha(self):
        with self.assertRaises(ValueError):build_record(SAMPLE,EXPECTED_VERSION,"bad","123",HOST)
    def test_oversubscription(self):
        with self.assertRaises(ValueError):build_record(SAMPLE,EXPECTED_VERSION,"a"*40,"123",{"logical_cpus":1,"affinity_cpus":1})
