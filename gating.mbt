///|
/// Auditable thresholds and counts used for integrated-loudness gating.
pub struct IntegratedGateReport {
  priv absolute_threshold_lufs : Double
  priv relative_threshold_lufs : Double
  priv applied_threshold_lufs : Double
  priv candidate_block_count : Int
  priv gated_block_count : Int
  priv integrated_lufs : Double
}

///|
pub fn IntegratedGateReport::absolute_threshold_lufs(
  self : IntegratedGateReport,
) -> Double {
  self.absolute_threshold_lufs
}

///|
pub fn IntegratedGateReport::relative_threshold_lufs(
  self : IntegratedGateReport,
) -> Double {
  self.relative_threshold_lufs
}

///|
pub fn IntegratedGateReport::applied_threshold_lufs(
  self : IntegratedGateReport,
) -> Double {
  self.applied_threshold_lufs
}

///|
pub fn IntegratedGateReport::candidate_block_count(
  self : IntegratedGateReport,
) -> Int {
  self.candidate_block_count
}

///|
pub fn IntegratedGateReport::gated_block_count(
  self : IntegratedGateReport,
) -> Int {
  self.gated_block_count
}

///|
pub fn IntegratedGateReport::integrated_lufs(
  self : IntegratedGateReport,
) -> Double {
  self.integrated_lufs
}

///|
/// Auditable thresholds, accepted block counts, and percentiles for LRA.
pub struct LraGateReport {
  priv absolute_threshold_lufs : Double
  priv relative_threshold_lufs : Double
  priv applied_threshold_lufs : Double
  priv candidate_block_count : Int
  priv gated_block_count : Int
  priv percentile_10_lufs : Double
  priv percentile_95_lufs : Double
  priv loudness_range_lu : Double
}

///|
pub fn LraGateReport::absolute_threshold_lufs(self : LraGateReport) -> Double {
  self.absolute_threshold_lufs
}

///|
pub fn LraGateReport::relative_threshold_lufs(self : LraGateReport) -> Double {
  self.relative_threshold_lufs
}

///|
pub fn LraGateReport::applied_threshold_lufs(self : LraGateReport) -> Double {
  self.applied_threshold_lufs
}

///|
pub fn LraGateReport::candidate_block_count(self : LraGateReport) -> Int {
  self.candidate_block_count
}

///|
pub fn LraGateReport::gated_block_count(self : LraGateReport) -> Int {
  self.gated_block_count
}

///|
pub fn LraGateReport::percentile_10_lufs(self : LraGateReport) -> Double {
  self.percentile_10_lufs
}

///|
pub fn LraGateReport::percentile_95_lufs(self : LraGateReport) -> Double {
  self.percentile_95_lufs
}

///|
pub fn LraGateReport::loudness_range_lu(self : LraGateReport) -> Double {
  self.loudness_range_lu
}

///|
/// Returns the integrated-gate trace when at least one block passes the absolute gate.
pub fn MeasurementReport::integrated_gate(
  self : MeasurementReport,
) -> IntegratedGateReport? {
  self.integrated_gate
}

///|
pub fn MeasurementReport::lra_gate(self : MeasurementReport) -> LraGateReport? {
  self.lra_gate
}

///|
/// Calculates the two EBU-style integrated gates over bounded block statistics.
fn integrated_gate_from_histogram(
  histogram : LoudnessHistogram,
) -> IntegratedGateReport? {
  if histogram.above_range_count > 0 {
    return None
  }
  match histogram.mean_energy_at_or_above(-70.0) {
    None => None
    Some(absolute_mean) => {
      let absolute_loudness = energy_to_lufs(absolute_mean)
      let relative_threshold = absolute_loudness - 10.0
      let applied_threshold = if relative_threshold > -70.0 {
        relative_threshold
      } else {
        -70.0
      }
      match histogram.mean_energy_at_or_above(applied_threshold) {
        None => None
        Some(gated_mean) =>
          Some({
            absolute_threshold_lufs: -70.0,
            relative_threshold_lufs: relative_threshold,
            applied_threshold_lufs: applied_threshold,
            candidate_block_count: histogram.count_at_or_above(-70.0).to_int(),
            gated_block_count: histogram
            .count_at_or_above(applied_threshold)
            .to_int(),
            integrated_lufs: energy_to_lufs(gated_mean),
          })
      }
    }
  }
}

///|
/// Calculates EBU-style absolute and relative LRA gates and 10th/95th percentiles.
fn lra_gate_from_histogram(histogram : LoudnessHistogram) -> LraGateReport? {
  if histogram.above_range_count > 0 {
    return None
  }
  match histogram.mean_energy_at_or_above(-70.0) {
    None => None
    Some(absolute_mean) => {
      let absolute_loudness = energy_to_lufs(absolute_mean)
      let relative_threshold = absolute_loudness - 20.0
      let applied_threshold = if relative_threshold > -70.0 {
        relative_threshold
      } else {
        -70.0
      }
      match
        (
          histogram.percentile_at_or_above(applied_threshold, 10),
          histogram.percentile_at_or_above(applied_threshold, 95),
        ) {
        (Some(p10), Some(p95)) =>
          Some({
            absolute_threshold_lufs: -70.0,
            relative_threshold_lufs: relative_threshold,
            applied_threshold_lufs: applied_threshold,
            candidate_block_count: histogram.count_at_or_above(-70.0).to_int(),
            gated_block_count: histogram
            .count_at_or_above(applied_threshold)
            .to_int(),
            percentile_10_lufs: p10,
            percentile_95_lufs: p95,
            loudness_range_lu: p95 - p10,
          })
        _ => None
      }
    }
  }
}

///|
fn Analyzer::calculate_integrated_gate(
  self : Analyzer,
) -> IntegratedGateReport? {
  integrated_gate_from_histogram(self.integrated_distribution)
}

///|
fn Analyzer::calculate_lra_gate(self : Analyzer) -> LraGateReport? {
  lra_gate_from_histogram(self.short_distribution)
}
