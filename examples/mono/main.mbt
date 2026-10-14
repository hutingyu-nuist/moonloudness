///|
fn main {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  let samples : Array[Double] = []
  let pi = 3.141592653589793
  for frame in 0..<48000 {
    let phase = 2.0 * pi * 1000.0 * frame.to_double() / 48000.0
    samples.push(0.1 * @math.sin(phase))
  }
  match analyzer.push(samples) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let report = analyzer.finish()
  match report.integrated_lufs() {
    Some(value) => println("Integrated loudness (LUFS): " + value.to_string())
    None => println("Integrated loudness (LUFS): unavailable")
  }
  match report.sample_peak_dbfs() {
    Some(value) => println("Sample peak (dBFS): " + value.to_string())
    None => println("Sample peak (dBFS): unavailable")
  }
  match report.true_peak_dbtp() {
    Some(value) => println("True peak (dBTP): " + value.to_string())
    None => println("True peak (dBTP): unavailable")
  }
  let plan = match report.normalization_plan(-16.0, -1.0) {
    Ok(value) => value
    Err(_) => panic()
  }
  println("Advisory gain (dB): " + plan.applied_gain_db().to_string())
}
