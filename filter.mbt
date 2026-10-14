///|
/// State for a direct-form biquad section.
priv struct BiquadState {
  mut x1 : Double
  mut x2 : Double
  mut y1 : Double
  mut y2 : Double
}

///|
/// Creates a biquad with zeroed delay elements.
fn BiquadState::new() -> BiquadState {
  { x1: 0.0, x2: 0.0, y1: 0.0, y2: 0.0, }
}

///|
/// Processes one sample through the 48 kHz K-weighting high shelf.
fn BiquadState::process_shelf(self : BiquadState, input : Double) -> Double {
  let output = 1.53512485958697 * input -
    2.69169618940638 * self.x1 +
    1.19839281085285 * self.x2 +
    1.69065929318241 * self.y1 -
    0.73248077421585 * self.y2
  self.x2 = self.x1
  self.x1 = input
  self.y2 = self.y1
  self.y1 = output
  output
}

///|
/// Processes one sample through the 48 kHz RLB high-pass section.
fn BiquadState::process_rlb(self : BiquadState, input : Double) -> Double {
  let output = input -
    2.0 * self.x1 +
    self.x2 +
    1.99004745483398 * self.y1 -
    0.99007225036621 * self.y2
  self.x2 = self.x1
  self.x1 = input
  self.y2 = self.y1
  self.y1 = output
  output
}

///|
/// Independent cascade state for one channel.
priv struct KWeightingState {
  shelf : BiquadState
  rlb : BiquadState
}

///|
/// Creates one channel's K-weighting path.
fn KWeightingState::new() -> KWeightingState {
  { shelf: BiquadState::new(), rlb: BiquadState::new(), }
}

///|
/// Applies the shelf then RLB high-pass section.
fn KWeightingState::process(self : KWeightingState, sample : Double) -> Double {
  self.rlb.process_rlb(self.shelf.process_shelf(sample))
}
