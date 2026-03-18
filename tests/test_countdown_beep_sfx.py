"""
Pytest tests for countdown beep sound effects (AU-03).

Validates that:
- countdown_beep.wav (440Hz, ~0.15s) and countdown_go.wav (880Hz, ~0.2s) exist
- Both WAV files have valid RIFF/WAVE headers and correct properties
- AudioStreamPlayer nodes (CountdownBeepAudio, CountdownGoAudio) exist in main.tscn
- race_manager.gd declares cd_beep_sfx and cd_go_sfx variables
- cd_beep_sfx.play() is triggered during COUNTDOWN state for digits 3,2,1
- cd_go_sfx.play() is triggered when countdown hits GO
- _setup_audio() binds the countdown audio nodes
"""

import os
import struct
import re
import wave
import numpy as np
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
        wav = f.read(4)
        assert wav == b"WAVE", f"{path} is not a valid WAVE file"
        while True:
            chunk_id = f.read(4)
            if len(chunk_id) < 4:
                raise ValueError("fmt chunk not found")
            chunk_size = struct.unpack("<I", f.read(4))[0]
            if chunk_id == b"fmt ":
                fmt_data = f.read(chunk_size)
                num_channels = struct.unpack("<H", fmt_data[2:4])[0]
                sample_rate = struct.unpack("<I", fmt_data[4:8])[0]
                bits_per_sample = struct.unpack("<H", fmt_data[14:16])[0]
                break
            else:
                f.seek(chunk_size, 1)
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


def _wav_dominant_freq(path):
    """Return the dominant frequency in Hz of a WAV file using FFT."""
    w = wave.open(path, "rb")
    sr = w.getframerate()
    frames = w.readframes(w.getnframes())
    w.close()
    samples = np.frombuffer(frames, dtype=np.int16).astype(float)
    fft = np.abs(np.fft.rfft(samples))
    freqs = np.fft.rfftfreq(len(samples), 1 / sr)
    # Skip DC component (index 0)
    dominant = freqs[np.argmax(fft[1:]) + 1]
    return dominant


# ── WAV file existence & validity ───────────────────────────────────────

class TestCountdownBeepWav:
    def test_beep_wav_exists(self):
        assert os.path.isfile(os.path.join(AUDIO_DIR, "countdown_beep.wav"))

    def test_beep_wav_valid_header(self):
        path = os.path.join(AUDIO_DIR, "countdown_beep.wav")
        sr, ch, bps, data_size = _read_wav_info(path)
        assert sr == 44100, f"Expected 44100 Hz sample rate, got {sr}"
        assert ch == 1, f"Expected mono, got {ch} channels"
        assert bps == 16, f"Expected 16-bit, got {bps}-bit"

    def test_beep_wav_duration_015s(self):
        path = os.path.join(AUDIO_DIR, "countdown_beep.wav")
        dur = _wav_duration(path)
        assert 0.10 <= dur <= 0.25, f"countdown_beep.wav duration {dur:.3f}s not ~0.15s"

    def test_beep_wav_frequency_440hz(self):
        path = os.path.join(AUDIO_DIR, "countdown_beep.wav")
        freq = _wav_dominant_freq(path)
        assert 430 <= freq <= 450, f"Expected ~440Hz, got {freq:.1f}Hz"


class TestCountdownGoWav:
    def test_go_wav_exists(self):
        assert os.path.isfile(os.path.join(AUDIO_DIR, "countdown_go.wav"))

    def test_go_wav_valid_header(self):
        path = os.path.join(AUDIO_DIR, "countdown_go.wav")
        sr, ch, bps, data_size = _read_wav_info(path)
        assert sr == 44100, f"Expected 44100 Hz sample rate, got {sr}"
        assert ch == 1, f"Expected mono, got {ch} channels"
        assert bps == 16, f"Expected 16-bit, got {bps}-bit"

    def test_go_wav_duration_02s(self):
        path = os.path.join(AUDIO_DIR, "countdown_go.wav")
        dur = _wav_duration(path)
        assert 0.15 <= dur <= 0.30, f"countdown_go.wav duration {dur:.3f}s not ~0.2s"

    def test_go_wav_frequency_880hz(self):
        path = os.path.join(AUDIO_DIR, "countdown_go.wav")
        freq = _wav_dominant_freq(path)
        assert 870 <= freq <= 890, f"Expected ~880Hz, got {freq:.1f}Hz"

    def test_go_longer_than_beep(self):
        beep_dur = _wav_duration(os.path.join(AUDIO_DIR, "countdown_beep.wav"))
        go_dur = _wav_duration(os.path.join(AUDIO_DIR, "countdown_go.wav"))
        assert go_dur > beep_dur, "GO beep should be longer than countdown beep"

    def test_go_higher_pitch_than_beep(self):
        beep_freq = _wav_dominant_freq(os.path.join(AUDIO_DIR, "countdown_beep.wav"))
        go_freq = _wav_dominant_freq(os.path.join(AUDIO_DIR, "countdown_go.wav"))
        assert go_freq > beep_freq, "GO beep should be higher pitch than countdown beep"


# ── Scene nodes in main.tscn ───────────────────────────────────────────

