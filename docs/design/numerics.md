# Numerical reliability

## Rolling energy

`EnergyWindow` accepts finite nonnegative frame energies and a positive capacity.
The analyzer uses 19,200 and 144,000 frames. It returns no mean before the first
complete span; clearing requires another complete span before returning a mean.

A subtract-then-add running total cannot retain quiet energy beside a dominant
sample: a capacity-two window fed `[1e30, 1, 1]` returns 0.5 instead of 1 after
the dominant sample expires. Compensation alone is not an adequate recovery
contract. At production capacities, repeated subtraction can even leave a
negative residue after replacing a large constant signal with a quiet one.

The implementation stores unscaled energies in the leaves of a complete binary
sum tree, padded to the next power of two. Replacing a leaf recomputes every
ancestor from its two children. No update subtracts from a rounded running total.
A quiet contribution can still round away while a dominant sibling remains,
but its subtree is retained: it recovers immediately when that sibling expires.
There is no duration-dependent accumulated subtraction error or negative sum
for nonnegative leaves. This is pairwise floating-point summation, not an exact
superaccumulator. For normal finite sums, its standard relative error bound is
`gamma_h = h*u/(1-h*u)`, where `h = ceil(log2(capacity))` and `u = 2^-53`.
Underflow and sum overflow are not covered by that bound. In particular, this
private window does not promise to average arbitrary near-maximum doubles
without overflow; production input magnitude limits keep frame sums far below
that regime.

Updates cost at most `ceil(log2(capacity))` additions, with no periodic full-scan
latency. Storage is `2*next_power_of_two(capacity)` doubles, including an unused
index zero; it is less than four doubles per retained frame. The production
windows use 65,536 and 524,288 slots respectively (about 4.5 MiB in total for
8-byte doubles, excluding runtime array metadata). Reset zeros the full tree
in bounded O(capacity) time. None of these changes affects the public interface.

White-box tests cover dominant-leaf expiry across a 300-decade energy range,
exact silence after expiry, the capacity-two regression, singleton/non-power-
of-two/power-of-two rings, repeated reset and refill, and both production spans.
A separate oracle sorts the current ring smallest-first and re-sums on each
comparison; mixed-scale rollover means agree to relative tolerance `1e-14`.
The original implementation fails four of the initial five regressions,
including a production mean of approximately -1693 instead of 0.25.

## K-weighting validation

The filter tests do not use the production processing functions as their
expected-value oracle. A generic coefficient-polynomial recurrence constructs
separate shelf and high-pass impulse sequences, then direct convolution checks
512 samples of the cascade at absolute tolerance `2e-12`. Two leading impulse
samples also have direct analytic assertions. The coefficients are the existing
48 kHz design constants; these checks validate realization and state handling,
not independent certification or derivation of those published constants.

DC tests check the shelf's numerator/denominator coefficient sums (unity gain)
and the high-pass's double zero at DC. A 0.25 constant step must settle to the
predicted shelf output and zero high-pass/cascade output; every sample in the
second half of a 24,000-frame run is checked.

For 20, 60, 1,000, 10,000, 20,000 and 24,000 Hz, measured cascade output/input
energy is compared against the analytic squared magnitude of
`B(exp(-jw))/A(exp(-jw))` for both sections, multiplied together. Each cosine
has a one-second warmup and a one-second integer-cycle observation interval;
cosine excites the Nyquist endpoint, unlike a sampled sine. The relative gain
squared tolerance is `1e-8`. Independent silent/driven states and newly allocated
states also check that filter histories cannot leak between channels or streams.

## True-peak public contract

Public tests compute direct zero-padded finite convolution on the submitted PCM,
using integer FIR tap numerators over 8192 rather than reproducing the production
ring buffer. Every output position is evaluated, including the first eleven
frames and all eleven trailing zero frames. The finalized reference is the
maximum of the FIR magnitudes and the original sample magnitudes. The live
getter is only the running FIR estimate and can be below sample peak before
finalization. The oracle uses the existing four-phase coefficient design; it is
not a claim of continuous-time reconstruction or official true-peak certification.

Short streams of lengths 0 through 24 check startup and tail behavior, with the
two-sample `[-0.5, -0.5]` fixture requiring an exact finalized peak of
0.6224365234375. Positive and negative isolated impulses at every position in
a 25-frame stream check the maximum-sample floor. A sign-aligned 11-frame suffix
checks a tail-only maximum above both the live estimate and unity. Finalization
must not increment the accepted PCM frame/sample counters or flush twice.

Across mono, stereo and 5.0, strides 1, 2, 5, 11, 12, 13 and 31 include empty
chunks and compare every submitted prefix to the direct-convolution live oracle.
The final peak, overall/channel sample peaks and accepted counters are invariant
to chunk partitioning. Explicit leading/trailing zero padding also leaves the
final peak unchanged. Reset clears interpolation history, maxima and cached
reports for every layout without mutating an already returned report.

These fixtures use dyadic PCM and coefficients, keeping the finite convolution
exactly representable and permitting equality assertions rather than snapshots.
They depend on the separately supplied parent FIR startup correction (original
parent commit `12842f4`), which evaluates the initially zero-filled delay line
on every input frame. That correction is integration baseline, not a change
made in this numerical worker's peak-test commit.

## Validation commands

For every coherent change, run `moon fmt`,
`moon check --target wasm-gc --deny-warn`, and
`moon test --target wasm-gc --deny-warn`. Formatting can rewrite checkout line
endings in otherwise untouched files; those out-of-scope formatter-only writes
are restored before validation/commit. Public interface generation is checked
with `moon info --target wasm-gc`; `pkg.generated.mbti` must remain unchanged.
No snapshots or production filter/FIR constants are updated by these tests.
