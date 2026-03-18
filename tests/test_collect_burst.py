"""
Pytest tests for the star/cookie collect particle burst effect.

The implementation lives in collect_burst.gd (preloaded by race_manager.gd
as `CollectBurst`).

Validates that:
- collect_burst.gd extends Node2D with _ready, _process, _draw
- Particle count is 12-16 (randi_range)
- Colors include gold (#FFD740), white, and cyan (#00E5FF)
- Fade duration (LIFETIME) is 0.5s using a Tween
- queue_free() auto-frees the node after animation
- Particles drawn with draw_rect or draw_circle (3-5px)
- Radial outward launch using cos/sin
- queue_redraw() called for continuous animation
- race_manager.gd preloads collect_burst.gd as CollectBurst (no underscore)
- _sparkle_at() spawns a CollectBurst and sets z_index
- No inner class _CollectBurst exists in race_manager.gd (no name collision)
"""

import re
import os
import pytest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RACE_MANAGER = os.path.join(REPO_ROOT, "race_manager.gd")
COLLECT_BURST = os.path.join(REPO_ROOT, "collect_burst.gd")


@pytest.fixture(scope="module")
def race_source():
    with open(RACE_MANAGER, "r", encoding="utf-8") as f:
        return f.read()


@pytest.fixture(scope="module")
def burst_source():
    with open(COLLECT_BURST, "r", encoding="utf-8") as f:
        return f.read()


@pytest.fixture(scope="module")
def sparkle_body(race_source):
    """Extract the _sparkle_at function body."""
    match = re.search(
        r"(func\s+_sparkle_at\s*\([^)]*\)[^\n]*\n)((?:\t.*\n|\s*\n)*)",
        race_source,
    )
    assert match, "_sparkle_at function not found"
    return match.group(0)


# ── No name collision ─────────────────────────────────────────────────


class TestNoNameCollision:
    def test_no_inner_class(self, race_source):
        """There must be no inner class _CollectBurst in race_manager.gd."""
        assert "class _CollectBurst" not in race_source, (
            "Dead inner class _CollectBurst still exists in race_manager.gd"
        )

    def test_preload_const_no_underscore(self, race_source):
        """The preload const must be CollectBurst (no leading underscore)."""
        assert re.search(
            r'const\s+CollectBurst\s*=\s*preload\(\s*"res://collect_burst\.gd"\s*\)',
            race_source,
        ), "CollectBurst preload const not found (expected no underscore)"

    def test_no_underscore_const(self, race_source):
        """There must be no _CollectBurst const (old name)."""
        assert "const _CollectBurst" not in race_source, (
            "Old _CollectBurst const still present"
        )


# ── collect_burst.gd structure ────────────────────────────────────────


class TestBurstStructure:
    def test_extends_node2d(self, burst_source):
        """collect_burst.gd must extend Node2D."""
        assert "extends Node2D" in burst_source

    def test_has_ready(self, burst_source):
        assert "func _ready" in burst_source

    def test_has_process(self, burst_source):
        assert "func _process" in burst_source

    def test_has_draw(self, burst_source):
        assert "func _draw" in burst_source


# ── Particle configuration ────────────────────────────────────────────


class TestParticleConfig:
    def test_particle_count_range(self, burst_source):
        """Particle count should use randi_range(12, 16)."""
        assert "randi_range(12, 16)" in burst_source or (
            "12" in burst_source and "16" in burst_source
        ), "Particle count 12-16 not found"

    def test_lifetime_half_second(self, burst_source):
        """LIFETIME must be 0.5 seconds."""
        match = re.search(r"LIFETIME\s*[:=]\s*(?:float\s*=\s*)?([\d.]+)", burst_source)
        assert match, "LIFETIME constant not found"
        assert float(match.group(1)) == 0.5, "LIFETIME must be 0.5"

    def test_particle_size_range(self, burst_source):
        """Particle size must use 3.0-5.0 range."""
        assert "3.0" in burst_source and "5.0" in burst_source


# ── Colors ─────────────────────────────────────────────────────────────


class TestColors:
    def test_gold_color(self, burst_source):
        assert "FFD740" in burst_source, "Gold color #FFD740 not found"

    def test_white_color(self, burst_source):
        has_white = (
            "1, 1, 1" in burst_source
            or "1.0, 1.0, 1.0" in burst_source
            or "FFFFFF" in burst_source
        )
        assert has_white, "White color not found"

    def test_cyan_color(self, burst_source):
        assert "00E5FF" in burst_source, "Cyan color #00E5FF not found"

    def test_color_cycling(self, burst_source):
        """Colors should cycle via modulo on COLORS array."""
        assert "COLORS" in burst_source, "COLORS array not found"
        assert re.search(r"%\s*COLORS\.size\(\)", burst_source), (
            "Color cycling via modulo not found"
        )


# ── Animation mechanics ───────────────────────────────────────────────


class TestAnimation:
    def test_tween_alpha_fade(self, burst_source):
        assert "create_tween" in burst_source
        assert "modulate:a" in burst_source or "_alpha" in burst_source
        assert "0.0" in burst_source

    def test_queue_free_after_animation(self, burst_source):
        assert "queue_free" in burst_source

    def test_queue_redraw_in_process(self, burst_source):
        process_match = re.search(
            r"func\s+_process\s*\([^)]*\)[^\n]*\n((?:\t.*\n|\s*\n)*)",
            burst_source,
        )
        assert process_match, "_process function not found"
        assert "queue_redraw" in process_match.group(0)

    def test_radial_launch_cos_sin(self, burst_source):
        assert "cos" in burst_source and "sin" in burst_source

    def test_uses_draw_rect_or_circle(self, burst_source):
        assert "draw_rect" in burst_source or "draw_circle" in burst_source

    def test_uses_both_rect_and_circle(self, burst_source):
        """Mix of rect and circle draws."""
        assert "draw_rect" in burst_source and "draw_circle" in burst_source

    def test_drag_deceleration(self, burst_source):
        """Particles must decelerate with drag."""
        assert "drag" in burst_source.lower() or "friction" in burst_source.lower()


# ── _sparkle_at integration ───────────────────────────────────────────


class TestSparkleAt:
    def test_creates_collect_burst(self, sparkle_body):
        """_sparkle_at() must create a CollectBurst node."""
        assert "CollectBurst" in sparkle_body

    def test_sets_position(self, sparkle_body):
        assert "position" in sparkle_body

    def test_sets_z_index(self, sparkle_body):
        assert "z_index" in sparkle_body

    def test_adds_as_child(self, sparkle_body):
        assert "add_child" in sparkle_body


# ── Collection call sites ─────────────────────────────────────────────


class TestCallSites:
    def test_player_collection_calls_sparkle(self, race_source):
        sparkle_calls = [m.start() for m in re.finditer(r"_sparkle_at\s*\(", race_source)]
        assert len(sparkle_calls) >= 1, "No _sparkle_at calls found"
        found = False
        for idx in sparkle_calls:
            context = race_source[max(0, idx - 300):idx]
            if '"cookie"' in context or "cookie" in context.lower():
                found = True
                break
        assert found, "No _sparkle_at call found near cookie collection code"

    def test_sparkle_called_at_least_twice(self, race_source):
        count = len(re.findall(r"_sparkle_at\s*\(", race_source))
        assert count >= 2, (
            f"_sparkle_at called {count} time(s), expected >= 2 (player + AI)"
        )
