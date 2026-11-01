#!/usr/bin/env python3
"""Reject a missing or obsolete MoonBit compiler before running acceptance checks."""
import argparse
import re
import subprocess
import sys

MINIMUM = (0, 10, 16)


def compiler_version(output):
    """Read the compiler line rather than confusing moon or moonrun with moonc."""
    match = re.search(r"^moonc\s+v?(\d+)\.(\d+)\.(\d+)(?:\+[^\s]+)?(?:\s|$)", output, re.MULTILINE)
    if not match:
        raise ValueError("Cannot identify moonc version in toolchain output")
    return tuple(int(part) for part in match.groups())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--moon", default="moon", help="Moon executable to verify")
    args = parser.parse_args(argv)
    try:
        result = subprocess.run([args.moon, "version", "--all"], check=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                encoding="utf-8", errors="replace", timeout=30)
        version = compiler_version(result.stdout)
    except (OSError, subprocess.SubprocessError, ValueError):
        print("Cannot verify MoonBit compiler; install moonc >= 0.10.16.", file=sys.stderr)
        return 1
    print(result.stdout, end="")
    if version < MINIMUM:
        print("Acceptance requires moonc >= 0.10.16.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
