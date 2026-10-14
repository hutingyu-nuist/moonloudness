///|
/// Errors returned while combining finalized reports.
pub enum AggregationError {
  UnsupportedAggregateSampleRate(Int)
  ReportSampleRateMismatch(Int, Int)
  AggregateCounterOverflow
  InvalidAggregateCounters
  InvalidAggregateDistribution
  InvalidAggregatePeak
}

///|
/// Fixed-memory accumulator for independently measured programs at one sample rate.
pub struct LoudnessAggregator {
  priv sample_rate : Int
  priv integrated_distribution : LoudnessHistogram
  priv short_distribution : LoudnessHistogram
  priv mut sample_peak_linear : Double
  priv mut true_peak_linear : Double
  priv mut frame_count : Int
  priv mut asset_count : Int
}

///|
/// Creates an accumulator compatible with the available coefficient set.
pub fn LoudnessAggregator::new(
  sample_rate : Int,
) -> Result[LoudnessAggregator, AggregationError] {
  if sample_rate != 48000 {
    Err(UnsupportedAggregateSampleRate(sample_rate))
  } else {
    Ok({
      sample_rate,
      integrated_distribution: LoudnessHistogram::new(),
      short_distribution: LoudnessHistogram::new(),
      sample_peak_linear: 0.0,
      true_peak_linear: 0.0,
      frame_count: 0,
      asset_count: 0,
    })
  }
}

///|
/// Adds one finalized asset without retaining its report or PCM samples.
pub fn LoudnessAggregator::add(
  self : LoudnessAggregator,
  report : MeasurementReport,
) -> Result[Unit, AggregationError] {
  if report.sample_rate != self.sample_rate {
    return Err(ReportSampleRateMismatch(self.sample_rate, report.sample_rate))
  }
  match
    self.validate_addition(
      report.frame_count,
      1,
      report.integrated_distribution,
      report.short_distribution,
      report.sample_peak_linear,
      report.true_peak_linear,
    ) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  self.integrated_distribution.merge(report.integrated_distribution)
  self.short_distribution.merge(report.short_distribution)
  if report.sample_peak_linear > self.sample_peak_linear {
    self.sample_peak_linear = report.sample_peak_linear
  }
  if report.true_peak_linear > self.true_peak_linear {
    self.true_peak_linear = report.true_peak_linear
  }
  self.frame_count = self.frame_count + report.frame_count
  self.asset_count = self.asset_count + 1
  Ok(())
}

///|
/// Number of finalized reports accepted so far.
pub fn LoudnessAggregator::asset_count(self : LoudnessAggregator) -> Int {
  self.asset_count
}

///|
pub fn LoudnessAggregator::frame_count(self : LoudnessAggregator) -> Int {
  self.frame_count
}

///|
/// Immutable combined result calculated over all accepted loudness blocks.
pub struct AggregateReport {
  priv sample_rate : Int
  priv asset_count : Int
  priv frame_count : Int
  priv integrated_status : GateStatus
  priv lra_status : GateStatus
  priv integrated_gate : IntegratedGateReport?
  priv lra_gate : LraGateReport?
  priv sample_peak_linear : Double
  priv true_peak_linear : Double
}

///|
pub fn AggregateReport::sample_rate(self : AggregateReport) -> Int {
  self.sample_rate
}

///|
pub fn AggregateReport::asset_count(self : AggregateReport) -> Int {
  self.asset_count
}

///|
pub fn AggregateReport::frame_count(self : AggregateReport) -> Int {
  self.frame_count
}

///|
pub fn AggregateReport::duration_seconds(self : AggregateReport) -> Double {
  self.frame_count.to_double() / self.sample_rate.to_double()
}

///|
pub fn AggregateReport::integrated_lufs(self : AggregateReport) -> Double? {
  match self.integrated_gate {
    Some(gate) => Some(gate.integrated_lufs())
    None => None
  }
}

///|
pub fn AggregateReport::loudness_range_lu(self : AggregateReport) -> Double? {
  match self.lra_gate {
    Some(gate) => Some(gate.loudness_range_lu())
    None => None
  }
}

///|
pub fn AggregateReport::integrated_gate(
  self : AggregateReport,
) -> IntegratedGateReport? {
  self.integrated_gate
}

///|
pub fn AggregateReport::lra_gate(self : AggregateReport) -> LraGateReport? {
  self.lra_gate
}

///|
pub fn AggregateReport::sample_peak_linear(self : AggregateReport) -> Double {
  self.sample_peak_linear
}

///|
pub fn AggregateReport::true_peak_linear(self : AggregateReport) -> Double {
  self.true_peak_linear
}

///|
pub fn AggregateReport::sample_peak_dbfs(self : AggregateReport) -> Double? {
  amplitude_to_db(self.sample_peak_linear)
}

///|
pub fn AggregateReport::true_peak_dbtp(self : AggregateReport) -> Double? {
  amplitude_to_db(self.true_peak_linear)
}

///|
/// Produces a detached aggregate report; the accumulator remains usable afterward.
pub fn LoudnessAggregator::finish(self : LoudnessAggregator) -> AggregateReport {
  {
    sample_rate: self.sample_rate,
    asset_count: self.asset_count,
    frame_count: self.frame_count,
    integrated_status: self.integrated_status(),
    lra_status: self.lra_status(),
    integrated_gate: integrated_gate_from_histogram(
      self.integrated_distribution,
    ),
    lra_gate: lra_gate_from_histogram(self.short_distribution),
    sample_peak_linear: self.sample_peak_linear,
    true_peak_linear: self.true_peak_linear,
  }
}

