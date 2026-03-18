"""
Pytest tests for the star/cookie collect particle burst effect in race_manager.gd.

Validates that:
- _CollectBurst inner class exists and extends Node2D
- Particle count is 12-16
- Colors include gold (#FFD740), white, and cyan (#00E5FF)
- Fade duration is 0.5s using a Tween
- queue_free() auto-frees the node after animation
- Particles drawn with draw_rect or draw_circle (3-5px)
- Radial outward launch using cos/sin
- _sparkle_at() spawns a _CollectBurst and sets z_index
- queue_redraw() called for continuous animation
"""

import re
import os
import pytest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RACE_MANAGER = os.path.join(REPO_ROOT, "race_manager.gd")


@pytest.fixture(scope="module")
def source():
    with open(RACE_MANAGER, "r", encoding="utf-8") as f:
        return f.read()


@pytest.fixture(scope="module")
def class_body(source):
    """Extract the _CollectBurst inner class body."""
    idx = source.find("class _CollectBurst")
    assert idx >= 0, "_CollectBurst inner class not found"
    return source[idx:]


@pytest.fixture(scope="module")
def sparkle_body(source):
    """Extract the _sparkle_at function body."""
    match = re.search(
        r"(func\s+_sparkle_at\s*\([^)]*\)[^\n]*\n)((?:\t.*\n|\s*\n)*)",
        source,
    )
    assert match, "_sparkle_at function not found"
    return match.group(0)


# ── Inner class structure ──────────────────────────────────────────────


class TestClassStructure:
    def test_class_exists(self, source):
        """_CollectBurst inner class must exist."""
        assert "class _CollectBurst" in source

    def test_extends_node2d(self, source):
        """_CollectBurst must extend Node2D."""
        assert "_CollectBurst extends Node2D" in source

    def test_has_ready(self, class_body):
        """_CollectBurst must have a _ready() function."""
        assert "func _ready" in class_body

    def test_has_process(self, class_body):
        """_CollectBurst must have a _process() function."""
        assert "func _process" in class_body

    def test_has_draw(self, class_body):
        """_CollectBurst must have a _draw() function."""
        assert "func _draw" in class_body


# ── Particle configuration ─────────────────────────────────────────────


class TestParticleConfig:
    def test_particle_count_in_range(self, class_body):
        """PARTICLE_COUNT must be between 12 and 16."""
        match = re.search(r"PARTICLE_COUNT\s*:=\s*(\d+)", class_body)
        assert match, "PARTICLE_COUNT constant not found"
        count = int(match.group(1))
        assert 12 <= count <= 16, f"PARTICLE_COUNT={count}, expected 12-16"

    def test_burst_duration_half_second(self, class_body):
        """BURST_DURATION must be 0.5 seconds."""
        match = re.search(r"BURST_DURATION\s*:=\s*([\d.]+)", class_body)
        assert match, "BURST_DURATION constant not found"
        assert float(match.group(1)) == 0.5, "BURST_DURATION must be 0.5"

    def test_particle_size_range(self, class_body):
        """Particle size must use randf_range(3.0, 5.0) for 3-5px."""
        assert "3.0" in class_body and "5.0" in class_body, (
            "Particle size range 3.0-5.0 not found"
        )


# ── Colors ──────────────────────────────────────────────────────────────


class TestColors:
    def test_gold_color(self, class_body):
        """Gold color #FFD740 must be present."""
        assert "FFD740" in class_body, "Gold color #FFD740 not found"

    def test_white_color(self, class_body):
        """White color must be present."""
        has_white = (
            "1, 1, 1" in class_body
            or "1.0, 1.0, 1.0" in class_body
            or "FFFFFF" in class_body
        )
        assert has_white, "White color not found"

    def test_cyan_color(self, class_body):
        """Cyan color #00E5FF must be present."""
        assert "00E5FF" in class_body, "Cyan color #00E5FF not found"

    def test_color_cycling(self, class_body):
        """Colors should cycle via modulo on BURST_COLORS array."""
        assert "BURST_COLORS" in class_body, "BURST_COLORS array not found"
        assert "% BURST_COLORS.size()" in class_body, (
            "Color cycling via modulo not found"
        )


# ── Animation mechanics ────────────────────────────────────────────────


class TestAnimation:
    def test_tween_alpha_fade(self, class_body):
        """Must use create_tween() to fade _alpha to 0."""
        assert "create_tween" in class_body, "No create_tween() call found"
        assert "_alpha" in class_body, "No _alpha property found"
        assert "0.0" in class_body, "Tween target of 0.0 not found"

    def test_queue_free_after_animation(self, class_body):
        """queue_free must be called after tween completes."""
        assert "queue_free" in class_body, "queue_free() not found in _CollectBurst"

    def test_queue_redraw_in_process(self, class_body):
        """queue_redraw() must be called in _process for continuous redraw."""
        process_match = re.search(
            r"func\s+_process\s*\([^)]*\)[^\n]*\n((?:\t.*\n|\s*\n)*)",
            class_body,
        )
        assert process_match, "_process function not found in _CollectBurst"
        assert "queue_redraw" in process_match.group(0), (
            "No queue_redraw in _process — particles won't animate"
        )

    def test_radial_launch_cos_sin(self, class_body):
        """Particles must launch radially using cos/sin."""
        assert "cos" in class_body and "sin" in class_body, (
            "No cos/sin found — particles may not launch radially"
        )

    def test_uses_draw_rect_or_circle(self, class_body):
        """Particles must be drawn with draw_rect or draw_circle."""
        has_draw = "draw_rect" in class_body or "draw_circle" in class_body
        assert has_draw, "No draw_rect or draw_circle in _draw()"


# ── _sparkle_at integration ────────────────────────────────────────────


class TestSparkleAt:
    def test_creates_collect_burst(self, sparkle_body):
        """_sparkle_at() must create a _CollectBurst node."""
        assert "_CollectBurst" in sparkle_body, (
            "_sparkle_at() does not create _CollectBurst"
        )

    def test_sets_position(self, sparkle_body):
        """_sparkle_at() must set position on the burst node."""
        assert "position" in sparkle_body, (
            "_sparkle_at() does not set position"
        )

    def test_sets_z_index(self, sparkle_body):
        """_sparkle_at() must set z_index for layering."""
        assert "z_index" in sparkle_body, (
            "_sparkle_at() does not set z_index"
        )

    def test_adds_as_child(self, sparkle_body):
        """_sparkle_at() must add burst node as child."""
        assert "add_child" in sparkle_body, (
            "_sparkle_at() does not call add_child"
        )


# ── Collection call sites ──────────────────────────────────────────────


class TestCallSites:
    def test_player_collection_calls_sparkle(self, source):
        """Player cookie collection must call _sparkle_at."""
        # Find the _sparkle_at function and verify cookie collection calls it
        # Search for _sparkle_at calls near "cookie" tag references
        sparkle_calls = [m.start() for m in re.finditer(r"_sparkle_at\s*\(", source)]
        assert len(sparkle_calls) >= 1, "No _sparkle_at calls found"
        # At least one call should be near a cookie collection context
        found = False
        for idx in sparkle_calls:
            context = source[max(0, idx - 300):idx]
            if '"cookie"' in context or "cookie" in context.lower():
                found = True
                break
        assert found, "No _sparkle_at call found near cookie collection code"

    def test_sparkle_called_at_least_twice(self, source):
        """_sparkle_at should be called for both player and AI collection."""
        count = len(re.findall(r"_sparkle_at\s*\(", source))
        assert count >= 2, (
            f"_sparkle_at called {count} time(s), expected >= 2 (player + AI)"
        )
