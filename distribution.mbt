///| A bounded histogram of block energy indexed by LUFS.

///| Buckets cover -120..24 LUFS at 0.01 LU resolution; per-bucket energy sums

///|
/// retain exact mean-square values for the integrated gate calculation.
priv struct LoudnessHistogram {
  counts : Array[Double]
  energy_sums : Array[Double]
  mut total_count : Double
  mut above_range_count : Int
}

///|
/// Lowest loudness represented without clamping.
const HISTOGRAM_MIN_LUFS : Double = -120.0

///|
/// Highest loudness represented without clamping.
const HISTOGRAM_MAX_LUFS : Double = 24.0

///|
/// Number of quantization buckets per loudness unit.
const HISTOGRAM_BUCKETS_PER_LU : Int = 100

///|
/// Creates fixed-size arrays for the declared range and resolution.
fn LoudnessHistogram::new() -> LoudnessHistogram {
  let bucket_count = ((HISTOGRAM_MAX_LUFS - HISTOGRAM_MIN_LUFS) *
    HISTOGRAM_BUCKETS_PER_LU.to_double()).to_int() +
    1
  let counts : Array[Double] = []
  let energy_sums : Array[Double] = []
  for _ in 0..<bucket_count {
    counts.push(0.0)
    energy_sums.push(0.0)
  }
  { counts, energy_sums, total_count: 0.0, above_range_count: 0, }
}

///|
/// Maps an energy to a clamped, deterministic histogram bucket.
fn LoudnessHistogram::bucket_for_energy(
  self : LoudnessHistogram,
  energy : Double,
) -> Int {
  let lufs = energy_to_lufs(energy)
  let scaled = (lufs - HISTOGRAM_MIN_LUFS) *
    HISTOGRAM_BUCKETS_PER_LU.to_double()
  if scaled < 0.0 {
    0
  } else if scaled >= self.counts.length().to_double() {
    self.counts.length() - 1
  } else {
    scaled.to_int()
  }
}

///|
/// Adds one complete gating block without retaining an unbounded block list.
fn LoudnessHistogram::push_energy(
  self : LoudnessHistogram,
  energy : Double,
) -> Unit {
  self.total_count = self.total_count + 1.0
  if energy_to_lufs(energy) > HISTOGRAM_MAX_LUFS {
    self.above_range_count = self.above_range_count + 1
    return
  }
  let bucket = self.bucket_for_energy(energy)
  self.counts[bucket] = self.counts[bucket] + 1.0
  self.energy_sums[bucket] = self.energy_sums[bucket] + energy
}

///|
/// Finds the first bucket whose lower edge is at or above a loudness gate.
fn LoudnessHistogram::first_bucket_at_or_above(
  self : LoudnessHistogram,
  threshold_lufs : Double,
) -> Int {
  let scaled = (threshold_lufs - HISTOGRAM_MIN_LUFS) *
    HISTOGRAM_BUCKETS_PER_LU.to_double()
  if scaled < 0.0 {
    0
  } else if scaled >= self.counts.length().to_double() {
    self.counts.length()
  } else {
    let base = scaled.to_int()
    let fraction = scaled - base.to_double()
    // Ignore floating-point residue at a mathematically exact bucket edge.
    if fraction > 0.000000001 {
      base + 1
    } else {
      base
    }
  }
}

///|
/// Returns the exact mean energy of occupied buckets above a gate.
fn LoudnessHistogram::mean_energy_at_or_above(
  self : LoudnessHistogram,
  threshold_lufs : Double,
) -> Double? {
  let start = self.first_bucket_at_or_above(threshold_lufs)
  if start >= self.counts.length() {
    return None
  }
  let mut count = 0.0
  let mut energy = 0.0
  for bucket in start..<self.counts.length() {
    count = count + self.counts[bucket]
    energy = energy + self.energy_sums[bucket]
  }
  if count == 0.0 {
    None
  } else {
    Some(energy / count)
  }
}

///|
/// Returns the retained block count above an EBU-style loudness gate.
fn LoudnessHistogram::count_at_or_above(
  self : LoudnessHistogram,
  threshold_lufs : Double,
) -> Double {
  let start = self.first_bucket_at_or_above(threshold_lufs)
  let mut count = 0.0
  for bucket in start..<self.counts.length() {
    count = count + self.counts[bucket]
  }
  count
}

///|
/// Returns a bucket-edge percentile after gate application.
fn LoudnessHistogram::percentile_at_or_above(
  self : LoudnessHistogram,
  threshold_lufs : Double,
  percentile : Int,
) -> Double? {
  let start = self.first_bucket_at_or_above(threshold_lufs)
  let count = self.count_at_or_above(threshold_lufs)
  if count == 0.0 {
    return None
  }
  // Use the nearest zero-based order-statistic index, with half-up ties.
  let target = @math.floor((count - 1.0) * percentile.to_double() / 100.0 + 0.5)
  let mut cumulative = 0.0
  for bucket in start..<self.counts.length() {
    cumulative = cumulative + self.counts[bucket]
    if cumulative > target {
      return Some(
        HISTOGRAM_MIN_LUFS +
        bucket.to_double() / HISTOGRAM_BUCKETS_PER_LU.to_double(),
      )
    }
  }
  Some(HISTOGRAM_MAX_LUFS)
}

///|
/// Clears all bins while retaining their allocated, fixed capacity.
fn LoudnessHistogram::clear(self : LoudnessHistogram) -> Unit {
  for bucket in 0..<self.counts.length() {
    self.counts[bucket] = 0.0
    self.energy_sums[bucket] = 0.0
  }
  self.total_count = 0.0
  self.above_range_count = 0
}

///|
/// Makes an independent fixed-capacity copy for finalized report aggregation.
fn LoudnessHistogram::clone(self : LoudnessHistogram) -> LoudnessHistogram {
  let counts : Array[Double] = []
  let energy_sums : Array[Double] = []
  for bucket in 0..<self.counts.length() {
    counts.push(self.counts[bucket])
    energy_sums.push(self.energy_sums[bucket])
  }
  {
    counts,
    energy_sums,
    total_count: self.total_count,
    above_range_count: self.above_range_count,
  }
}

///|
/// Merges another histogram with identical fixed bounds and resolution.
fn LoudnessHistogram::merge(
  self : LoudnessHistogram,
  other : LoudnessHistogram,
) -> Unit {
  for bucket in 0..<self.counts.length() {
    self.counts[bucket] = self.counts[bucket] + other.counts[bucket]
    self.energy_sums[bucket] = self.energy_sums[bucket] +
      other.energy_sums[bucket]
  }
  self.total_count = self.total_count + other.total_count
  self.above_range_count = self.above_range_count + other.above_range_count
}
