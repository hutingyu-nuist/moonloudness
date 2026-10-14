///|
/// Errors returned while combining finalized reports.
pub enum AggregationError {
  UnsupportedAggregateSampleRate(Int)
  ReportSampleRateMismatch(Int, Int)
  AggregateCounterOverflow
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
  if report.frame_count > 2147483647 - self.frame_count ||
    self.asset_count == 2147483647 {
    return Err(AggregateCounterOverflow)
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
