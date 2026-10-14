///| Channel ordering accepted by the analyzer.

///|
/// FivePointZero uses L, R, C, Ls, Rs order; it has no LFE channel.
pub enum ChannelLayout {
  Mono
  Stereo
  FivePointZero
}

///|
/// Returns the layouts implemented by this release.
pub fn ChannelLayout::supported() -> Array[ChannelLayout] {
  [Mono, Stereo, FivePointZero]
}

///|
/// Returns the canonical mono layout.
pub fn ChannelLayout::mono() -> ChannelLayout {
  Mono
}

///|
/// Returns the canonical left-right stereo layout.
pub fn ChannelLayout::stereo() -> ChannelLayout {
  Stereo
}

///|
/// Returns the canonical 5.0 layout in L,R,C,Ls,Rs order.
pub fn ChannelLayout::five_point_zero() -> ChannelLayout {
  FivePointZero
}

///|
/// Returns the canonical short name for a channel index in this layout.
pub fn ChannelLayout::channel_label(
  self : ChannelLayout,
  index : Int,
) -> String? {
  match (self, index) {
    (Mono, 0) => Some("C")
    (Stereo, 0) => Some("L")
    (Stereo, 1) => Some("R")
    (FivePointZero, 0) => Some("L")
    (FivePointZero, 1) => Some("R")
    (FivePointZero, 2) => Some("C")
    (FivePointZero, 3) => Some("Ls")
    (FivePointZero, 4) => Some("Rs")
    _ => None
  }
}

///|
/// Returns the BS.1770 channel multiplier, or None for an invalid index.
pub fn ChannelLayout::channel_weight(
  self : ChannelLayout,
  index : Int,
) -> Double? {
  match (self, index) {
    (Mono, 0) | (Stereo, 0) | (Stereo, 1) => Some(1.0)
    (FivePointZero, 0) | (FivePointZero, 1) | (FivePointZero, 2) => Some(1.0)
    (FivePointZero, 3) | (FivePointZero, 4) => Some(1.41)
    _ => None
  }
}

///|
/// Finds the exact canonical channel label in a layout.
pub fn ChannelLayout::index_of(self : ChannelLayout, label : String) -> Int? {
  for index in 0..<self.channels() {
    if self.channel_label(index) == Some(label) {
      return Some(index)
    }
  }
  None
}

///|
/// Returns the number of interleaved samples in one frame.
pub fn ChannelLayout::channels(self : ChannelLayout) -> Int {
  match self {
    Mono => 1
    Stereo => 2
    FivePointZero => 5
  }
}

///|
/// Typed configuration and input errors.
pub enum MeterError {
  UnsupportedSampleRate(Int)
  IncompleteFrame(Int, Int)
  NonFiniteSample
  SampleMagnitudeTooLarge(Double)
  CounterOverflow
  InvalidHistoryCapacity(Int)
  AnalyzerFinished
}

///|
/// Immutable configuration for one 48 kHz PCM stream.
pub struct MeterConfig {
  priv sample_rate : Int
  priv layout : ChannelLayout
}

///|
/// Creates a configuration. Only the published 48 kHz coefficient set is enabled.
pub fn MeterConfig::new(
  sample_rate : Int,
  layout : ChannelLayout,
) -> Result[MeterConfig, MeterError] {
  if sample_rate != 48000 {
    Err(UnsupportedSampleRate(sample_rate))
  } else {
    Ok({ sample_rate, layout, })
  }
}

///|
/// Returns the configured sample rate in samples per second.
pub fn MeterConfig::sample_rate(self : MeterConfig) -> Int {
  self.sample_rate
}

///|
/// Returns the interleaved channel layout.
pub fn MeterConfig::layout(self : MeterConfig) -> ChannelLayout {
  self.layout
}

///|
/// Allocates independent K-weighting state for every configured channel.
fn new_filter_states(layout : ChannelLayout) -> Array[KWeightingState] {
  let states : Array[KWeightingState] = []
  for _ in 0..<layout.channels() {
    states.push(KWeightingState::new())
  }
  states
}

///|
/// Allocates a zero-initialized ring for one channel.
fn new_zero_ring(length : Int) -> Array[Double] {
  let ring : Array[Double] = []
  for _ in 0..<length {
    ring.push(0.0)
  }
  ring
}

///| ITU-R BS.1770-5 Annex 2 order-48, four-phase FIR coefficients.

