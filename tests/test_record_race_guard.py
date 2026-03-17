"""
Verify that record_race() was moved out of _build_results() into _record_race_once()
with a proper guard, called from _ready().
"""
import pathlib, re, pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
RESULTS_GD = REPO_ROOT / "results.gd"

@pytest.fixture(scope="module")
def src():
    return RESULTS_GD.read_text(encoding="utf-8")


def _extract_func_body(src: str, func_name: str) -> str:
    """Extract the body of a GDScript function (up to the next top-level func)."""
    # Match "func _name(" at start of line
    name_only = func_name.rstrip("()")
    pattern = re.compile(r"^func " + re.escape(name_only) + r"\s*\(", re.MULTILINE)
    m = pattern.search(src)
    assert m, f"Function {func_name} not found in results.gd"
    start = m.start()
    # Find next top-level func (line starting with "func ")
    next_func = re.search(r"\nfunc ", src[start + 1:])
    end = start + 1 + next_func.start() if next_func else len(src)
    return src[start:end]


# ── 1. _record_race_once() exists ─────────────────────────

def test_record_race_once_exists(src):
    assert "func _record_race_once()" in src


# ── 2. _ready() calls _record_race_once() ────────────────

def test_ready_calls_record_race_once(src):
    body = _extract_func_body(src, "_ready()")
    assert "_record_race_once()" in body


# ── 3. _record_race_once() has _result_saved guard ───────

def test_record_race_once_has_guard(src):
    body = _extract_func_body(src, "_record_race_once()")
    assert "_result_saved" in body, \
        "_record_race_once() must use _result_saved guard (not _race_recorded)"


# ── 3b. _record_race_once() does NOT touch _race_recorded ─

def test_record_race_once_does_not_touch_race_recorded(src):
    body = _extract_func_body(src, "_record_race_once()")
    assert "_race_recorded" not in body, \
        "_record_race_once() must NOT reference _race_recorded — that flag is for button handlers only"


# ── 4. _record_race_once() calls Records.record_race ─────

def test_record_race_once_calls_records(src):
    body = _extract_func_body(src, "_record_race_once()")
    assert "Records.record_race(" in body


# ── 5. _build_results() does NOT call Records.record_race ─

def test_build_results_no_record_race(src):
    body = _extract_func_body(src, "_build_results()")
    assert "Records.record_race(" not in body, \
        "_build_results() still calls Records.record_race — double-record risk!"


# ── 6. _build_results() does NOT call Records.get_best_time ─

def test_build_results_no_get_best_time(src):
    body = _extract_func_body(src, "_build_results()")
    assert "Records.get_best_time(" not in body, \
        "_build_results() should use cached _prev_best"


# ── 7. _get_player_position helper exists ─────────────────

def test_get_player_position_exists(src):
    assert "func _get_player_position(" in src


# ── 8. Instance vars _is_pb and _prev_best declared ──────

def test_is_pb_declared(src):
    assert "var _is_pb" in src


def test_prev_best_declared(src):
    assert "var _prev_best" in src


# ── 9. _build_results uses cached values ─────────────────

def test_build_results_uses_cached_is_pb(src):
    body = _extract_func_body(src, "_build_results()")
    assert "_is_pb" in body


def test_build_results_uses_cached_prev_best(src):
    body = _extract_func_body(src, "_build_results()")
    assert "_prev_best" in body


# ── 10. _record_race_once reads prev best before recording ─

def test_record_once_reads_best_before_record(src):
    body = _extract_func_body(src, "_record_race_once()")
    best_pos = body.find("get_best_time")
    record_pos = body.find("Records.record_race(")
    assert best_pos >= 0 and record_pos >= 0, \
        "_record_race_once must call both get_best_time and record_race"
    assert best_pos < record_pos, \
        "get_best_time must be called BEFORE record_race to capture old value"
