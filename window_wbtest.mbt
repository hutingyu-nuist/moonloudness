///|
/// Re-sum current leaves independently, smallest first, without running state.
fn window_reference_mean(values : Array[Double]) -> Double {
  let sorted = values.copy()
  for index in 1..<sorted.length() {
    let value = sorted[index]
    let mut position = index
    while position > 0 && sorted[position - 1] > value {
      sorted[position] = sorted[position - 1]
      position = position - 1
    }
    sorted[position] = value
  }
  let mut sum = 0.0
  for value in sorted {
    sum = sum + value
  }
  sum / values.length().to_double()
}

///|
test "window_recovers_low_energy_immediately_when_dominant_leaf_expires" {
  let window = EnergyWindow::new(4)
  assert_eq(window.push(1.0e200), None)
  assert_eq(window.push(1.0e-100), None)
  assert_eq(window.push(1.0e-100), None)
  assert_eq(window.push(1.0e-100), Some(2.5e199))
  assert_eq(window.push(1.0e-100), Some(1.0e-100))
  for _ in 0..<40 {
    assert_eq(window.push(1.0e-100), Some(1.0e-100))
  }
}

///|
test "window_silence_has_no_negative_residue_after_high_dynamic_range" {
  let window = EnergyWindow::new(3)
  ignore(window.push(1.0e20))
  ignore(window.push(1.0))
  ignore(window.push(1.0))
  assert_eq(window.push(0.0), Some(2.0 / 3.0))
  assert_eq(window.push(0.0), Some(1.0 / 3.0))
  assert_eq(window.push(0.0), Some(0.0))
  for _ in 0..<30 {
    assert_eq(window.push(0.0), Some(0.0))
  }
}

///|
test "window_rollovers_match_independent_sorted_reference_sum" {
  for capacity in [1, 2, 3, 7, 16, 31, 257] {
    let window = EnergyWindow::new(capacity)
    let reference : Array[Double] = []
    for _ in 0..<capacity {
      reference.push(0.0)
    }
    for frame in 0..<(capacity * 20) {
      let value = match (frame * 17 + frame / 11) % 9 {
        0 => 1.0e200
        1 => 1.0e-200
        2 => 0.0
        3 => 1.0e16
        4 => 1.0e-16
        _ => (frame % 101).to_double() / 8.0
      }
      reference[frame % capacity] = value
      match window.push(value) {
        None => assert_true(frame < capacity - 1)
        Some(actual) => {
          assert_true(frame >= capacity - 1)
          let expected = window_reference_mean(reference)
          assert_true(actual >= 0.0)
          if expected == 0.0 {
            assert_eq(actual, 0.0)
          } else {
            assert_true(abs_value(actual / expected - 1.0) < 1.0e-14)
          }
        }
      }
    }
  }
}

///|
test "window_clear_discards_tree_history_and_requires_a_complete_new_span" {
  for capacity in [1, 3, 8, 17] {
    let window = EnergyWindow::new(capacity)
    for _ in 0..<(capacity * 3 + 1) {
      ignore(window.push(1.0e200))
    }
    window.clear()
    window.clear()
    for frame in 0..<capacity {
      assert_eq(
        window.push(0.125),
        if frame == capacity - 1 {
          Some(0.125)
        } else {
          None
        },
      )
    }
    ignore(window.push(1.0e200))
    window.clear()
    for frame in 0..<capacity {
      assert_eq(
        window.push(0.0),
        if frame == capacity - 1 {
          Some(0.0)
        } else {
          None
        },
      )
    }
  }
}

///|
test "window_production_spans_recover_after_a_complete_high_to_low_rollover" {
  for capacity in [19200, 144000] {
    let window = EnergyWindow::new(capacity)
    for _ in 0..<capacity {
      ignore(window.push(1.0e20))
    }
    for _ in 0..<(capacity - 1) {
      ignore(window.push(0.25))
    }
    assert_eq(window.push(0.25), Some(0.25))
    for _ in 0..<100 {
      assert_eq(window.push(0.25), Some(0.25))
    }
    window.clear()
    for _ in 0..<(capacity - 1) {
      assert_eq(window.push(0.0), None)
    }
    assert_eq(window.push(0.0), Some(0.0))
  }
}

///|
test "window_two_leaves_preserve_unit_energy_after_large_value_expires" {
  let window = EnergyWindow::new(2)
  assert_eq(window.push(1.0e30), None)
  assert_eq(window.push(1.0), Some(5.0e29))
  assert_eq(window.push(1.0), Some(1.0))
}
