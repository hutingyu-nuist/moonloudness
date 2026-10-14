# Third-party attribution and reference boundaries

MoonLoudness is an independently written MoonBit implementation. It does not copy or mechanically translate third-party implementation source.

## Algorithm and behavior references

- **ITU-R BS.1770-5 (2023)**, “Algorithms to measure audio programme loudness and true-peak audio level.” The project implements a bounded subset of the published 48 kHz K-weighting and Annex 2 true-peak coefficient path. Standard prose and test vectors are not redistributed. <https://www.itu.int/rec/R-REC-BS.1770>
- **EBU Tech 3341, 3342, and 3343** inform the momentary/short-term, integrated-gating, and loudness-range behavior. No official EBU test suite or EBU audio assets are included or claimed as passed. <https://tech.ebu.ch/publications/tech3341> <https://tech.ebu.ch/publications/tech3342> <https://tech.ebu.ch/publications/tech3343>
- **Rust `sdroege/ebur128` v0.1.10**, fixed reference commit `0052abf06d8844f0972657c71e327d7eeee8967c`, MIT; copyright Jan Kokemüller and Sebastian Dröge. This is an independent behavior-comparison pointer only. No Rust source, tests, fixtures, or generated output was copied or translated. <https://github.com/sdroege/ebur128/tree/0052abf06d8844f0972657c71e327d7eeee8967c>

## License

The MoonLoudness source is distributed under the MIT License in [`LICENSE`](LICENSE). No third-party runtime dependency is added beyond MoonBit core's math package. Numerical coefficients and algorithm descriptions are attributed to the standards above; this repository does not reproduce their prose or official conformance materials.

## Optional independent validation tool

`tools/validate_reference.py` optionally invokes a separately installed FFmpeg
executable as an independent `ebur128` comparator. FFmpeg is by the FFmpeg
project (<https://ffmpeg.org/>); its licensing depends on build options (LGPL
2.1-or-later by default; GPL-enabled/version-3 builds select different terms; see
<https://ffmpeg.org/legal.html> and the installed build's `ffmpeg -L`). The
measured local Gyan full build reports GPL 3-or-later in `ffmpeg -L`; this
project does not distribute it.
No FFmpeg source, executable, coefficients, or reference fixtures are copied
by this workflow. All new PCM fixtures are original deterministic formulas,
generated temporarily outside the repository. This optional subprocess test
dependency does not change the MoonLoudness library license or dependencies.
