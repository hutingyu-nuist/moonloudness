///|
/// Fixed-capacity rolling mean over finite, nonnegative frame energy.
/// A pairwise tree is rebuilt along the replaced leaf's path on every push.
priv struct EnergyWindow {
  capacity : Int
  leaf_base : Int
  sums : Array[Double]
  mut cursor : Int
  mut filled : Int
}

///|
/// Creates an empty rolling window with a positive capacity.
fn EnergyWindow::new(capacity : Int) -> EnergyWindow {
  let mut leaf_base = 1
  while leaf_base < capacity {
    leaf_base = leaf_base * 2
  }
  let sums : Array[Double] = []
  for _ in 0..<(leaf_base * 2) {
    sums.push(0.0)
  }
  { capacity, leaf_base, sums, cursor: 0, filled: 0, }
}

///|
/// Inserts one energy value and returns a mean only once the window is complete.
fn EnergyWindow::push(self : EnergyWindow, value : Double) -> Double? {
  if self.filled < self.capacity {
    self.filled = self.filled + 1
  }
  let mut node = self.leaf_base + self.cursor
  self.sums[node] = value
  while node > 1 {
    node = node / 2
    // Never subtract an expired value from an already rounded large total.
    // Quiet leaves survive independently and reappear as loud leaves expire.
    self.sums[node] = self.sums[node * 2] + self.sums[node * 2 + 1]
  }
  self.cursor = (self.cursor + 1) % self.capacity
  if self.filled == self.capacity {
    Some(self.sums[1] / self.capacity.to_double())
  } else {
    None
  }
}

///|
/// Clears every tree node, including unused padding, without changing the span.
fn EnergyWindow::clear(self : EnergyWindow) -> Unit {
  for index in 0..<self.sums.length() {
    self.sums[index] = 0.0
  }
  self.cursor = 0
  self.filled = 0
}
