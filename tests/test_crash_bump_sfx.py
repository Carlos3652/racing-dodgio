"""
Pytest tests for crash & bump sound effects (AU-02).

Validates that:
- crash.wav and bump.wav exist in audio/ folder and have valid WAV headers
- crash.wav is ~0.2s (sharp impact) and bump.wav is ~0.1s (lighter bump)
- AudioStreamPlayer nodes (CrashAudio, BumpAudio) exist in main.tscn
- race_manager.gd declares crash_audio and bump_audio variables
- crash_audio.play() is triggered in _flash_screen() (called after apply_crash)
- bump_audio.play() is triggered in _flash_bump() (car-to-car collisions)
- _setup_audio() binds the nodes and is called from _ready()
"""

import os
import struct
import re
import pytest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
AUDIO_DIR = os.path.join(REPO_ROOT, "audio")
MAIN_TSCN = os.path.join(REPO_ROOT, "main.tscn")
RACE_MGR = os.path.join(REPO_ROOT, "race_manager.gd")


# ── Fixtures ────────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def tscn_src():
    with open(MAIN_TSCN, "r", encoding="utf-8") as f:
        return f.read()


@pytest.fixture(scope="module")
def mgr_src():
    with open(RACE_MGR, "r", encoding="utf-8") as f:
        return f.read()


def _read_wav_info(path):
    """Read WAV header and return (sample_rate, num_channels, bits_per_sample, data_size)."""
    with open(path, "rb") as f:
        riff = f.read(4)
        assert riff == b"RIFF", f"{path} is not a valid RIFF file"
        f.read(4)  # file size
        wave = f.read(4)
        assert wave == b"WAVE", f"{path} is not a valid WAVE file"
        # Find fmt chunk
        while True:
            chunk_id = f.read(4)
            if len(chunk_id) < 4:
                raise ValueError("fmt chunk not found")
            chunk_size = struct.unpack("<I", f.read(4))[0]
            if chunk_id == b"fmt ":
                fmt_data = f.read(chunk_size)
                audio_fmt = struct.unpack("<H", fmt_data[0:2])[0]
                num_channels = struct.unpack("<H", fmt_data[2:4])[0]
                sample_rate = struct.unpack("<I", fmt_data[4:8])[0]
                bits_per_sample = struct.unpack("<H", fmt_data[14:16])[0]
                break
            else:
                f.seek(chunk_size, 1)
        # Find data chunk
        while True:
            chunk_id = f.read(4)
            if len(chunk_id) < 4:
                raise ValueError("data chunk not found")
            chunk_size = struct.unpack("<I", f.read(4))[0]
            if chunk_id == b"data":
                return sample_rate, num_channels, bits_per_sample, chunk_size
            else:
                f.seek(chunk_size, 1)


def _wav_duration(path):
    """Return duration in seconds of a WAV file."""
    sr, ch, bps, data_size = _read_wav_info(path)
    bytes_per_sample = bps // 8
    num_samples = data_size // (bytes_per_sample * ch)
    return num_samples / sr


# ── WAV file existence & validity ───────────────────────────────────────

class TestCrashWav:
    def test_crash_wav_exists(self):
        assert os.path.isfile(os.path.join(AUDIO_DIR, "crash.wav"))

    def test_crash_wav_valid_header(self):
        path = os.path.join(AUDIO_DIR, "crash.wav")
        sr, ch, bps, data_size = _read_wav_info(path)
        assert sr > 0
        assert ch >= 1
        assert bps in (8, 16, 24, 32)

    def test_crash_wav_duration_approx_02s(self):
        path = os.path.join(AUDIO_DIR, "crash.wav")
        dur = _wav_duration(path)
        # Should be roughly 0.2s (allow 0.05s to 0.5s for placeholder)
        assert 0.05 <= dur <= 0.5, f"crash.wav duration {dur:.3f}s not in expected range"


class TestBumpWav:
    def test_bump_wav_exists(self):
        assert os.path.isfile(os.path.join(AUDIO_DIR, "bump.wav"))

    def test_bump_wav_valid_header(self):
        path = os.path.join(AUDIO_DIR, "bump.wav")
        sr, ch, bps, data_size = _read_wav_info(path)
        assert sr > 0
        assert ch >= 1
        assert bps in (8, 16, 24, 32)

    def test_bump_wav_duration_approx_01s(self):
        path = os.path.join(AUDIO_DIR, "bump.wav")
        dur = _wav_duration(path)
        # Should be roughly 0.1s (allow 0.03s to 0.3s for placeholder)
        assert 0.03 <= dur <= 0.3, f"bump.wav duration {dur:.3f}s not in expected range"

    def test_bump_shorter_than_crash(self):
        crash_dur = _wav_duration(os.path.join(AUDIO_DIR, "crash.wav"))
        bump_dur = _wav_duration(os.path.join(AUDIO_DIR, "bump.wav"))
        assert bump_dur <= crash_dur, "bump.wav should be shorter/equal to crash.wav"


# ── Scene nodes in main.tscn ───────────────────────────────────────────

class TestSceneNodes:
    def test_crash_audio_node_exists(self, tscn_src):
        assert "CrashAudio" in tscn_src

    def test_bump_audio_node_exists(self, tscn_src):
        assert "BumpAudio" in tscn_src

    def test_crash_wav_referenced(self, tscn_src):
        assert "crash.wav" in tscn_src

    def test_bump_wav_referenced(self, tscn_src):
        assert "bump.wav" in tscn_src

    def test_audio_stream_player_type(self, tscn_src):
        assert "AudioStreamPlayer" in tscn_src


