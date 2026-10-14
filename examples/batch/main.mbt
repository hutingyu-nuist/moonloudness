///|
fn number(value : Double?) -> String {
  match value {
    Some(x) => x.to_string()
    None => "null"
  }
}

///|
// Each asset gets fresh filter/window/gate state. The PCM block repeats every
// 100 ms, so reusing it is exact for the periodic 1 kHz input and bounds memory.
fn program(
  id : String,
  amplitude : Double,
  layout : @moonloudness.ChannelLayout,
  aggregator : @moonloudness.LoudnessAggregator,
) -> Unit {
  let config = match @moonloudness.MeterConfig::new(48000, layout) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  let block : Array[Double] = []
  for frame in 0..<4800 {
    let x = amplitude *
      @math.sin(2.0 * 3.141592653589793 * (frame % 48).to_double() / 48.0)
    for _ in 0..<layout.channels() {
      block.push(x)
    }
  }
  for _ in 0..<80 {
    match analyzer.push(block) {
      Ok(_) => ()
      Err(_) => panic()
    }
  }
  let report = analyzer.finish()
  // Illustrative delivery policy, not a broadcasting-standard acceptance test:
  // integrated target -23 +/-2 LU and maximum true peak -1 dBTP.
  let loudness_ok = match report.integrated_lufs() {
    Some(value) => value >= -25.0 && value <= -21.0
    None => false
  }
  let peak_ok = match report.true_peak_dbtp() {
    Some(value) => value <= -1.0
    None => false
  }
  match aggregator.add(report) {
    Ok(_) => ()
    Err(_) => panic()
  }
  println(
    "{\"kind\":\"program\",\"id\":\"" +
    id +
    "\",\"frames\":" +
    report.frame_count().to_string() +
    ",\"channels\":" +
    layout.channels().to_string() +
    ",\"integrated\":" +
    number(report.integrated_lufs()) +
    ",\"lra\":" +
    number(report.loudness_range_lu()) +
    ",\"sp\":" +
    number(report.sample_peak_dbfs()) +
    ",\"tp\":" +
    number(report.true_peak_dbtp()) +
    ",\"loudness_ok\":" +
    loudness_ok.to_string() +
    ",\"peak_ok\":" +
    peak_ok.to_string() +
    "}",
  )
}

///|
fn main {
  let aggregator = match @moonloudness.LoudnessAggregator::new(48000) {
    Ok(value) => value
    Err(_) => panic()
  }
  program("on_target", 0.1, @moonloudness.ChannelLayout::mono(), aggregator)
  program(
    "quiet_stereo",
    0.05,
    @moonloudness.ChannelLayout::stereo(),
    aggregator,
  )
  program("hot", 0.95, @moonloudness.ChannelLayout::mono(), aggregator)
  program("silence", 0.0, @moonloudness.ChannelLayout::mono(), aggregator)
  let batch = aggregator.finish()
  if batch.asset_count() != 4 || batch.frame_count() != 4 * 8 * 48000 {
    panic()
  }
  // Pooled distributions and maximum peaks of independent programs. This is
  // not concatenated PCM, does not invent cross-program windows, and must not
  // replace per-program QC with a single pooled normalization recommendation.
  println(
    "{\"kind\":\"aggregate\",\"assets\":" +
    batch.asset_count().to_string() +
    ",\"frames\":" +
    batch.frame_count().to_string() +
    ",\"duration\":" +
    batch.duration_seconds().to_string() +
    ",\"integrated\":" +
    number(batch.integrated_lufs()) +
    ",\"lra\":" +
    number(batch.loudness_range_lu()) +
    ",\"sp\":" +
    number(batch.sample_peak_dbfs()) +
    ",\"tp\":" +
    number(batch.true_peak_dbtp()) +
    "}",
  )
}
