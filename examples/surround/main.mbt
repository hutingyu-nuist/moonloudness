///|
fn main {
  let layout = @moonloudness.ChannelLayout::five_point_zero()
  let config = match @moonloudness.MeterConfig::new(48000, layout) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  let interleaved : Array[Double] = []
  let pi = 3.141592653589793
  for frame in 0..<48000 {
    let surround = 0.1 *
      @math.sin(2.0 * pi * 750.0 * frame.to_double() / 48000.0)
    interleaved.push(0.0)
    interleaved.push(0.0)
    interleaved.push(0.0)
    interleaved.push(surround)
    interleaved.push(0.0)
  }
  match analyzer.push(interleaved) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let report = analyzer.finish()
  let peaks = report.channel_sample_peaks_linear()
  for channel in 0..<layout.channels() {
    let label = match layout.channel_label(channel) {
      Some(value) => value
      None => "?"
    }
    println(label + " peak: " + peaks[channel].to_string())
  }
  match layout.channel_weight(3) {
    Some(value) => println("Loudness-weighted Ls gain: " + value.to_string())
    None => println("Loudness-weighted Ls gain: unavailable")
  }
  match report.integrated_lufs() {
    Some(value) => println("Program loudness (LUFS): " + value.to_string())
    None => println("Program loudness (LUFS): unavailable")
  }
}