# ── race_manager.gd wiring ─────────────────────────────────────────────

class TestRaceManagerWiring:
    def test_crash_audio_var_declared(self, mgr_src):
        assert "crash_audio" in mgr_src

    def test_bump_audio_var_declared(self, mgr_src):
        assert "bump_audio" in mgr_src

    def test_setup_audio_function_exists(self, mgr_src):
        assert "func _setup_audio" in mgr_src

    def test_setup_audio_called_from_ready(self, mgr_src):
        ready_match = re.search(r"func _ready[^:]*:.*?(?=\nfunc |\Z)", mgr_src, re.DOTALL)
        assert ready_match, "_ready function not found"
        assert "_setup_audio" in ready_match.group(0), "_setup_audio not called from _ready"

    def test_crash_audio_play_in_flash_screen(self, mgr_src):
        match = re.search(r"func _flash_screen[^:]*:.*?(?=\nfunc |\Z)", mgr_src, re.DOTALL)
        assert match, "_flash_screen function not found"
        body = match.group(0)
        assert "crash_audio" in body and ".play()" in body, \
            "crash_audio.play() not called in _flash_screen"

    def test_bump_audio_play_in_flash_bump(self, mgr_src):
        match = re.search(r"func _flash_bump[^:]*:.*?(?=\nfunc |\Z)", mgr_src, re.DOTALL)
        assert match, "_flash_bump function not found"
        body = match.group(0)
        assert "bump_audio" in body and ".play()" in body, \
            "bump_audio.play() not called in _flash_bump"

    def test_flash_screen_called_after_apply_crash(self, mgr_src):
        """Verify _flash_screen() is called in the same block as apply_crash()."""
        assert "apply_crash()" in mgr_src
        assert "_flash_screen()" in mgr_src
        # They should appear close together (crash triggers flash)
        crash_idx = mgr_src.index("apply_crash()")
        flash_idx = mgr_src.index("_flash_screen()", crash_idx)
        # flash_screen should be within ~200 chars of apply_crash
        assert flash_idx - crash_idx < 200, \
            "_flash_screen not called near apply_crash"

    def test_crash_audio_overlap_guard(self, mgr_src):
        """Verify crash audio has 'not crash_audio.playing' guard to prevent overlap."""
        match = re.search(r"func _flash_screen[^:]*:.*?(?=\nfunc |\Z)", mgr_src, re.DOTALL)
        assert match, "_flash_screen function not found"
        body = match.group(0)
        assert "not crash_audio.playing" in body, \
            "crash_audio should check 'not crash_audio.playing' to prevent overlap"

    def test_bump_audio_overlap_guard(self, mgr_src):
        """Verify bump audio has 'not bump_audio.playing' guard to prevent overlap."""
        match = re.search(r"func _flash_bump[^:]*:.*?(?=\nfunc |\Z)", mgr_src, re.DOTALL)
        assert match, "_flash_bump function not found"
        body = match.group(0)
        assert "not bump_audio.playing" in body, \
            "bump_audio should check 'not bump_audio.playing' to prevent overlap"


# ── Audio volume & scene config ──────────────────────────────────────

class TestAudioConfig:
    def test_crash_audio_has_volume_db(self, tscn_src):
        """CrashAudio node should have a volume_db setting."""
        crash_section = tscn_src[tscn_src.index("CrashAudio"):]
        # Find volume_db before next node
        next_node = crash_section.find("[node", 1)
        section = crash_section[:next_node] if next_node > 0 else crash_section
        assert "volume_db" in section, "CrashAudio should have volume_db configured"

    def test_bump_audio_has_volume_db(self, tscn_src):
        """BumpAudio node should have a volume_db setting."""
        bump_section = tscn_src[tscn_src.index("BumpAudio"):]
        next_node = bump_section.find("[node", 1)
        section = bump_section[:next_node] if next_node > 0 else bump_section
        assert "volume_db" in section, "BumpAudio should have volume_db configured"

    def test_crash_wav_mono_16bit(self):
        """Crash WAV should be mono 16-bit for game audio efficiency."""
        path = os.path.join(AUDIO_DIR, "crash.wav")
        sr, ch, bps, _ = _read_wav_info(path)
        assert ch == 1, f"crash.wav should be mono, got {ch} channels"
        assert bps == 16, f"crash.wav should be 16-bit, got {bps}-bit"

    def test_bump_wav_mono_16bit(self):
        """Bump WAV should be mono 16-bit for game audio efficiency."""
        path = os.path.join(AUDIO_DIR, "bump.wav")
        sr, ch, bps, _ = _read_wav_info(path)
        assert ch == 1, f"bump.wav should be mono, got {ch} channels"
        assert bps == 16, f"bump.wav should be 16-bit, got {bps}-bit"

    def test_crash_wav_sample_rate(self):
        """Crash WAV should use a standard sample rate."""
        path = os.path.join(AUDIO_DIR, "crash.wav")
        sr, _, _, _ = _read_wav_info(path)
        assert sr in (11025, 22050, 44100, 48000), \
            f"crash.wav sample rate {sr} is non-standard"

    def test_bump_wav_sample_rate(self):
        """Bump WAV should use a standard sample rate."""
        path = os.path.join(AUDIO_DIR, "bump.wav")
        sr, _, _, _ = _read_wav_info(path)
        assert sr in (11025, 22050, 44100, 48000), \
            f"bump.wav sample rate {sr} is non-standard"
