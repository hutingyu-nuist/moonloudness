///|
/// A detached point-in-time view of a streaming loudness analyzer.
pub struct MeterSnapshot {
  priv sample_rate : Int
  priv frame_count : Int
  priv sample_count : Int
  priv momentary_lufs : Double?
  priv short_term_lufs : Double?
  priv sample_peak_linear : Double
  priv true_peak_linear : Double
  priv channel_sample_peaks_linear : Array[Double]
}

///|
/// Returns the frame position represented by this snapshot.
pub fn MeterSnapshot::sample_rate(self : MeterSnapshot) -> Int {
  self.sample_rate
}

///|
pub fn MeterSnapshot::frame_count(self : MeterSnapshot) -> Int {
  self.frame_count
}

///|
pub fn MeterSnapshot::duration_seconds(self : MeterSnapshot) -> Double {
  self.frame_count.to_double() / self.sample_rate.to_double()
}

///|
pub fn MeterSnapshot::sample_count(self : MeterSnapshot) -> Int {
  self.sample_count
}

///|
pub fn MeterSnapshot::momentary_lufs(self : MeterSnapshot) -> Double? {
  self.momentary_lufs
}

///|
pub fn MeterSnapshot::short_term_lufs(self : MeterSnapshot) -> Double? {
  self.short_term_lufs
}

///|
pub fn MeterSnapshot::sample_peak_linear(self : MeterSnapshot) -> Double {
  self.sample_peak_linear
}

///|
pub fn MeterSnapshot::true_peak_linear(self : MeterSnapshot) -> Double {
  self.true_peak_linear
}

///|
/// Returns channel peaks in the configured layout order as an independent array.
pub fn MeterSnapshot::channel_sample_peaks_linear(
  self : MeterSnapshot,
) -> Array[Double] {
  let result : Array[Double] = []
  for peak in self.channel_sample_peaks_linear {
    result.push(peak)
  }
  result
}

///|
/// Bounded chronological history of measurements emitted by one analyzer.
priv struct MeasurementHistory {
  capacity : Int
  values : Array[MeterSnapshot]
  mut next : Int
  mut count : Int
}

///|
fn MeasurementHistory::new(capacity : Int) -> MeasurementHistory {
  let values : Array[MeterSnapshot] = []
  for _ in 0..<capacity {
    values.push({
      sample_rate: 48000,
      frame_count: 0,
      sample_count: 0,
      momentary_lufs: None,
      short_term_lufs: None,
      sample_peak_linear: 0.0,
      true_peak_linear: 0.0,
      channel_sample_peaks_linear: [],
    })
  }
  { capacity, values, next: 0, count: 0, }
}

///|
fn MeasurementHistory::push(
  self : MeasurementHistory,
  point : MeterSnapshot,
) -> Unit {
  if self.capacity > 0 {
    self.values[self.next] = point
    self.next = (self.next + 1) % self.capacity
    if self.count < self.capacity {
      self.count = self.count + 1
    }
  }
}

///|
fn MeasurementHistory::points(
  self : MeasurementHistory,
) -> Array[MeterSnapshot] {
  let result : Array[MeterSnapshot] = []
  let start = if self.count == self.capacity { self.next } else { 0 }
  for offset in 0..<self.count {
    result.push(self.values[(start + offset) % self.capacity])
  }
  result
}

///|
fn MeasurementHistory::last_frame_count(self : MeasurementHistory) -> Int? {
  if self.count == 0 {
    None
  } else {
    let index = (self.next + self.capacity - 1) % self.capacity
    Some(self.values[index].frame_count)
  }
}

///|
fn MeasurementHistory::clear(self : MeasurementHistory) -> Unit {
  self.next = 0
  self.count = 0
}

///|
/// Returns the current counters, levels, and peaks without changing analyzer state.
pub fn Analyzer::snapshot(self : Analyzer) -> MeterSnapshot {
  {
    sample_rate: self.config.sample_rate,
    frame_count: self.frame_count,
    sample_count: self.sample_count,
    momentary_lufs: self.momentary_lufs(),
    short_term_lufs: self.short_term_lufs(),
    sample_peak_linear: self.sample_peak,
    true_peak_linear: self.true_peak_linear(),
    channel_sample_peaks_linear: self.channel_sample_peaks_linear(),
  }
}

///|
/// Returns retained measurement points in chronological order.
pub fn Analyzer::history(self : Analyzer) -> Array[MeterSnapshot] {
  self.history.points()
}

///|
/// Returns the configured maximum number of retained points.
pub fn Analyzer::history_capacity(self : Analyzer) -> Int {
  self.history.capacity
}

///|
/// Drops historical points while keeping all live measurement state.
pub fn Analyzer::clear_history(self : Analyzer) -> Unit {
  self.history.clear()
}

///|
fn Analyzer::record_snapshot(self : Analyzer) -> Unit {
  self.history.push(self.snapshot())
}

///|
/// Returns snapshot sample peak in dBFS, or None for digital silence.
pub fn MeterSnapshot::sample_peak_dbfs(self : MeterSnapshot) -> Double? {
  amplitude_to_db(self.sample_peak_linear)
}

///|
/// Returns the live FIR estimate in dBTP, or None for digital silence.
pub fn MeterSnapshot::true_peak_dbtp(self : MeterSnapshot) -> Double? {
  amplitude_to_db(self.true_peak_linear)
}

///|
// Replace a terminal point after FIR tail flushing without adding a second timestamp.
fn MeasurementHistory::replace_last(
  self : MeasurementHistory,
  point : MeterSnapshot,
) -> Unit {
  if self.count > 0 {
    let index = (self.next + self.capacity - 1) % self.capacity
    self.values[index] = point
  }
}
