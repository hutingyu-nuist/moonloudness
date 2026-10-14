///|
/// Validation failures for a non-destructive constant-gain recommendation.
pub enum NormalizationPlanError {
  MissingIntegratedLoudness
  InvalidTargetLufs(Double)
  InvalidTruePeakCeilingDbtp(Double)
}

///|
/// Constant-gain advice constrained by an explicit true-peak ceiling.
/// This value is informational: it never changes or limits audio samples.
pub struct NormalizationPlan {
  priv target_lufs : Double
  priv true_peak_ceiling_dbtp : Double
  priv requested_gain_db : Double
  priv peak_limited_gain_db : Double
  priv applied_gain_db : Double
  priv predicted_integrated_lufs : Double
  priv predicted_true_peak_dbtp : Double
  priv peak_constrained : Bool
}

///|
pub fn NormalizationPlan::target_lufs(self : NormalizationPlan) -> Double {
  self.target_lufs
}

///|
pub fn NormalizationPlan::true_peak_ceiling_dbtp(
  self : NormalizationPlan,
) -> Double {
  self.true_peak_ceiling_dbtp
}

///|
pub fn NormalizationPlan::requested_gain_db(self : NormalizationPlan) -> Double {
  self.requested_gain_db
}

///|
pub fn NormalizationPlan::peak_limited_gain_db(
  self : NormalizationPlan,
) -> Double {
  self.peak_limited_gain_db
}

///|
pub fn NormalizationPlan::applied_gain_db(self : NormalizationPlan) -> Double {
  self.applied_gain_db
}

///|
pub fn NormalizationPlan::predicted_integrated_lufs(
  self : NormalizationPlan,
) -> Double {
  self.predicted_integrated_lufs
}

///|
pub fn NormalizationPlan::predicted_true_peak_dbtp(
  self : NormalizationPlan,
) -> Double {
  self.predicted_true_peak_dbtp
}

///|
pub fn NormalizationPlan::peak_constrained(self : NormalizationPlan) -> Bool {
  self.peak_constrained
}

///|
fn make_normalization_plan(
  measured_lufs : Double,
  measured_dbtp : Double,
  target_lufs : Double,
  ceiling_dbtp : Double,
) -> Result[NormalizationPlan, NormalizationPlanError] {
  if target_lufs - target_lufs != 0.0 ||
    target_lufs < -70.0 ||
    target_lufs > 24.0 {
    return Err(InvalidTargetLufs(target_lufs))
  }
  if ceiling_dbtp - ceiling_dbtp != 0.0 ||
    ceiling_dbtp < -100.0 ||
    ceiling_dbtp > 24.0 {
    return Err(InvalidTruePeakCeilingDbtp(ceiling_dbtp))
  }
  let requested_gain = target_lufs - measured_lufs
  let peak_limited_gain = ceiling_dbtp - measured_dbtp
  let peak_constrained = peak_limited_gain < requested_gain
  let applied_gain = if peak_constrained {
    peak_limited_gain
  } else {
    requested_gain
  }
  Ok({
    target_lufs,
    true_peak_ceiling_dbtp: ceiling_dbtp,
    requested_gain_db: requested_gain,
    peak_limited_gain_db: peak_limited_gain,
    applied_gain_db: applied_gain,
    predicted_integrated_lufs: measured_lufs + applied_gain,
    predicted_true_peak_dbtp: measured_dbtp + applied_gain,
    peak_constrained,
  })
}

///|
/// Recommends constant gain only; it does not normalize or limit the stream.
pub fn MeasurementReport::normalization_plan(
  self : MeasurementReport,
  target_lufs : Double,
  ceiling_dbtp : Double,
) -> Result[NormalizationPlan, NormalizationPlanError] {
  match (self.integrated_lufs, self.true_peak_dbtp()) {
    (Some(lufs), Some(dbtp)) =>
      make_normalization_plan(lufs, dbtp, target_lufs, ceiling_dbtp)
    _ => Err(MissingIntegratedLoudness)
  }
}

///|
pub fn AggregateReport::normalization_plan(
  self : AggregateReport,
  target_lufs : Double,
  ceiling_dbtp : Double,
) -> Result[NormalizationPlan, NormalizationPlanError] {
  match (self.integrated_lufs(), self.true_peak_dbtp()) {
    (Some(lufs), Some(dbtp)) =>
      make_normalization_plan(lufs, dbtp, target_lufs, ceiling_dbtp)
    _ => Err(MissingIntegratedLoudness)
  }
}
