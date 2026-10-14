#!/usr/bin/env python3
"""Harness tests use synthetic parser text, never claimed as measurement evidence."""
import array
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

# Importing the harness must not leave __pycache__ in the repository.
sys.dont_write_bytecode = True
import validate_reference as reference


class ReferenceTests(unittest.TestCase):
    def log(self):
        return """unrelated per-frame I: -70.0
Summary:
 Integrated loudness:
   I: -23.0 LUFS
 Loudness range:
   LRA: 20.0 LU
 Sample peak:
   Peak: -inf -20.0 -26.0 dBFS
 True peak:
   Peak: -inf -19.9 -25.9 dBFS
"""

    def test_summary_last_and_multichannel_max(self):
        parsed = reference.parse_summary("Summary: I: -99.0\n" + self.log())
        self.assertEqual(parsed, {"integrated": -23.0, "lra": 20.0, "sp": -20.0, "tp": -19.9})

    def test_summary_missing_or_unusable_fails(self):
        for log in ["", self.log().replace("True peak:", "Unknown:"),
                    self.log().replace("I: -23.0", "I: -inf")]:
            with self.subTest(log=log), self.assertRaises(ValueError):
                reference.parse_summary(log)

    def test_tolerance_boundary_and_missing_measurement(self):
        self.assertTrue(reference.compare(-23.2, -23.0, "integrated"))
        self.assertFalse(reference.compare(-23.201, -23.0, "integrated"))
        for invalid in [None, float("nan"), float("inf")]:
            self.assertFalse(reference.compare(invalid, -23.0, "integrated"))

    def test_moon_case_inventory(self):
        rows = [json.dumps({"id": case[0]}) for case in reference.CASES]
        self.assertEqual(len(reference.parse_moon("noise\n" + "\n".join(rows))), 5)
        for data in ["\n".join(rows[:-1]), "\n".join(rows + rows[:1]), "\n".join(reversed(rows))]:
            with self.assertRaises(ValueError):
                reference.parse_moon(data)

    def test_gate_sections_and_surround_order(self):
        for second, amplitude in [(0, 0.0), (4, .01), (12, .1), (20, .001), (28, .03), (36, 0.0)]:
            self.assertAlmostEqual(reference.sample("gated", second * 48000 + 12, 0), amplitude)
        self.assertEqual([reference.sample("surround", 12, channel) for channel in range(5)],
                         [0.0, 0.0, 0.0, 0.1, 0.0])

    def test_intersample_phase_and_fades(self):
        self.assertEqual(reference.sample("intersample", 0, 0), 0.0)
        self.assertEqual(reference.sample("intersample", 8 * 48000 - 1, 0), 0.0)
        for frame in range(4800, 4804):
            self.assertAlmostEqual(abs(reference.sample("intersample", frame, 0)), .8 / math.sqrt(2))

    def test_fixture_little_endian_interleaving_and_metadata(self):
        with tempfile.TemporaryDirectory(prefix="moonloudness-unit-") as directory:
            path, metadata = reference.fixture(Path(directory), "stereo", 1, 2)
            self.assertEqual(path.stat().st_size, 48000 * 2 * 8)
            with path.open("rb") as stream:
                first = struct.unpack("<4d", stream.read(32))
            expected = tuple(reference.sample("stereo", frame, channel)
                             for frame in range(2) for channel in range(2))
            self.assertEqual(first, expected)
            self.assertAlmostEqual(metadata["energy"], 48000 * (.1 ** 2 + .05 ** 2) / 2, places=8)
            self.assertAlmostEqual(metadata["sp"], -20.0)
            self.assertEqual(metadata["frames"], 48000)

    def test_subprocess_status_is_checked(self):
        with mock.patch.object(reference.subprocess, "run", side_effect=subprocess.CalledProcessError(7, ["bad"])) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                reference.checked(["bad"])
            self.assertTrue(run.call_args.kwargs["check"])
            self.assertEqual(run.call_args.kwargs["timeout"], 300)


if __name__ == "__main__":
    unittest.main()
