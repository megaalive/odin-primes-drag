"""Recompute published, explicitly local Base results from source samples."""
import json
import statistics
import unittest
from pathlib import Path

class BaseIntelReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads(Path("base-intel12900h.json").read_text(encoding="utf-8"))

    def test_provenance_is_not_ci(self):
        d=self.data
        self.assertEqual(d["status"],"reported")
        self.assertEqual(d["track"],"base")
        self.assertEqual(d["original_source_commit"],"f3279ab5b93093b8ba89a0e77b3a17a0921d20b1")
        self.assertEqual(d["source_compatibility"]["strict_original_source_verdict"],"inconclusive")
        self.assertIn("#+feature using-stmt",d["source_compatibility"]["minimal_change"])
        self.assertEqual(d["compiler"]["version"],"dev-2026-10-nightly:84bc3fc")
        self.assertEqual(d["host"]["cpu_model"],"Intel Core i9-12900H")

    def test_all_samples_and_medians(self):
        d=self.data
        self.assertEqual(len(d["lanes"]),4)
        seen=set()
        for lane in d["lanes"]:
            self.assertNotIn(lane["label"],seen)
            seen.add(lane["label"])
            self.assertEqual(len(lane["rounds"]),7)
            self.assertEqual([r["round"] for r in lane["rounds"]],list(range(1,8)))
            expected_workers=1 if lane["mode"]=="single" else 20
            self.assertEqual(lane["workers"],expected_workers)
            for r in lane["rounds"]:
                self.assertGreater(r["passes"],0)
                self.assertGreaterEqual(r["seconds"],5)
                self.assertAlmostEqual(r["passes_per_second"],r["passes"]/r["seconds"],places=6)
            self.assertAlmostEqual(lane["median_passes_per_second"],
                                   statistics.median(r["passes_per_second"] for r in lane["rounds"]),places=6)
        self.assertEqual(seen,{"odin_bit_moe","odin_bit_threaded_moe","odin_byte_moe","odin_byte_threaded_moe"})

    def test_known_medians(self):
        medians={x["label"]:x["median_passes_per_second"] for x in self.data["lanes"]}
        self.assertAlmostEqual(medians["odin_bit_moe"],9721.83259,places=4)
        self.assertAlmostEqual(medians["odin_bit_threaded_moe"],38288.42245,places=4)

if __name__=="__main__":
    unittest.main()