///|
pub fn LoudnessAggregator::sample_rate(self : LoudnessAggregator) -> Int {
  self.sample_rate
}

///|
/// Preflights both distributions and all counters before any state is changed.
/// Counts stay within Int range because public gate reports expose Int counts.
fn LoudnessAggregator::validate_addition(
  self : LoudnessAggregator,
  frames : Int,
  assets : Int,
  integrated : LoudnessHistogram,
  short : LoudnessHistogram,
  sample_peak : Double,
  true_peak : Double,
) -> Result[Unit, AggregationError] {
  if frames < 0 || assets < 0 || self.frame_count < 0 || self.asset_count < 0 {
    return Err(InvalidAggregateCounters)
  }
  if frames > 2147483647 - self.frame_count ||
    assets > 2147483647 - self.asset_count {
    return Err(AggregateCounterOverflow)
  }
  if sample_peak < 0.0 ||
    true_peak < sample_peak ||
    sample_peak - sample_peak != 0.0 ||
    true_peak - true_peak != 0.0 {
    return Err(InvalidAggregatePeak)
  }
  match validate_histogram_merge(self.integrated_distribution, integrated) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  validate_histogram_merge(self.short_distribution, short)
}

///|
fn validate_histogram_merge(
  destination : LoudnessHistogram,
  source : LoudnessHistogram,
) -> Result[Unit, AggregationError] {
  if source.counts.length() != destination.counts.length() ||
    source.energy_sums.length() != source.counts.length() {
    return Err(InvalidAggregateDistribution)
  }
  let mut total = 0.0
  for bucket in 0..<source.counts.length() {
    let count = source.counts[bucket]
    let energy = source.energy_sums[bucket]
    if count - count != 0.0 ||
      count < 0.0 ||
      count > 2147483647.0 ||
      @math.floor(count) != count ||
      energy - energy != 0.0 ||
      energy < 0.0 ||
      (count == 0.0 && energy != 0.0) {
      return Err(InvalidAggregateDistribution)
    }
    total = total + count
    let combined_energy = destination.energy_sums[bucket] + energy
    if combined_energy - combined_energy != 0.0 {
      return Err(AggregateCounterOverflow)
    }
  }
  if source.above_range_count < 0 {
    return Err(InvalidAggregateDistribution)
  }
  total = total + source.above_range_count.to_double()
  if total != source.total_count {
    return Err(InvalidAggregateDistribution)
  }
  if total + destination.total_count > 2147483647.0 {
    return Err(AggregateCounterOverflow)
  }
  Ok(())
}

///|
/// Combines independent programs, not concatenated PCM: no cross-program
/// windows or filter transitions are invented. Neither source nor reports are
/// retained. Self-merge deliberately doubles the accepted programs. Histogram
/// addition is associative up to floating-point energy-sum rounding.
pub fn LoudnessAggregator::merge(
  self : LoudnessAggregator,
  other : LoudnessAggregator,
) -> Result[Unit, AggregationError] {
  if other.sample_rate != self.sample_rate {
    return Err(ReportSampleRateMismatch(self.sample_rate, other.sample_rate))
  }
  match
    self.validate_addition(
      other.frame_count,
      other.asset_count,
      other.integrated_distribution,
      other.short_distribution,
      other.sample_peak_linear,
      other.true_peak_linear,
    ) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  self.integrated_distribution.merge(other.integrated_distribution)
  self.short_distribution.merge(other.short_distribution)
  self.frame_count = self.frame_count + other.frame_count
  self.asset_count = self.asset_count + other.asset_count
  if other.sample_peak_linear > self.sample_peak_linear {
    self.sample_peak_linear = other.sample_peak_linear
  }
  if other.true_peak_linear > self.true_peak_linear {
    self.true_peak_linear = other.true_peak_linear
  }
  Ok(())
}

///|
test "aggregation rejects invalid private counters and malformed second histogram atomically" {
  let accumulator = LoudnessAggregator::new(48000).unwrap()
  let analyzer = Analyzer::new(
    MeterConfig::new(48000, ChannelLayout::mono()).unwrap(),
  )
  let report = analyzer.finish()
  assert_true(
    accumulator.validate_addition(
      -1,
      1,
      report.integrated_distribution,
      report.short_distribution,
      0.0,
      0.0,
    )
    is Err(InvalidAggregateCounters),
  )
  report.integrated_distribution.push_energy(1.0)
  report.short_distribution.counts[0] = -1.0
  assert_true(accumulator.add(report) is Err(InvalidAggregateDistribution))
  assert_eq(accumulator.asset_count(), 0)
  assert_eq(accumulator.integrated_distribution.total_count, 0.0)
  assert_eq(accumulator.sample_peak_linear, 0.0)
}

///|
test "aggregation histogram count and energy overflow are atomic" {
  let accumulator = LoudnessAggregator::new(48000).unwrap()
  let other = LoudnessAggregator::new(48000).unwrap()
  other.integrated_distribution.counts[0] = 2147483647.0
  other.integrated_distribution.total_count = 2147483647.0
  assert_true(accumulator.merge(other) is Ok(_))
  assert_true(accumulator.merge(other) is Err(AggregateCounterOverflow))
  assert_eq(accumulator.integrated_distribution.total_count, 2147483647.0)
  let energy = LoudnessAggregator::new(48000).unwrap()
  energy.short_distribution.counts[0] = 1.0
  energy.short_distribution.total_count = 1.0
  energy.short_distribution.energy_sums[0] = 1.0e308
  assert_true(energy.merge(energy) is Err(AggregateCounterOverflow))
  assert_eq(energy.short_distribution.energy_sums[0], 1.0e308)
}