///|
/// The outer index is phase; coefficient order is oldest to newest sample.
fn true_peak_coefficients() -> Array[Array[Double]] {
  [
    [
      0.001708984375, 0.010986328125, -0.0196533203125, 0.033203125, -0.0594482421875,
      0.1373291015625, 0.97216796875, -0.102294921875, 0.047607421875, -0.026611328125,
      0.014892578125, -0.00830078125,
    ],
    [
      -0.0291748046875, 0.029296875, -0.0517578125, 0.089111328125, -0.16650390625,
      0.465087890625, 0.77978515625, -0.2003173828125, 0.1015625, -0.0582275390625,
      0.0330810546875, -0.0189208984375,
    ],
    [
      -0.0189208984375, 0.0330810546875, -0.0582275390625, 0.1015625, -0.2003173828125,
      0.77978515625, 0.465087890625, -0.16650390625, 0.089111328125, -0.0517578125,
      0.029296875, -0.0291748046875,
    ],
    [
      -0.00830078125, 0.014892578125, -0.026611328125, 0.047607421875, -0.102294921875,
      0.97216796875, 0.1373291015625, -0.0594482421875, 0.033203125, -0.0196533203125,
      0.010986328125, 0.001708984375,
    ],
  ]
}

///|
/// Stateful analyzer for interleaved PCM frames at 48 kHz.
pub struct Analyzer {
  priv config : MeterConfig
  priv mut filters : Array[KWeightingState]
  priv mut sample_peak : Double
  priv channel_sample_peaks : Array[Double]
  priv peak_coefficients : Array[Array[Double]]
  priv mut true_peak_ring : Array[Array[Double]]
  priv mut true_peak_cursor : Int
  priv mut true_peak_max : Double
  priv mut sample_count : Int
  priv mut frame_count : Int
  priv momentary_window : EnergyWindow
  priv short_window : EnergyWindow
  priv mut latest_momentary_energy : Double?
  priv mut latest_short_energy : Double?
  priv integrated_distribution : LoudnessHistogram
  priv short_distribution : LoudnessHistogram
  priv mut finished : Bool
  priv mut cached_report : MeasurementReport?
  priv history : MeasurementHistory
}

///|
/// Starts an empty analyzer with separate filter and window history.
pub fn Analyzer::new(config : MeterConfig) -> Analyzer {
  Analyzer::new_internal(config, 600)
}

///|
/// Creates an analyzer with a bounded history capacity (zero disables retention).
pub fn Analyzer::new_with_history_capacity(
  config : MeterConfig,
  capacity : Int,
) -> Result[Analyzer, MeterError] {
  if capacity < 0 || capacity > 100000 {
    Err(InvalidHistoryCapacity(capacity))
  } else {
    Ok(Analyzer::new_internal(config, capacity))
  }
}

///|
fn Analyzer::new_internal(
  config : MeterConfig,
  history_capacity : Int,
) -> Analyzer {
  let peak_ring : Array[Array[Double]] = []
  for _ in 0..<config.layout.channels() {
    peak_ring.push(new_zero_ring(12))
  }
  {
    config,
    filters: new_filter_states(config.layout),
    sample_peak: 0.0,
    channel_sample_peaks: new_zero_ring(config.layout.channels()),
    peak_coefficients: true_peak_coefficients(),
    true_peak_ring: peak_ring,
    true_peak_cursor: 0,
    true_peak_max: 0.0,
    sample_count: 0,
    frame_count: 0,
    momentary_window: EnergyWindow::new(19200),
    short_window: EnergyWindow::new(144000),
    latest_momentary_energy: None,
    latest_short_energy: None,
    integrated_distribution: LoudnessHistogram::new(),
    short_distribution: LoudnessHistogram::new(),
    finished: false,
    cached_report: None,
    history: MeasurementHistory::new(history_capacity),
  }
}

///|
/// Adds complete interleaved frames. The whole chunk is validated before mutation.
pub fn Analyzer::push(
  self : Analyzer,
  samples : Array[Double],
) -> Result[Unit, MeterError] {
  if self.finished {
    return Err(AnalyzerFinished)
  }
  let channels = self.config.layout.channels()
  if samples.length() % channels != 0 {
    return Err(IncompleteFrame(samples.length(), channels))
  }
  for sample in samples {
    if sample - sample != 0.0 {
      return Err(NonFiniteSample)
    }
  }
  let input_frames = samples.length() / channels
  if input_frames > 2147483647 - self.frame_count ||
    samples.length() > 2147483647 - self.sample_count {
    return Err(CounterOverflow)
  }
  for sample in samples {
    if abs_value(sample) > 1.0e+150 {
      return Err(SampleMagnitudeTooLarge(sample))
    }
  }
  for frame in 0..<input_frames {
    let offset = frame * channels
    let mut frame_energy = 0.0
    for channel in 0..<channels {
      let sample = samples[offset + channel]
      let magnitude = abs_value(sample)
      if magnitude > self.sample_peak {
        self.sample_peak = magnitude
      }
      if magnitude > self.channel_sample_peaks[channel] {
        self.channel_sample_peaks[channel] = magnitude
      }
      let weighted = self.filters[channel].process(sample)
      let channel_weight = match self.config.layout.channel_weight(channel) {
        Some(weight) => weight
        None => 0.0
      }
      frame_energy = frame_energy + weighted * weighted * channel_weight
    }
    self.push_true_peak_frame(samples, offset, true)
    self.record_frame_energy(frame_energy)
  }
  self.sample_count = self.sample_count + samples.length()
  Ok(())
}

