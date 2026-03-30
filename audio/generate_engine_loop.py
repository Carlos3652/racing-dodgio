"""
generate_engine_loop.py
-----------------------
Generates audio/engine_loop.wav — a 0.5 second mono sine wave at 220 Hz
(16-bit PCM, 44100 Hz sample rate).

The wave is amplitude-tapered over the first and last 5% of its length so the
loop point is seamless when Godot plays it end-to-end via the finished signal.

Usage:
    python audio/generate_engine_loop.py

The file is written relative to the project root, so run from the project root
or pass --output <path> to override the destination.
"""

import argparse
import math
import os
import struct
import wave

FREQUENCY_HZ: float = 220.0
DURATION_S: float = 0.5
SAMPLE_RATE: int = 44100
AMPLITUDE: int = 24000  # headroom below 32767 so the loop never clips at max pitch_scale

_DEFAULT_OUTPUT = os.path.join(os.path.dirname(__file__), "engine_loop.wav")


def _fade_envelope(index: int, total: int, fade_fraction: float = 0.05) -> float:
    """Return a [0.0, 1.0] linear taper for loop-point seamlessness."""
    fade_samples = int(total * fade_fraction)
    if index < fade_samples:
        return index / fade_samples
    if index >= total - fade_samples:
        return (total - index) / fade_samples
    return 1.0


def generate(output_path: str = _DEFAULT_OUTPUT) -> None:
    total_frames = int(SAMPLE_RATE * DURATION_S)
    samples: list[int] = []
    for i in range(total_frames):
        t = i / SAMPLE_RATE
        sine = math.sin(2.0 * math.pi * FREQUENCY_HZ * t)
        envelope = _fade_envelope(i, total_frames)
        sample = int(sine * AMPLITUDE * envelope)
        samples.append(max(-32768, min(32767, sample)))

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with wave.open(output_path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)  # 16-bit
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(struct.pack(f"<{total_frames}h", *samples))

    size_kb = os.path.getsize(output_path) / 1024
    print(f"Written: {output_path}  ({total_frames} frames, {DURATION_S}s, {size_kb:.1f} KB)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate engine_loop.wav placeholder")
    parser.add_argument(
        "--output",
        default=_DEFAULT_OUTPUT,
        help="Destination path (default: audio/engine_loop.wav next to this script)",
    )
    args = parser.parse_args()
    generate(args.output)
