///|
/// Transfer-function impulse response, computed as a finite sequence rather
/// than using the production mutable biquad state.
fn filter_reference_impulse(
  b : Array[Double],
  a : Array[Double],
  frames : Int,
) -> Array[Double] {
  let response : Array[Double] = []
  for frame in 0..<frames {
    let mut output = if frame < b.length() { b[frame] } else { 0.0 }
    for delay in 1..<a.length() {
      if frame >= delay {
        output = output - a[delay] * response[frame - delay]
      }
    }
    response.push(output)
  }
  response
}

///|
/// Analytic squared magnitude of B(exp(-jw))/A(exp(-jw)).
fn filter_reference_gain_squared(
  b : Array[Double],
  a : Array[Double],
  frequency : Double,
) -> Double {
  let angle = 2.0 * 3.141592653589793 * frequency / 48000.0
  let mut numerator_real = 0.0
  let mut numerator_imag = 0.0
  let mut denominator_real = 0.0
  let mut denominator_imag = 0.0
  for index in 0..<b.length() {
    let phase = angle * index.to_double()
    numerator_real = numerator_real + b[index] * @math.cos(phase)
    numerator_imag = numerator_imag - b[index] * @math.sin(phase)
  }
  for index in 0..<a.length() {
    let phase = angle * index.to_double()
    denominator_real = denominator_real + a[index] * @math.cos(phase)
    denominator_imag = denominator_imag - a[index] * @math.sin(phase)
  }
  (numerator_real * numerator_real + numerator_imag * numerator_imag) /
  (denominator_real * denominator_real + denominator_imag * denominator_imag)
}

///|
test "k_filter_impulse_matches_independent_section_convolution" {
  let frames = 512
  let shelf = filter_reference_impulse(
    [1.53512485958697, -2.69169618940638, 1.19839281085285],
    [1.0, -1.69065929318241, 0.73248077421585],
    frames,
  )
  let rlb = filter_reference_impulse(
    [1.0, -2.0, 1.0],
    [1.0, -1.99004745483398, 0.99007225036621],
    frames,
  )
  let filter = KWeightingState::new()
  for frame in 0..<frames {
    let mut expected = 0.0
    for index in 0..<(frame + 1) {
      expected = expected + shelf[index] * rlb[frame - index]
    }
    let actual = filter.process(if frame == 0 { 1.0 } else { 0.0 })
    assert_true(abs_value(actual - expected) < 2.0e-12)
  }
}

///|
test "k_filter_first_impulse_samples_have_analytic_values" {
  let filter = KWeightingState::new()
  let b0 = 1.53512485958697
  assert_eq(filter.process(1.0), b0)
  let shelf_h1 = -2.69169618940638 + 1.69065929318241 * b0
  let rlb_h1 = -2.0 + 1.99004745483398
  assert_true(
    abs_value(filter.process(0.0) - (shelf_h1 + b0 * rlb_h1)) < 1.0e-15,
  )
}

///|
test "k_filter_dc_step_settles_to_unity_shelf_and_zero_high_pass" {
  let shelf = BiquadState::new()
  let rlb = BiquadState::new()
  let cascade = KWeightingState::new()
  let expected_shelf_dc = (
      1.53512485958697 - 2.69169618940638 + 1.19839281085285
    ) /
    (1.0 - 1.69065929318241 + 0.73248077421585)
  assert_true(abs_value(expected_shelf_dc - 1.0) < 1.0e-12)
  for frame in 0..<24000 {
    let shelf_out = shelf.process_shelf(0.25)
    let rlb_out = rlb.process_rlb(0.25)
    let cascade_out = cascade.process(0.25)
    if frame >= 12000 {
      assert_true(abs_value(shelf_out - 0.25 * expected_shelf_dc) < 1.0e-12)
      assert_true(abs_value(rlb_out) < 1.0e-10)
      assert_true(abs_value(cascade_out) < 1.0e-10)
    }
  }
}

///|
test "k_filter_steady_state_gain_matches_analytic_transfer_function" {
  for frequency in [20.0, 60.0, 1000.0, 10000.0, 20000.0, 24000.0] {
    let shelf_gain = filter_reference_gain_squared(
      [1.53512485958697, -2.69169618940638, 1.19839281085285],
      [1.0, -1.69065929318241, 0.73248077421585],
      frequency,
    )
    let rlb_gain = filter_reference_gain_squared(
      [1.0, -2.0, 1.0],
      [1.0, -1.99004745483398, 0.99007225036621],
      frequency,
    )
    let expected = shelf_gain * rlb_gain
    let filter = KWeightingState::new()
    let mut input_energy = 0.0
    let mut output_energy = 0.0
    for frame in 0..<96000 {
      // Integer frequencies and a 48,000-frame observation interval remove
      // partial-cycle bias. Cosine also excites the Nyquist endpoint.
      let sample = 0.125 *
        @math.cos(
          2.0 * 3.141592653589793 * frequency * frame.to_double() / 48000.0,
        )
      let output = filter.process(sample)
      if frame >= 48000 {
        input_energy = input_energy + sample * sample
        output_energy = output_energy + output * output
      }
    }
    let measured = output_energy / input_energy
    assert_true(abs_value(measured / expected - 1.0) < 1.0e-8)
  }
}

///|
test "k_filter_new_state_has_no_shared_impulse_history" {
  let driven = KWeightingState::new()
  let silent = KWeightingState::new()
  for frame in 0..<1000 {
    ignore(driven.process(if frame == 0 { 1.0 } else { 0.0 }))
    assert_eq(silent.process(0.0), 0.0)
  }
  let fresh = KWeightingState::new()
  assert_eq(fresh.process(1.0), 1.53512485958697)
}