///|
/// Absolute value without introducing a dependency on a platform-specific intrinsic.
fn abs_value(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
/// Adds one frame to the FIR delay line and evaluates its four interpolation phases.
fn Analyzer::push_true_peak_frame(
  self : Analyzer,
  samples : Array[Double],
  offset : Int,
  has_input : Bool,
) -> Unit {
  let channels = self.config.layout.channels()
  for channel in 0..<channels {
    self.true_peak_ring[channel][self.true_peak_cursor] = if has_input {
      samples[offset + channel]
    } else {
      0.0
    }
  }
  // The zero-initialized ring supplies startup padding: evaluate every frame.
  for channel in 0..<channels {
    for phase in 0..<4 {
      let mut interpolated = 0.0
      for tap in 0..<12 {
        let ring_index = (self.true_peak_cursor + 1 + tap) % 12
        interpolated = interpolated +
          self.true_peak_ring[channel][ring_index] *
          self.peak_coefficients[phase][tap]
      }
      let magnitude = abs_value(interpolated)
      if magnitude > self.true_peak_max {
        self.true_peak_max = magnitude
      }
    }
  }
  self.true_peak_cursor = (self.true_peak_cursor + 1) % 12
}

///|
/// Retains window means and samples the two measurement time scales.
fn Analyzer::record_frame_energy(
  self : Analyzer,
  frame_energy : Double,
) -> Unit {
  self.latest_momentary_energy = self.momentary_window.push(frame_energy)
  self.latest_short_energy = self.short_window.push(frame_energy)
  self.frame_count = self.frame_count + 1
  if self.frame_count >= 19200 && (self.frame_count - 19200) % 4800 == 0 {
    match self.latest_momentary_energy {
      Some(energy) => self.integrated_distribution.push_energy(energy)
      None => ()
    }
    self.record_snapshot()
  }
  if self.frame_count >= 144000 && (self.frame_count - 144000) % 4800 == 0 {
    match self.latest_short_energy {
      Some(energy) => self.short_distribution.push_energy(energy)
      None => ()
    }
  }
}

///|
/// Converts weighted mean-square energy to LUFS/LKFS.
fn energy_to_lufs(energy : Double) -> Double {
  if energy <= 0.0 {
    -1000.0
  } else {
    -0.691 + 10.0 * @math.log10(energy)
  }
}

///|
/// Returns the latest complete 400 ms momentary window when available.
pub fn Analyzer::momentary_lufs(self : Analyzer) -> Double? {
  match self.latest_momentary_energy {
    Some(energy) => Some(energy_to_lufs(energy))
    None => None
  }
}

///|
/// Returns the latest complete 3 s short-term window when available.
pub fn Analyzer::short_term_lufs(self : Analyzer) -> Double? {
  match self.latest_short_energy {
    Some(energy) => Some(energy_to_lufs(energy))
    None => None
  }
}

///|
/// Returns the maximum Annex 2 four-phase FIR estimate in linear amplitude.
pub fn Analyzer::true_peak_linear(self : Analyzer) -> Double {
  self.true_peak_max
}

///|
/// Returns the largest absolute input sample in linear amplitude.
pub fn Analyzer::sample_peak_linear(self : Analyzer) -> Double {
  self.sample_peak
}

///|
/// Returns one channel's maximum absolute input sample, or None for an invalid index.
pub fn Analyzer::channel_sample_peak_linear(
  self : Analyzer,
  channel : Int,
) -> Double? {
  if channel < 0 || channel >= self.channel_sample_peaks.length() {
    None
  } else {
    Some(self.channel_sample_peaks[channel])
  }
}

///|
/// Returns a detached copy of the channel-ordered sample-peak array.
pub fn Analyzer::channel_sample_peaks_linear(self : Analyzer) -> Array[Double] {
  let result : Array[Double] = []
  for peak in self.channel_sample_peaks {
    result.push(peak)
  }
  result
}

///|
/// Returns the number of accepted interleaved samples.
pub fn Analyzer::sample_count(self : Analyzer) -> Int {
  self.sample_count
}

///|
/// Returns the number of accepted frames.
pub fn Analyzer::frame_count(self : Analyzer) -> Int {
  self.frame_count
}

///|
/// Returns the analyzed duration based on complete 48 kHz frames.
pub fn Analyzer::duration_seconds(self : Analyzer) -> Double {
  self.frame_count.to_double() / self.config.sample_rate.to_double()
}
