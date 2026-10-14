///|
/// Validation failures for a non-destructive constant-gain recommendation.
pub enum NormalizationPlanError {
  MissingIntegratedLoudness
  InvalidTargetLufs(Double)
  InvalidTruePeakCeilingDbtp(Double)
  InvalidMeasuredLevels
  UnsafeNormalizationMath
}

///|
/// Constant-gain advice constrained by an explicit true-peak ceiling.
/// This value is informational: it never changes or limits audio samples.
/// Predicted loudness holds the original gate membership fixed. Gain can move
/// blocks across the absolute gate, so processed audio MUST be remeasured.
pub struct NormalizationPlan {
  priv target_lufs : Double
  priv true_peak_ceiling_dbtp : Double
  priv requested_gain_db : Double
  priv peak_limited_gain_db : Double
  priv applied_gain_db : Double
  priv linear_gain : Double
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
/// Fixed-gate estimate, not an exact remeasurement of gained audio.
/// Absolute-gate membership can change after gain; remeasure the output.
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
  if measured_lufs - measured_lufs != 0.0 ||
    measured_dbtp - measured_dbtp != 0.0 {
    return Err(InvalidMeasuredLevels)
  }
  let requested_gain = target_lufs - measured_lufs
  let peak_limited_gain = ceiling_dbtp - measured_dbtp
  let peak_constrained = peak_limited_gain < requested_gain
  let applied_gain = if peak_constrained {
    peak_limited_gain
  } else {
    requested_gain
  }
  let linear_gain = @math.pow(10.0, applied_gain / 20.0)
  let predicted_lufs = measured_lufs + applied_gain
  let predicted_dbtp = measured_dbtp + applied_gain
  if requested_gain - requested_gain != 0.0 ||
    peak_limited_gain - peak_limited_gain != 0.0 ||
    applied_gain - applied_gain != 0.0 ||
    linear_gain - linear_gain != 0.0 ||
    linear_gain <= 0.0 ||
    predicted_lufs - predicted_lufs != 0.0 ||
    predicted_dbtp - predicted_dbtp != 0.0 {
    return Err(UnsafeNormalizationMath)
  }
  Ok({
    target_lufs,
    true_peak_ceiling_dbtp: ceiling_dbtp,
    requested_gain_db: requested_gain,
    peak_limited_gain_db: peak_limited_gain,
    applied_gain_db: applied_gain,
    linear_gain,
    predicted_integrated_lufs: predicted_lufs,
    predicted_true_peak_dbtp: predicted_dbtp,
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

///|
/// Positive finite amplitude multiplier corresponding to applied_gain_db.
/// Does not apply gain, change gating, or guarantee exact target loudness.
pub fn NormalizationPlan::linear_gain(self : NormalizationPlan) -> Double {
  self.linear_gain
}

///|
test "normalization rejects invalid measured levels and unsafe finite math" {
  assert_true(
    make_normalization_plan(0.0 / 0.0, 0.0, -23.0, -1.0)
    is Err(InvalidMeasuredLevels),
  )
  assert_true(
    make_normalization_plan(-23.0, 1.0 / 0.0, -23.0, -1.0)
    is Err(InvalidMeasuredLevels),
  )
  assert_true(
    make_normalization_plan(-1.0e308, -1.0e308, 24.0, 24.0)
    is Err(UnsafeNormalizationMath),
  )
  assert_true(
    make_normalization_plan(1.0e308, 1.0e308, -70.0, -100.0)
    is Err(UnsafeNormalizationMath),
  )
}

///|
test "normalization equal peak allowance is not marked constrained" {
  let plan = make_normalization_plan(-23.0, -1.0, -23.0, -1.0).unwrap()
  assert_eq(plan.linear_gain(), 1.0)
  assert_eq(plan.applied_gain_db(), 0.0)
  assert_eq(plan.peak_constrained(), false)
}
