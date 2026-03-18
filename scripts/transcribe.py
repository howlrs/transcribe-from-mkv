"""faster-whisper による音声文字起こし"""
import sys
from faster_whisper import WhisperModel


def format_timestamp(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def transcribe(audio_path: str, output_path: str, model_size: str) -> None:
    import os
    cpu_threads = int(os.environ.get("WHISPER_THREADS", 4))
    model = WhisperModel(model_size, device="cpu", compute_type="int8", cpu_threads=cpu_threads)
    print(f"  CPUスレッド数: {cpu_threads}")
    segments, info = model.transcribe(
        audio_path,
        language="ja",
        beam_size=5,
        vad_filter=True,
        vad_parameters=dict(
            min_silence_duration_ms=1000,
            speech_pad_ms=200,
        ),
    )

    print(f"  言語: {info.language} (確率: {info.language_probability:.2f})")
    print(f"  音声長: {info.duration:.1f}秒")

    with open(output_path, "w", encoding="utf-8") as f:
        for segment in segments:
            line = f"[{format_timestamp(segment.start)} - {format_timestamp(segment.end)}] {segment.text}"
            print(f"  {line}")
            f.write(line + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: transcribe.py <audio.wav> <output.txt> <model_size>")
        sys.exit(1)
    transcribe(sys.argv[1], sys.argv[2], sys.argv[3])
