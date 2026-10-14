///|
/// Fixed-capacity rolling mean over frame energy.
priv struct EnergyWindow {
  capacity : Int
  values : Array[Double]
  mut cursor : Int
  mut filled : Int
  mut total : Double
}

///|
/// Creates an empty rolling window with a positive capacity.
fn EnergyWindow::new(capacity : Int) -> EnergyWindow {
  let values : Array[Double] = []
  for _ in 0..<capacity {
    values.push(0.0)
  }
  { capacity, values, cursor: 0, filled: 0, total: 0.0, }
}

///|
/// Inserts one energy value and returns a mean only once the window is complete.
fn EnergyWindow::push(self : EnergyWindow, value : Double) -> Double? {
  if self.filled == self.capacity {
    self.total = self.total - self.values[self.cursor]
  } else {
    self.filled = self.filled + 1
  }
  self.values[self.cursor] = value
  self.total = self.total + value
  self.cursor = (self.cursor + 1) % self.capacity
  if self.filled == self.capacity {
    Some(self.total / self.capacity.to_double())
  } else {
    None
  }
}

///|
/// Clears retained energy without changing the configured span.
fn EnergyWindow::clear(self : EnergyWindow) -> Unit {
  for index in 0..<self.capacity {
    self.values[index] = 0.0
  }
  self.cursor = 0
  self.filled = 0
  self.total = 0.0
}
