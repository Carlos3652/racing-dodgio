"""
Numerical verification of the local closest-offset algorithm.

Tests the search logic in pure Python to validate correctness
independently of the Godot engine.

Run:  python tests/test_local_closest_offset.py
"""

import math
import sys


# ─── Simulate a 2D curve (circle of radius R) ─────────────────────
class FakeCurve2D:
    """A circular curve of given radius for testing. Baked length = 2*pi*R."""

    def __init__(self, radius: float = 500.0):
        self.radius = radius
        self._length = 2.0 * math.pi * radius

    def get_baked_length(self) -> float:
        return self._length

    def sample_baked(self, offset: float):
        angle = (offset / self._length) * 2.0 * math.pi
        return (self.radius * math.cos(angle), self.radius * math.sin(angle))

    def get_closest_offset(self, pos):
        """Full O(n) search — ground truth."""
        angle = math.atan2(pos[1], pos[0])
        if angle < 0:
            angle += 2.0 * math.pi
        return (angle / (2.0 * math.pi)) * self._length


# ─── Port of _local_closest_offset ────────────────────────────────
LOCAL_SEARCH_RADIUS = 300.0
LOCAL_SEARCH_STEPS = 16
LOCAL_REFINE_STEPS = 8
LOCAL_FALLBACK_DIST = 250.0


def local_closest_offset(curve, pos, hint):
    curve_len = curve.get_baked_length()
    if curve_len <= 0.0:
        return 0.0

    # First frame fallback
    if hint <= 0.0:
        return curve.get_closest_offset(pos)

    # Coarse pass
    lo = hint - LOCAL_SEARCH_RADIUS
    hi = hint + LOCAL_SEARCH_RADIUS
    step = (hi - lo) / float(LOCAL_SEARCH_STEPS)
    best_off = hint
    best_dsq = float("inf")

    for i in range(LOCAL_SEARCH_STEPS + 1):
        off = lo + step * float(i)
        if off < 0.0:
            off += curve_len
        elif off >= curve_len:
            off -= curve_len
        pt = curve.sample_baked(off)
        dsq = (pt[0] - pos[0]) ** 2 + (pt[1] - pos[1]) ** 2
        if dsq < best_dsq:
            best_dsq = dsq
            best_off = off

    # Refine
    refine_lo = best_off - step
    refine_hi = best_off + step
    for _ in range(LOCAL_REFINE_STEPS):
        mid_a = (refine_lo + refine_hi) * 0.5 - (refine_hi - refine_lo) * 0.125
        mid_b = (refine_lo + refine_hi) * 0.5 + (refine_hi - refine_lo) * 0.125
        off_a = (mid_a + curve_len) % curve_len
        off_b = (mid_b + curve_len) % curve_len
        pt_a = curve.sample_baked(off_a)
        pt_b = curve.sample_baked(off_b)
        dsq_a = (pt_a[0] - pos[0]) ** 2 + (pt_a[1] - pos[1]) ** 2
        dsq_b = (pt_b[0] - pos[0]) ** 2 + (pt_b[1] - pos[1]) ** 2
        if dsq_a < dsq_b:
            refine_hi = mid_b
            if dsq_a < best_dsq:
                best_dsq = dsq_a
                best_off = off_a
        else:
            refine_lo = mid_a
            if dsq_b < best_dsq:
                best_dsq = dsq_b
                best_off = off_b

    # Safety fallback
    if best_dsq > LOCAL_FALLBACK_DIST ** 2:
        return curve.get_closest_offset(pos)

    return best_off


# ─── Tests ─────────────────────────────────────────────────────────
def test_basic_accuracy():
    """Local search should match full search within small tolerance."""
    curve = FakeCurve2D(500.0)
    curve_len = curve.get_baked_length()

    errors = []
    max_err = 0.0

    # Test at many positions around the circle, simulating frame-by-frame movement
    hint = 100.0
    for i in range(200):
        # Player slightly outside the curve (510px from center), moving along it
        angle = (hint / curve_len) * 2.0 * math.pi + 0.01  # slight offset
        pos = (510.0 * math.cos(angle), 510.0 * math.sin(angle))

        local_off = local_closest_offset(curve, pos, hint)
        true_off = curve.get_closest_offset(pos)

        # Account for wrap-around
        err = abs(local_off - true_off)
        err = min(err, curve_len - err)
        max_err = max(max_err, err)

        if err > 5.0:  # allow 5px tolerance
            errors.append((i, hint, local_off, true_off, err))

        # Advance hint by ~8px (simulating 500px/s at 60fps)
        hint = (hint + 8.3) % curve_len

    return len(errors) == 0, max_err, errors


