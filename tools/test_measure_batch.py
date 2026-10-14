#!/usr/bin/env python3
"""Synthetic schema/guard tests, not performance or measured audio evidence."""
import argparse
import copy
import json
import sys
import unittest
sys.dont_write_bytecode = True
import measure_batch as batch


class BatchTests(unittest.TestCase):
    def rows(self):
        result = []
        for name, channels, integrated, peak, qc in [
            ("on_target", 1, -23.0, -20.0, (True, True)),
            ("quiet_stereo", 2, -26.0, -26.0, (False, True)),
            ("hot", 1, -3.4, -0.4, (False, False)),
            ("silence", 1, None, None, (False, False)),
        ]:
            result.append({"kind": "program", "id": name, "frames": 384000,
                           "channels": channels, "integrated": integrated,
                           "lra": 0.0 if integrated is not None else None,
                           "sp": peak, "tp": peak, "loudness_ok": qc[0], "peak_ok": qc[1]})
        result.append({"kind": "aggregate", "assets": 4, "frames": batch.FRAMES,
                       "duration": batch.AUDIO_SECONDS, "integrated": -3.4,
                       "lra": 22.6, "sp": -0.4, "tp": -0.4})
        return result

    def output(self, rows):
        return "\n".join(json.dumps(row) for row in rows)

    def test_schema_and_workload(self):
        self.assertEqual(batch.validate_output(self.output(self.rows())), self.rows())
        self.assertEqual(batch.FRAMES, 1536000)
        self.assertEqual(batch.SAMPLES, 1920000)

    def test_missing_duplicate_or_wrong_workload(self):
        rows = self.rows()
        wrong = copy.deepcopy(rows)
        wrong[0]["frames"] = 100
        for sample in [rows[:-1], rows + rows[:1], wrong, list(reversed(rows))]:
            with self.assertRaises(ValueError):
                batch.validate_output(self.output(sample))

    def test_policy_silence_and_finite_guards(self):
        for index, key, value in [(0, "peak_ok", False), (3, "integrated", -70),
                                  (0, "tp", float("nan")), (4, "tp", float("inf"))]:
            rows = self.rows()
            rows[index][key] = value
            with self.assertRaises(ValueError):
                batch.validate_output(self.output(rows))

    def test_pooled_distribution_not_mean_lufs_or_mean_lra(self):
        for key, value in [("integrated", -17.0), ("lra", 0.0), ("tp", -1.0)]:
            rows = self.rows()
            rows[-1][key] = value
            with self.assertRaises(ValueError):
                batch.validate_output(self.output(rows))

    def test_repetition_configuration(self):
        self.assertEqual(batch.positive("5"), 5)
        for invalid in ["0", "-1"]:
            with self.assertRaises(argparse.ArgumentTypeError):
                batch.positive(invalid)

    def test_fingerprint_is_repeatable(self):
        self.assertEqual(batch.source_digest(), batch.source_digest())
        self.assertEqual(len(batch.source_digest()), 64)


if __name__ == "__main__":
    unittest.main()
