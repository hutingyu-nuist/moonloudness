///|
fn number(value : Double?) -> String {
  match value {
    Some(x) => x.to_string()
    None => "null"
  }
}

///|
// This formula is independently repeated in tools/validate_reference.py.
// Period reduction prevents large-angle/platform-dependent phase drift.
fn sample(id : String, frame : Int, channel : Int) -> Double {
  let pi = 3.141592653589793
  let phase = 2.0 * pi * (frame % 48).to_double() / 48.0
  match id {
    "steady" => 0.1 * @math.sin(phase)
    "gated" => {
      let second = frame / 48000
      let amplitude = if second < 4 {
        0.0
      } else if second < 12 {
        0.01
      } else if second < 20 {
        0.1
      } else if second < 28 {
        0.001
      } else if second < 36 {
        0.03
      } else {
        0.0
      }
      amplitude * @math.sin(phase)
    }
    "stereo" =>
      if channel == 0 {
        0.1 * @math.sin(phase)
      } else {
        0.05 * @math.sin(phase + pi / 2.0)
      }
    "surround" => if channel == 3 { 0.1 * @math.sin(phase) } else { 0.0 }
    "intersample" => {
      // 12 kHz, pi/4 offset: samples under-read the continuous sine maximum.
      // Linear 100 ms fades suppress start/end transient overshoot.
      let remaining = 8 * 48000 - 1 - frame
      let envelope = if frame < 4800 {
        frame.to_double() / 4800.0
      } else if remaining < 4800 {
        remaining.to_double() / 4800.0
      } else {
        1.0
      }
      0.8 *
      envelope *
      @math.sin(2.0 * pi * (frame % 4).to_double() / 4.0 + pi / 4.0)
    }
    _ => panic()
  }
}

///|
fn measure(
  id : String,
  seconds : Int,
  layout : @moonloudness.ChannelLayout,
) -> Unit {
  let config = match @moonloudness.MeterConfig::new(48000, layout) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  let mut energy = 0.0
  let mut sum = 0.0
  // Non-window-aligned chunks also exercise streaming boundary invariance.
  let frames = seconds * 48000
  let mut start = 0
  while start < frames {
    let stop = if start + 997 < frames { start + 997 } else { frames }
    let pcm : Array[Double] = []
    for frame in start..<stop {
      for channel in 0..<layout.channels() {
        let x = sample(id, frame, channel)
        pcm.push(x)
        sum = sum + x
        energy = energy + x * x
      }
    }
    match analyzer.push(pcm) {
      Ok(_) => ()
      Err(_) => panic()
    }
    start = stop
  }
  let report = analyzer.finish()
  println(
    "{\"id\":\"" +
    id +
    "\",\"frames\":" +
    report.frame_count().to_string() +
    ",\"channels\":" +
    layout.channels().to_string() +
    ",\"sum\":" +
    sum.to_string() +
    ",\"energy\":" +
    energy.to_string() +
    ",\"integrated\":" +
    number(report.integrated_lufs()) +
    ",\"lra\":" +
    number(report.loudness_range_lu()) +
    ",\"sp\":" +
    number(report.sample_peak_dbfs()) +
    ",\"tp\":" +
    number(report.true_peak_dbtp()) +
    "}",
  )
}

///|
fn main {
  measure("steady", 8, @moonloudness.ChannelLayout::mono())
  measure("gated", 40, @moonloudness.ChannelLayout::mono())
  measure("stereo", 8, @moonloudness.ChannelLayout::stereo())
  measure("surround", 8, @moonloudness.ChannelLayout::five_point_zero())
  measure("intersample", 8, @moonloudness.ChannelLayout::mono())
}
