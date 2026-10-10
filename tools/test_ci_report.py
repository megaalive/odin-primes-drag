import unittest
from ci_report import parse


def example():
    return "\n".join([
        "odin_bit_moe;100;5.01;1;algorithm=base,faithful=yes,bits=1",
        "odin_bit_threaded_moe;200;5.02;4;algorithm=base,faithful=yes,bits=1",
        "odin_byte_moe;50;5.03;1;algorithm=base,faithful=yes,bits=8",
        "odin_byte_threaded_moe;120;5.04;4;algorithm=base,faithful=yes,bits=8",
    ])


class RecordTests(unittest.TestCase):
    def test_valid_protocol(self):
        rows = parse(example())
        self.assertEqual(len(rows), 4)
        self.assertAlmostEqual(rows[0]["passes_per_second"], 100 / 5.01)

    def test_missing_lane(self):
        with self.assertRaises(ValueError):
            parse(example().splitlines()[0])

    def test_wrong_tags(self):
        with self.assertRaises(ValueError):
            parse(example().replace("bits=8", "bits=1", 1))

    def test_duplicate(self):
        with self.assertRaises(ValueError):
            parse(example() + "\n" + example().splitlines()[0])

    def test_thread_mismatch(self):
        with self.assertRaises(ValueError):
            parse(example().replace("120;5.04;4", "120;5.04;3"))

    def test_nonfinite_or_invalid_duration(self):
        with self.assertRaises(ValueError):
            parse(example().replace("100;5.01", "100;nan"))


if __name__ == "__main__":
    unittest.main()
