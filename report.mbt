///|
/// Result of finalizing one analyzer stream.
pub struct MeasurementReport {
  priv integrated_lufs : Double?
  priv loudness_range_lu : Double?
  priv integrated_gate : IntegratedGateReport?
  priv lra_gate : LraGateReport?
  priv momentary_lufs : Double?
  priv short_term_lufs : Double?
  priv sample_peak_linear : Double
  priv channel_sample_peaks_linear : Array[Double]
  priv true_peak_linear : Double
  priv frame_count : Int
  priv sample_rate : Int
  priv integrated_distribution : LoudnessHistogram
  priv short_distribution : LoudnessHistogram
}

///|
/// Returns integrated loudness after absolute and relative gating.
pub fn MeasurementReport::integrated_lufs(self : MeasurementReport) -> Double? {
  self.integrated_lufs
}

///|
/// Returns gated short-term loudness range, if enough signal passed the gates.
pub fn MeasurementReport::loudness_range_lu(
  self : MeasurementReport,
) -> Double? {
  self.loudness_range_lu
}

///|
/// Returns the latest complete 400 ms measurement.
pub fn MeasurementReport::momentary_lufs(self : MeasurementReport) -> Double? {
  self.momentary_lufs
}

///|
/// Returns the latest complete 3 s measurement.
pub fn MeasurementReport::short_term_lufs(self : MeasurementReport) -> Double? {
  self.short_term_lufs
}

///|
/// Returns the largest absolute submitted PCM sample.
pub fn MeasurementReport::sample_peak_linear(
  self : MeasurementReport,
) -> Double {
  self.sample_peak_linear
}

///|
/// Returns the maximum four-phase FIR estimate after the FIR tail was flushed.
pub fn MeasurementReport::channel_sample_peaks_linear(
  self : MeasurementReport,
) -> Array[Double] {
  let result : Array[Double] = []
  for peak in self.channel_sample_peaks_linear {
    result.push(peak)
  }
  result
}

///|
/// Returns one channel's peak or None when the channel index is invalid.
pub fn MeasurementReport::channel_sample_peak_linear(
  self : MeasurementReport,
  channel : Int,
) -> Double? {
  if channel < 0 || channel >= self.channel_sample_peaks_linear.length() {
    None
  } else {
    Some(self.channel_sample_peaks_linear[channel])
  }
}

///|
pub fn MeasurementReport::true_peak_linear(self : MeasurementReport) -> Double {
  self.true_peak_linear
}

///|
/// Returns the count of complete input frames accepted by the analyzer.
pub fn MeasurementReport::frame_count(self : MeasurementReport) -> Int {
  self.frame_count
}

///|
pub fn MeasurementReport::sample_rate(self : MeasurementReport) -> Int {
  self.sample_rate
}

///|
pub fn MeasurementReport::duration_seconds(self : MeasurementReport) -> Double {
  self.frame_count.to_double() / self.sample_rate.to_double()
}

///|
/// Converts positive linear amplitude to decibels relative to full scale.
fn amplitude_to_db(amplitude : Double) -> Double? {
  if amplitude <= 0.0 {
    None
  } else {
    Some(20.0 * @math.log10(amplitude))
  }
}

///|
/// Returns sample peak in dBFS; silence has no finite logarithmic value.
pub fn MeasurementReport::sample_peak_dbfs(self : MeasurementReport) -> Double? {
  amplitude_to_db(self.sample_peak_linear)
}

///|
/// Returns true peak in dBTP; silence has no finite logarithmic value.
pub fn MeasurementReport::true_peak_dbtp(self : MeasurementReport) -> Double? {
  amplitude_to_db(self.true_peak_linear)
}

///|
/// Finalizes the input and flushes the Annex 2 interpolation FIR tail.
pub fn Analyzer::finish(self : Analyzer) -> MeasurementReport {
  match self.cached_report {
    Some(report) => report
    None => {
      for _ in 0..<11 {
        self.push_true_peak_frame([][:], 0, false)
      }
      if self.sample_peak > self.true_peak_max {
        self.true_peak_max = self.sample_peak
      }
      if self.frame_count > 0 {
        if self.history.last_frame_count() == Some(self.frame_count) {
          self.history.replace_last(self.snapshot())
        } else {
          self.record_snapshot()
        }
      }
      let integrated_gate = self.calculate_integrated_gate()
      let lra_gate = self.calculate_lra_gate()
      let integrated_lufs = match integrated_gate {
        Some(gate) => Some(gate.integrated_lufs())
        None => None
      }
      let loudness_range_lu = match lra_gate {
        Some(gate) => Some(gate.loudness_range_lu())
        None => None
      }
      let report = {
        integrated_lufs,
        loudness_range_lu,
        integrated_gate,
        lra_gate,
        momentary_lufs: self.momentary_lufs(),
        short_term_lufs: self.short_term_lufs(),
        sample_peak_linear: self.sample_peak,
        channel_sample_peaks_linear: self.channel_sample_peaks_linear(),
        true_peak_linear: self.true_peak_max,
        frame_count: self.frame_count,
        sample_rate: self.config.sample_rate,
        integrated_distribution: self.integrated_distribution.clone(),
        short_distribution: self.short_distribution.clone(),
      }
      self.finished = true
      self.cached_report = Some(report)
      report
    }
  }
}

///|
/// Restarts the analyzer with the same immutable stream configuration.
pub fn Analyzer::reset(self : Analyzer) -> Unit {
  self.filters = new_filter_states(self.config.layout)
  self.sample_peak = 0.0
  for channel in 0..<self.channel_sample_peaks.length() {
    self.channel_sample_peaks[channel] = 0.0
  }
  self.true_peak_ring = []
  for _ in 0..<self.config.layout.channels() {
    self.true_peak_ring.push(new_zero_ring(12))
  }
  self.true_peak_cursor = 0
  self.true_peak_max = 0.0
  self.sample_count = 0
  self.frame_count = 0
  self.momentary_window.clear()
  self.short_window.clear()
  self.latest_momentary_energy = None
  self.latest_short_energy = None
  self.integrated_distribution.clear()
  self.short_distribution.clear()
  self.finished = false
  self.cached_report = None
  self.history.clear()
}
