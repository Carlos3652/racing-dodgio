"""
Static analysis tests for the 3 P1 bug fixes:
  rd-high-01: boost_bar theme override set every frame
  rd-high-05: AI-vs-AI bump ignores bump_radius_bonus
  rd-high-06: First 1st-place time never written to records
"""
import pathlib, re, pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
RACE_MGR = REPO_ROOT / "race_manager.gd"
RECORDS  = REPO_ROOT / "records.gd"


@pytest.fixture(scope="module")
def mgr_src():
    return RACE_MGR.read_text(encoding="utf-8")


@pytest.fixture(scope="module")
def rec_src():
    return RECORDS.read_text(encoding="utf-8")


def _extract_func_body(src: str, func_name: str) -> str:
    """Extract the body of a GDScript function (up to the next top-level func)."""
    name_only = func_name.rstrip("()")
    pattern = re.compile(r"^func " + re.escape(name_only) + r"\s*\(", re.MULTILINE)
    m = pattern.search(src)
    assert m, f"Function {func_name} not found"
    start = m.start()
    next_func = re.search(r"\nfunc ", src[start + 1:])
    end = start + 1 + next_func.start() if next_func else len(src)
    return src[start:end]


# ── rd-high-01: boost_bar theme override should not fire every frame ──────────

class TestBoostBarDirtyFlag:
    def test_boost_bar_state_var_declared(self, mgr_src):
        """A state-tracking variable for the boost bar must be declared."""
        assert "_boost_bar_state" in mgr_src, \
            "_boost_bar_state variable not found in race_manager.gd"

    def test_crash_stylebox_override_guarded(self, mgr_src):
        """add_theme_stylebox_override for crash should be inside a state-change guard."""
        # Find the actual call site: add_theme_stylebox_override("fill", _crash_style)
        idx = mgr_src.find('add_theme_stylebox_override("fill", _crash_style)')
        assert idx >= 0, "add_theme_stylebox_override for _crash_style not found"
        region = mgr_src[max(0, idx - 300):idx + 50]
        assert "_boost_bar_state" in region, \
            "add_theme_stylebox_override for crash is not guarded by _boost_bar_state check"

    def test_boost_stylebox_override_guarded(self, mgr_src):
        """add_theme_stylebox_override for boost should be inside a state-change guard."""
        # Find the actual call site: add_theme_stylebox_override("fill", _boost_style)
        idx = mgr_src.find('add_theme_stylebox_override("fill", _boost_style)')
        assert idx >= 0, "add_theme_stylebox_override for _boost_style not found"
        region = mgr_src[max(0, idx - 300):idx + 50]
        assert "_boost_bar_state" in region, \
            "add_theme_stylebox_override for boost is not guarded by _boost_bar_state check"

    def test_max_value_not_set_every_frame_crash(self, mgr_src):
        """boost_bar.max_value assignment for crash state must be inside a guard."""
        # Find max_value = player.STUN_DURATION
        idx = mgr_src.find("player.STUN_DURATION")
        assert idx >= 0, "player.STUN_DURATION assignment not found"
        region = mgr_src[max(0, idx - 300):idx + 50]
        assert "_boost_bar_state" in region, \
            "boost_bar.max_value (STUN_DURATION) is set outside a state-change guard"

    def test_max_value_not_set_every_frame_boost(self, mgr_src):
        """boost_bar.max_value assignment for boost state must be inside a guard."""
        idx = mgr_src.find("player.BOOST_DURATION")
        assert idx >= 0, "player.BOOST_DURATION assignment not found"
        region = mgr_src[max(0, idx - 300):idx + 50]
        assert "_boost_bar_state" in region, \
            "boost_bar.max_value (BOOST_DURATION) is set outside a state-change guard"

    def test_boost_bar_state_transitions_crash(self, mgr_src):
        """State variable must be assigned to 'crash' string."""
        assert '"crash"' in mgr_src or "'crash'" in mgr_src, \
            "_boost_bar_state never assigned 'crash'"

    def test_boost_bar_state_transitions_boost(self, mgr_src):
        """State variable must be assigned to 'boost' string."""
        assert '"boost"' in mgr_src or "'boost'" in mgr_src, \
            "_boost_bar_state never assigned 'boost'"

    def test_boost_bar_state_transitions_none(self, mgr_src):
        """State variable must be assigned to 'none' string."""
        assert '"none"' in mgr_src or "'none'" in mgr_src, \
            "_boost_bar_state never assigned 'none'"