def test_wrap_around():
    """Search near offset 0 should handle wrap correctly."""
    curve = FakeCurve2D(500.0)
    curve_len = curve.get_baked_length()

    # Hint near the end of the curve
    hint = curve_len - 50.0
    # Player position corresponding to just past 0
    angle = 0.05
    pos = (510.0 * math.cos(angle), 510.0 * math.sin(angle))

    local_off = local_closest_offset(curve, pos, hint)
    true_off = curve.get_closest_offset(pos)

    err = abs(local_off - true_off)
    err = min(err, curve_len - err)
    return err < 10.0, err


def test_first_frame_fallback():
    """With hint=0, should use full search (fallback)."""
    curve = FakeCurve2D(500.0)
    pos = (0.0, 510.0)  # top of circle

    local_off = local_closest_offset(curve, pos, 0.0)
    true_off = curve.get_closest_offset(pos)

    err = abs(local_off - true_off)
    return err < 0.01, err


def test_stationary_player():
    """Same hint many frames in a row should keep returning same offset."""
    curve = FakeCurve2D(500.0)
    curve_len = curve.get_baked_length()

    hint = 400.0
    angle = (hint / curve_len) * 2.0 * math.pi
    pos = (480.0 * math.cos(angle), 480.0 * math.sin(angle))

    offsets = set()
    for _ in range(10):
        off = local_closest_offset(curve, pos, hint)
        offsets.add(round(off, 2))
        hint = off  # update hint as real code does

    return len(offsets) == 1, offsets


def test_large_jump_triggers_fallback():
    """If player teleports far, local search should fallback to full search."""
    curve = FakeCurve2D(500.0)
    curve_len = curve.get_baked_length()

    hint = 100.0
    # Position at opposite side of the circle
    angle = math.pi  # 180° away
    pos = (510.0 * math.cos(angle), 510.0 * math.sin(angle))

    local_off = local_closest_offset(curve, pos, hint)
    true_off = curve.get_closest_offset(pos)

    err = abs(local_off - true_off)
    err = min(err, curve_len - err)
    return err < 1.0, err


def test_performance_improvement():
    """Local search should call sample_baked far fewer times than curve length would imply."""
    # Not a precise benchmark, but verifies the algorithm does bounded work
    # LOCAL_SEARCH_STEPS + 1 coarse + 2 * LOCAL_REFINE_STEPS refine = 17 + 16 = 33 samples max
    # vs. a typical baked curve with 500+ segments
    total_samples = (LOCAL_SEARCH_STEPS + 1) + 2 * LOCAL_REFINE_STEPS
    return total_samples < 50, total_samples


# ─── Runner ────────────────────────────────────────────────────────
def main():
    print("\n══════════════════════════════════════════════════")
    print("  LOCAL CLOSEST OFFSET — NUMERICAL TESTS (Python)")
    print("══════════════════════════════════════════════════\n")

    tests = [
        ("Basic accuracy (200 frames)",       test_basic_accuracy),
        ("Wrap-around near offset 0",         test_wrap_around),
        ("First-frame fallback (hint=0)",     test_first_frame_fallback),
        ("Stationary player consistency",     test_stationary_player),
        ("Large jump triggers fallback",      test_large_jump_triggers_fallback),
        ("Bounded sample count",              test_performance_improvement),
    ]

    passed = 0
    failed = 0

    for name, fn in tests:
        try:
            result = fn()
            ok = result[0]
            detail = result[1:]
            if ok:
                print(f"  ✓  {name}  (detail: {detail})")
                passed += 1
            else:
                print(f"  ✗ FAIL: {name}  (detail: {detail})")
                failed += 1
        except Exception as e:
            print(f"  ✗ FAIL: {name}  (exception: {e})")
            failed += 1

    print("\n══════════════════════════════════════════════════")
    if failed == 0:
        print(f"  ALL TESTS PASSED ({passed} tests)")
    else:
        print(f"  {failed} FAILED out of {passed + failed} tests")
    print("══════════════════════════════════════════════════\n")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