class TestSceneNodes:
    def test_countdown_beep_node_exists(self, tscn_src):
        assert "CountdownBeepAudio" in tscn_src

    def test_countdown_go_node_exists(self, tscn_src):
        assert "CountdownGoAudio" in tscn_src

    def test_countdown_beep_wav_referenced(self, tscn_src):
        assert "countdown_beep.wav" in tscn_src

    def test_countdown_go_wav_referenced(self, tscn_src):
        assert "countdown_go.wav" in tscn_src

    def test_countdown_nodes_are_audio_stream_player(self, tscn_src):
        assert re.search(
            r'CountdownBeepAudio.*type="AudioStreamPlayer"', tscn_src
        ), "CountdownBeepAudio should be AudioStreamPlayer type"
        assert re.search(
            r'CountdownGoAudio.*type="AudioStreamPlayer"', tscn_src
        ), "CountdownGoAudio should be AudioStreamPlayer type"


# ── race_manager.gd wiring ─────────────────────────────────────────────

class TestRaceManagerWiring:
    def test_cd_beep_sfx_var_declared(self, mgr_src):
        assert re.search(r"var\s+cd_beep_sfx\s*:\s*AudioStreamPlayer", mgr_src), \
            "cd_beep_sfx not typed as AudioStreamPlayer"

    def test_cd_go_sfx_var_declared(self, mgr_src):
        assert re.search(r"var\s+cd_go_sfx\s*:\s*AudioStreamPlayer", mgr_src), \
            "cd_go_sfx not typed as AudioStreamPlayer"

    def test_setup_audio_binds_countdown_beep(self, mgr_src):
        match = re.search(r"func _setup_audio[^:]*:.*?(?=\nfunc |\Z)", mgr_src, re.DOTALL)
        assert match, "_setup_audio function not found"
        body = match.group(0)
        assert "CountdownBeepAudio" in body, \
            "_setup_audio should reference CountdownBeepAudio node"
        assert "cd_beep_sfx" in body, \
            "_setup_audio should assign cd_beep_sfx"

    def test_setup_audio_binds_countdown_go(self, mgr_src):
        match = re.search(r"func _setup_audio[^:]*:.*?(?=\nfunc |\Z)", mgr_src, re.DOTALL)
        assert match, "_setup_audio function not found"
        body = match.group(0)
        assert "CountdownGoAudio" in body, \
            "_setup_audio should reference CountdownGoAudio node"
        assert "cd_go_sfx" in body, \
            "_setup_audio should assign cd_go_sfx"

    def test_setup_audio_casts_countdown_nodes(self, mgr_src):
        match = re.search(r"func _setup_audio[^:]*:.*?(?=\nfunc |\Z)", mgr_src, re.DOTALL)
        assert match, "_setup_audio function not found"
        body = match.group(0)
        # Both countdown vars should be cast with "as AudioStreamPlayer"
        assert body.count("as AudioStreamPlayer") >= 2, \
            "_setup_audio should cast countdown nodes to AudioStreamPlayer"


# ── Countdown state logic ──────────────────────────────────────────────

class TestCountdownLogic:
    def test_beep_played_during_countdown_digits(self, mgr_src):
        """cd_beep_sfx.play() should be called when countdown digit changes (3,2,1)."""
        # Find the State.COUNTDOWN block
        match = re.search(r"State\.COUNTDOWN:.*?(?=State\.\w+:|\Z)", mgr_src, re.DOTALL)
        assert match, "State.COUNTDOWN block not found"
        block = match.group(0)
        assert "cd_beep_sfx.play()" in block, \
            "cd_beep_sfx.play() not called in COUNTDOWN state"

    def test_go_played_at_zero(self, mgr_src):
        """cd_go_sfx.play() should be called when countdown reaches GO."""
        match = re.search(r"State\.COUNTDOWN:.*?(?=State\.\w+:|\Z)", mgr_src, re.DOTALL)
        assert match, "State.COUNTDOWN block not found"
        block = match.group(0)
        assert "cd_go_sfx.play()" in block, \
            "cd_go_sfx.play() not called in COUNTDOWN state"

    def test_beep_triggered_on_digit_change(self, mgr_src):
        """cd_beep_sfx.play() should be near last_digit_shown change (not every frame)."""
        match = re.search(r"State\.COUNTDOWN:.*?(?=State\.\w+:|\Z)", mgr_src, re.DOTALL)
        assert match, "State.COUNTDOWN block not found"
        block = match.group(0)
        assert "last_digit_shown" in block, \
            "Countdown should track last_digit_shown to avoid repeat plays"
        # beep should be after the digit-change check
        digit_idx = block.index("last_digit_shown")
        beep_idx = block.index("cd_beep_sfx.play()")
        assert beep_idx > digit_idx, \
            "cd_beep_sfx.play() should come after last_digit_shown check"

    def test_go_after_beep_in_countdown(self, mgr_src):
        """GO sound should trigger after the digit-counting beeps (at 0)."""
        match = re.search(r"State\.COUNTDOWN:.*?(?=State\.\w+:|\Z)", mgr_src, re.DOTALL)
        assert match, "State.COUNTDOWN block not found"
        block = match.group(0)
        beep_idx = block.index("cd_beep_sfx.play()")
        go_idx = block.index("cd_go_sfx.play()")
        assert go_idx > beep_idx, \
            "cd_go_sfx.play() should come after cd_beep_sfx.play() in countdown flow"

    def test_countdown_shows_go_text(self, mgr_src):
        """The countdown should display 'GO!' text."""
        match = re.search(r"State\.COUNTDOWN:.*?(?=State\.\w+:|\Z)", mgr_src, re.DOTALL)
        assert match, "State.COUNTDOWN block not found"
        block = match.group(0)
        assert '"GO!"' in block or "'GO!'" in block, \
            "Countdown should display 'GO!' text"