# ── rd-high-05: AI-vs-AI bump must respect bump_radius_bonus ─────────────────

class TestAiVsAiBumpRadius:
    def test_ai_vs_ai_uses_bump_radius_bonus(self, mgr_src):
        """AI-vs-AI collision check must include bump_radius_bonus."""
        # Find the ai-vs-ai bump section and check bump_radius_bonus is present
        idx = mgr_src.find("# AI vs AI")
        assert idx >= 0, "AI vs AI section not found in race_manager.gd"
        section = mgr_src[idx:idx + 500]
        assert "bump_radius_bonus" in section, \
            "AI-vs-AI bump check does not use bump_radius_bonus"

    def test_ai_vs_ai_effective_dist_var(self, mgr_src):
        """AI-vs-AI should compute an effective bump distance (not raw BUMP_DIST)."""
        idx = mgr_src.find("# AI vs AI")
        assert idx >= 0
        section = mgr_src[idx:idx + 500]
        assert "effective_bump_dist" in section, \
            "AI-vs-AI does not compute effective_bump_dist variable"

    def test_ai_vs_ai_uses_max_for_bonus(self, mgr_src):
        """AI-vs-AI should take the max of both cars' bonuses."""
        idx = mgr_src.find("# AI vs AI")
        assert idx >= 0
        section = mgr_src[idx:idx + 500]
        assert "max(" in section, \
            "AI-vs-AI should use max() to pick the larger bump_radius_bonus"

    def test_player_vs_ai_still_uses_bonus(self, mgr_src):
        """Player-vs-AI bump check must still use bump_radius_bonus (regression)."""
        # Anchor to the Player vs AI section header and inspect that specific block
        idx = mgr_src.find("# Player vs AI")
        assert idx >= 0, "Player vs AI section not found in race_manager.gd"
        # Grab the player-vs-AI block (before the AI vs AI section)
        ai_vs_ai_idx = mgr_src.find("# AI vs AI", idx)
        assert ai_vs_ai_idx > idx, "AI vs AI section not found after Player vs AI"
        section = mgr_src[idx:ai_vs_ai_idx]
        assert "effective_bump_dist" in section, \
            "Player-vs-AI section does not compute effective_bump_dist"
        assert "bump_radius_bonus" in section, \
            "Player-vs-AI section does not use bump_radius_bonus"


# ── rd-high-06: First 1st-place time written to records ──────────────────────

class TestFirstPlaceTimeRecord:
    def test_new_track_first_place_uses_conditional_time(self, rec_src):
        """New track branch must not unconditionally set best_time = time."""
        idx = rec_src.find("not data.tracks.has(track_name)")
        assert idx >= 0, "new-track branch not found in records.gd"
        # Extract up to the 'else:' that closes this if block (~5 lines)
        section = rec_src[idx:idx + 400]
        # Should NOT have a plain best_time = time (only conditional or via variable)
        # The fix uses a ternary: time if position == 1 else INF
        assert "position == 1" in section, \
            "New track branch must guard best_time with position == 1 check"

    def test_new_track_non_first_uses_inf(self, rec_src):
        """Non-1st-place new track entry must use INF for best_time."""
        idx = rec_src.find("not data.tracks.has(track_name)")
        assert idx >= 0
        section = rec_src[idx:idx + 400]
        assert "INF" in section, \
            "New track branch must use INF for best_time when position != 1"

    def test_new_track_best_time_not_raw_time(self, rec_src):
        """New track branch must not directly use `best_time = time` (unguarded)."""
        idx = rec_src.find("not data.tracks.has(track_name)")
        assert idx >= 0
        # Find the dict literal inside this branch
        end = rec_src.find("else:", idx)
        section = rec_src[idx:end] if end > idx else rec_src[idx:idx + 400]
        # Should NOT have 'best_time = time,' directly (without a conditional)
        # It should have a variable (first_best_time) or ternary
        assert "best_time = time," not in section, \
            "New track branch sets best_time = time unconditionally — should use position guard"

    def test_else_branch_still_guards_best_time_for_first_place(self, rec_src):
        """Existing else branch must still guard best_time with position == 1."""
        idx = rec_src.find("# Only store best time for 1st place finishes")
        assert idx >= 0, "Comment about 1st-place best_time guard not found in records.gd"
        section = rec_src[idx:idx + 100]
        assert "position == 1" in section, \
            "Else branch must check position == 1 before updating best_time"
