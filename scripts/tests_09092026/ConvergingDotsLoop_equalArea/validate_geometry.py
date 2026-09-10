"""Independent NumPy checks of the MATLAB position-map mathematics.

This does not execute MATLAB or Psychtoolbox. Run with Python 3 and NumPy.
Writes validation_results.json beside this script.
"""
from __future__ import annotations
import json
from pathlib import Path
import numpy as np


def position(phase: np.ndarray, beta: np.ndarray, half_height: float = 45.0):
    z = 2.0 * phase - 1.0
    q = np.sqrt(np.maximum(0.0, 1.0 - z*z))
    azimuth = np.mod(np.degrees(np.arctan2(q*np.cos(beta), z)), 360.0)
    elevation = half_height*q*np.sin(beta)
    return azimuth, elevation


def wrapped_difference_deg(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return (a-b+180.0) % 360.0 - 180.0


def main() -> None:
    rng = np.random.default_rng(20260909)
    n = 1_000_000
    phase = rng.random(n)
    beta = 2*np.pi*rng.random(n)
    az, el = position(phase, beta)
    edges = [np.linspace(0, 360, 37), np.linspace(-45, 45, 10)]
    counts, _, _ = np.histogram2d(az, el, bins=edges)
    expected = n/counts.size
    front = int(np.count_nonzero((az < 30) | (az >= 330)))
    back = int(np.count_nonzero((az >= 150) & (az < 210)))
    assert np.isfinite(az).all() and np.isfinite(el).all()
    assert ((az >= 0) & (az < 360)).all() and (np.abs(el) <= 45).all()
    assert np.max(np.abs(counts/expected-1)) < 0.15
    assert abs(front/back-1) < 0.025

    # Translation modulo one preserves the phase measure.
    az2, el2 = position(np.mod(phase+0.371, 1), beta)
    after_counts, _, _ = np.histogram2d(az2, el2, bins=edges)
    assert np.max(np.abs(after_counts/expected-1)) < 0.15

    # Endpoint identities.
    a, e = position(np.array([0.0, 1.0]), np.array([0.31, 2.71]))
    assert np.allclose(a, [180, 0], atol=1e-12)
    assert np.allclose(e, [0, 0], atol=1e-12)

    # The constant screen-area Jacobian (azimuth radians, elevation degrees).
    p = rng.uniform(.01, .99, 10_000)
    b = rng.uniform(0, 2*np.pi, 10_000)
    d = 1e-6
    ap, ep = position(p+d, b)
    am, em = position(p-d, b)
    bp, fp = position(p, b+d)
    bm, fm = position(p, b-d)
    dap = np.radians(wrapped_difference_deg(ap, am))/(2*d)
    dab = np.radians(wrapped_difference_deg(bp, bm))/(2*d)
    jacobian = dap*(fp-fm)/(2*d)-dab*(ep-em)/(2*d)
    jacobian_error = float(np.max(np.abs(np.abs(jacobian)-90)))
    assert jacobian_error < 1e-2

    # Actual bearing distance to the front must decrease, not just an
    # auxiliary-sphere distance.
    p = np.linspace(1e-8, 1-1e-8, 1001)[:, None]
    b = rng.uniform(0, 2*np.pi, 2_000)[None, :]
    a, e = position(p, b)
    distance = np.arccos(np.clip(np.cos(np.radians(e))*np.cos(np.radians(a)), -1, 1))
    max_increase = float(np.max(np.diff(distance, axis=0)))
    assert max_increase <= 1e-10

    # Optional physical embedding, bounded between original radial limits.
    r_min, r_max, r_target = 61.0, 91.5, 76.25
    p = rng.random(20_000)
    b = rng.uniform(0, 2*np.pi, p.size)
    spawn_r = (r_min**3+rng.random(p.size)*(r_max**3-r_min**3))**(1/3)
    radius = (1-p)*spawn_r+p*r_target
    a, e = position(p, b)
    xyz = radius*np.array([np.cos(np.radians(e))*np.sin(np.radians(a)),
                           np.sin(np.radians(e)),
                           np.cos(np.radians(e))*np.cos(np.radians(a))])
    recovered_r = np.linalg.norm(xyz, axis=0)
    radius_error = float(np.max(np.abs(recovered_r-radius)))
    assert radius_error < 1e-10
    assert ((recovered_r >= r_min-1e-10) & (recovered_r <= r_max+1e-10)).all()

    # Multiple-wrap / overshoot behavior of the direct phase clock.
    p0 = np.array([0.99, 0.25, 0.75])
    delta = 2.03
    laps = np.floor(p0+delta)
    final_p = np.mod(p0+delta, 1)
    assert np.allclose(final_p, [0.02, 0.28, 0.78])
    assert np.array_equal(laps, [3, 2, 2])

    report = {
        "implementation_executed": "Independent NumPy translation of numerical geometry, not MATLAB",
        "numpy_version": np.__version__,
        "random_seed": 20260909,
        "samples": n,
        "screen_bins": list(counts.shape),
        "expected_count_per_bin": expected,
        "minimum_bin_count": int(counts.min()),
        "maximum_bin_count": int(counts.max()),
        "relative_bin_rms": float(counts.std()/expected),
        "front_sector_degrees": "[-30, 30) around 0; all elevations",
        "back_sector_degrees": "[150, 210); all elevations",
        "front_count": front,
        "back_count": back,
        "front_back_ratio": front/back,
        "expected_absolute_jacobian_rad_times_deg": 90.0,
        "maximum_absolute_jacobian_error": jacobian_error,
        "maximum_step_in_target_angular_distance_radians": max_increase,
        "maximum_radius_reconstruction_error_cm": radius_error,
        "endpoint_test_passed": True,
        "stationarity_after_wrap_test_passed": True,
        "overshoot_and_multiple_wrap_test_passed": True,
        "radial_shell_bounds_test_passed": True,
        "monotonic_approach_test_passed": True,
        "matlab_executed": False,
        "psychtoolbox_executed": False,
        "arena_hardware_tested": False,
    }
    output = Path(__file__).with_name("validation_results.json")
    output.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
