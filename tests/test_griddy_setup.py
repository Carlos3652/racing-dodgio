"""
Verify that _setup_griddy() no longer uses await (making _ready a coroutine)
and that griddy_kid.frame is guarded by a type check via _set_griddy_frame().
"""
import pathlib, re, pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
RACE_MGR = REPO_ROOT / "race_manager.gd"


@pytest.fixture(scope="module")
def src():
    return RACE_MGR.read_text(encoding="utf-8")


def _extract_func_body(src: str, func_name: str) -> str:
    """Extract the body of a GDScript function (up to the next top-level func)."""
    name_only = func_name.rstrip("()")
    pattern = re.compile(r"^func " + re.escape(name_only) + r"\s*\(", re.MULTILINE)
    m = pattern.search(src)
    assert m, f"Function {func_name} not found in race_manager.gd"
    start = m.start()
    next_func = re.search(r"\nfunc ", src[start + 1:])
    end = start + 1 + next_func.start() if next_func else len(src)
    return src[start:end]


# ── 1. _setup_griddy must NOT contain await ──────────────────────────

def test_setup_griddy_no_await(src):
    """_setup_griddy must be synchronous — no await keyword allowed."""
    body = _extract_func_body(src, "_setup_griddy()")
    # Strip comments before checking for await
    lines = [l for l in body.splitlines() if not l.strip().startswith("#")]
    code_only = "\n".join(lines)
    assert "await" not in code_only, \
        "_setup_griddy() still contains 'await', making _ready a coroutine"


# ── 2. _setup_griddy uses process_frame signal instead ───────────────

def test_setup_griddy_uses_signal_callback(src):
    """_setup_griddy must connect to process_frame via signal, not await."""
    body = _extract_func_body(src, "_setup_griddy()")
    assert "process_frame.connect(" in body, \
        "_setup_griddy() must connect to process_frame signal for deferred layout"


# ── 3. _on_griddy_layout_tick exists and disconnects ─────────────────

def test_griddy_layout_tick_exists(src):
    assert "func _on_griddy_layout_tick()" in src

def test_griddy_layout_tick_disconnects(src):
    body = _extract_func_body(src, "_on_griddy_layout_tick()")
    assert "process_frame.disconnect(" in body, \
        "_on_griddy_layout_tick must disconnect itself after completing"


# ── 4. _on_griddy_layout_tick has is_inside_tree guard ───────────────

def test_griddy_layout_tick_tree_guard(src):
    body = _extract_func_body(src, "_on_griddy_layout_tick()")
    assert "is_inside_tree()" in body, \
        "_on_griddy_layout_tick must check is_inside_tree before accessing scene"


# ── 5. _on_griddy_layout_tick calls _show_intro ─────────────────────

def test_griddy_layout_tick_calls_show_intro(src):
    body = _extract_func_body(src, "_on_griddy_layout_tick()")
    assert "_show_intro()" in body, \
        "_on_griddy_layout_tick must call _show_intro after positioning"


# ── 6. _set_griddy_frame helper exists ───────────────────────────────

def test_set_griddy_frame_exists(src):
    assert "func _set_griddy_frame(" in src


# ── 7. _set_griddy_frame checks AnimatedSprite2D or Sprite2D ────────

def test_set_griddy_frame_type_check(src):
    body = _extract_func_body(src, "_set_griddy_frame(")
    assert "AnimatedSprite2D" in body, \
        "_set_griddy_frame must check for AnimatedSprite2D"
    assert "Sprite2D" in body, \
        "_set_griddy_frame must check for Sprite2D"


# ── 8. _set_griddy_frame warns on wrong type ────────────────────────

def test_set_griddy_frame_warns(src):
    body = _extract_func_body(src, "_set_griddy_frame(")
    assert "push_warning" in body, \
        "_set_griddy_frame must push_warning when type is unexpected"


# ── 9. No direct griddy_kid.frame assignment remains ────────────────

def test_no_direct_frame_assignment(src):
    """All .frame assignments must go through _set_griddy_frame."""
    # Find all griddy_kid.frame = assignments outside _set_griddy_frame
    set_frame_body = _extract_func_body(src, "_set_griddy_frame(")
    src_without_helper = src.replace(set_frame_body, "")
    matches = re.findall(r"griddy_kid\.frame\s*=", src_without_helper)
    assert len(matches) == 0, \
        f"Found {len(matches)} direct griddy_kid.frame assignment(s) outside _set_griddy_frame"


# ── 10. _setup_griddy calls _set_griddy_frame ───────────────────────

def test_setup_griddy_calls_helper(src):
    body = _extract_func_body(src, "_setup_griddy()")
    assert "_set_griddy_frame(" in body


# ── 11. _on_griddy_finished calls _set_griddy_frame ─────────────────

def test_on_griddy_finished_calls_helper(src):
    body = _extract_func_body(src, "_on_griddy_finished(")
    assert "_set_griddy_frame(" in body


# ── 12. _griddy_defer_frames is declared ─────────────────────────────

def test_griddy_defer_frames_declared(src):
    assert re.search(r"^var _griddy_defer_frames", src, re.MULTILINE), \
        "_griddy_defer_frames must be declared as instance variable"


# ── 13. _ready does NOT contain await ────────────────────────────────

def test_ready_not_coroutine(src):
    """_ready must remain synchronous (no await)."""
    body = _extract_func_body(src, "_ready()")
    lines = [l for l in body.splitlines() if not l.strip().startswith("#")]
    code_only = "\n".join(lines)
    assert "await" not in code_only, \
        "_ready() contains 'await' — it must stay synchronous"
