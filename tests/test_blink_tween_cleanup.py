"""
Verify that the infinite blink tween on skip_lbl is properly killed
before reveal_container is freed in _start_phase_results(), preventing
freed-object errors during normal Phase2 → Phase3 transition.
"""
import pathlib, re, pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
RESULTS_GD = REPO_ROOT / "results.gd"


@pytest.fixture(scope="module")
def src():
    return RESULTS_GD.read_text(encoding="utf-8")


def _extract_func_body(src: str, func_name: str) -> str:
    """Extract the body of a GDScript function (up to the next top-level func)."""
    name_only = func_name.rstrip("()")
    pattern = re.compile(r"^func " + re.escape(name_only) + r"\s*\(", re.MULTILINE)
    m = pattern.search(src)
    assert m, f"Function {func_name} not found in results.gd"
    start = m.start()
    next_func = re.search(r"\nfunc ", src[start + 1:])
    end = start + 1 + next_func.start() if next_func else len(src)
    return src[start:end]


# ── 1. _blink_tween instance var is declared ─────────────────

def test_blink_tween_var_declared(src):
    assert "var _blink_tween" in src, \
        "results.gd must declare a _blink_tween instance variable"


# ── 2. _start_phase_reveal assigns _blink_tween ─────────────

def test_phase_reveal_assigns_blink_tween(src):
    body = _extract_func_body(src, "_start_phase_reveal")
    assert "_blink_tween" in body, \
        "_start_phase_reveal must assign the blink tween to _blink_tween"
    assert "_blink_tween = " in body or "_blink_tween =" in body, \
        "_start_phase_reveal must assign _blink_tween (not just reference it)"


# ── 3. _start_phase_reveal still uses set_loops() for blink ─

def test_phase_reveal_uses_set_loops(src):
    body = _extract_func_body(src, "_start_phase_reveal")
    assert "set_loops()" in body, \
        "Blink tween must use set_loops() for infinite looping"


# ── 4. _start_phase_results kills _blink_tween ──────────────

def test_phase_results_kills_blink_tween(src):
    body = _extract_func_body(src, "_start_phase_results")
    assert "_blink_tween" in body, \
        "_start_phase_results must reference _blink_tween to kill it"
    assert "_blink_tween.kill()" in body, \
        "_start_phase_results must call _blink_tween.kill()"


# ── 5. Blink tween is killed BEFORE reveal_container fade ───

def test_blink_killed_before_reveal_container_fade(src):
    body = _extract_func_body(src, "_start_phase_results")
    kill_pos = body.find("_blink_tween.kill()")
    fade_pos = body.find("reveal_container")
    # Find the reveal_container fade tween (the one that animates modulate:a)
    container_fade = body.find("reveal_container, \"modulate:a\"")
    if container_fade < 0:
        container_fade = body.find("reveal_container.queue_free")
    assert kill_pos >= 0, "_blink_tween.kill() not found"
    assert container_fade >= 0, "reveal_container fade/free not found"
    assert kill_pos < container_fade, \
        "_blink_tween must be killed BEFORE reveal_container is faded/freed"


# ── 6. _blink_tween is created via _tracked_tween ───────────
#    (so _skip_to_results still kills it via the _tweens array)

def test_blink_tween_is_tracked(src):
    body = _extract_func_body(src, "_start_phase_reveal")
    assert "_blink_tween = _tracked_tween()" in body, \
        "_blink_tween must be created via _tracked_tween() so skip still kills it"


# ── 7. _skip_to_results iterates _tweens (unchanged) ────────

def test_skip_still_kills_all_tweens(src):
    body = _extract_func_body(src, "_skip_to_results")
    assert "for tw in _tweens" in body, \
        "_skip_to_results must still iterate _tweens to kill all tracked tweens"
    assert "tw.kill()" in body, \
        "_skip_to_results must still call tw.kill() on each tracked tween"


# ── 8. is_instance_valid guard on _blink_tween ──────────────
#    (prevents crash if _start_phase_reveal was never called / tween already dead)

def test_blink_tween_has_validity_guard(src):
    body = _extract_func_body(src, "_start_phase_results")
    assert "is_instance_valid(_blink_tween)" in body, \
        "_start_phase_results must guard _blink_tween.kill() with is_instance_valid"


# ── 9. _blink_tween is nulled after kill ─────────────────────
#    (clean state for any subsequent checks)

def test_blink_tween_nulled_after_kill(src):
    body = _extract_func_body(src, "_start_phase_results")
    kill_pos = body.find("_blink_tween.kill()")
    null_pos = body.find("_blink_tween = null")
    assert kill_pos >= 0, "_blink_tween.kill() not found"
    assert null_pos >= 0, "_blink_tween = null not found"
    assert null_pos > kill_pos, \
        "_blink_tween must be set to null AFTER calling kill()"


# ── 10. _start_phase_results has double-entry guard ─────────
#    (prevents freed-object errors if called twice)

def test_phase_results_double_entry_guard(src):
    body = _extract_func_body(src, "_start_phase_results")
    assert "if phase == Phase.RESULTS" in body, \
        "_start_phase_results must have an early return guard for Phase.RESULTS"
    # The guard should appear before any tween/container operations
    guard_pos = body.find("if phase == Phase.RESULTS")
    kill_pos = body.find("_blink_tween")
    assert guard_pos < kill_pos, \
        "Phase.RESULTS guard must come before _blink_tween operations"
