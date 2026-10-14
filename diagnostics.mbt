///|
/// Gate availability is distinct from logarithmic silence and numeric input validity.
pub enum GateStatus {
  WarmingUp
  BelowAbsoluteGate
  HistogramRangeExceeded(Int)
  Available
} derive(Eq, Debug)

///|
fn LoudnessHistogram::status(self : LoudnessHistogram) -> GateStatus {
  if self.above_range_count > 0 {
    HistogramRangeExceeded(self.above_range_count)
  } else if self.total_count == 0.0 {
    WarmingUp
  } else if self.count_at_or_above(-70.0) == 0.0 {
    BelowAbsoluteGate
  } else {
    Available
  }
}

///|
/// Gate is unavailable if any candidate exceeds the bounded +24 LUFS range.
pub fn Analyzer::integrated_status(self : Analyzer) -> GateStatus {
  self.integrated_distribution.status()
}

///|
pub fn Analyzer::lra_status(self : Analyzer) -> GateStatus {
  self.short_distribution.status()
}

///|
pub fn MeasurementReport::integrated_status(
  self : MeasurementReport,
) -> GateStatus {
  self.integrated_distribution.status()
}

///|
pub fn MeasurementReport::lra_status(self : MeasurementReport) -> GateStatus {
  self.short_distribution.status()
}

///|
/// Includes range failures from every independently added program.
pub fn LoudnessAggregator::integrated_status(
  self : LoudnessAggregator,
) -> GateStatus {
  self.integrated_distribution.status()
}

///|
pub fn LoudnessAggregator::lra_status(self : LoudnessAggregator) -> GateStatus {
  self.short_distribution.status()
}

///|
pub extend GateStatus with Eq::{equal, not_equal}

///|
pub extend GateStatus with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn AggregateReport::integrated_status(self : AggregateReport) -> GateStatus {
  self.integrated_status
}

///|
pub fn AggregateReport::lra_status(self : AggregateReport) -> GateStatus {
  self.lra_status
}

///|
/// Versioned report exports encode availability separately from missing values.
fn GateStatus::as_json(self : GateStatus) -> Json {
  let (name, count) = match self {
    WarmingUp => ("warming_up", 0)
    BelowAbsoluteGate => ("below_absolute_gate", 0)
    HistogramRangeExceeded(n) => ("histogram_range_exceeded", n)
    Available => ("available", 0)
  }
  Json::object({
    "status": Json::string(name),
    "above_range_blocks": count.to_json(),
  })
}
