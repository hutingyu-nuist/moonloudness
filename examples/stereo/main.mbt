///|
fn main {
  let layout = @moonloudness.ChannelLayout::stereo()
  let config = match @moonloudness.MeterConfig::new(48000, layout) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = match
    @moonloudness.Analyzer::new_with_history_capacity(config, 8) {
    Ok(value) => value
    Err(_) => panic()
  }
  let pi = 3.141592653589793
  for chunk_index in 0..<10 {
    let interleaved : Array[Double] = []
    for local_frame in 0..<4800 {
      let frame = chunk_index * 4800 + local_frame
      let left = 0.12 *
        @math.sin(2.0 * pi * 997.0 * frame.to_double() / 48000.0)
      let right = 0.08 *
        @math.sin(2.0 * pi * 440.0 * frame.to_double() / 48000.0)
      interleaved.push(left)
      interleaved.push(right)
    }
    match analyzer.push(interleaved) {
      Ok(_) => ()
      Err(_) => panic()
    }
  }
  println("Duration (seconds): " + analyzer.duration_seconds().to_string())
  println("Retained points: " + analyzer.history().length().to_string())
  let report = analyzer.finish()
  match report.integrated_lufs() {
    Some(value) => println("Integrated loudness (LUFS): " + value.to_string())
    None => println("Integrated loudness (LUFS): unavailable")
  }
  match report.integrated_gate() {
    Some(gate) => {
      println("Blocks passing gate: " + gate.gated_block_count().to_string())
      println(
        "Applied gate (LUFS): " + gate.applied_threshold_lufs().to_string(),
      )
    }
    None => println("No blocks passed the absolute gate")
  }
}
