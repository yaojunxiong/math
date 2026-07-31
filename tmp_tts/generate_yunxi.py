import asyncio
import base64
import hashlib
import json
import subprocess
from pathlib import Path

import edge_tts

VOICE = "zh-CN-YunxiNeural"
RATE = "-8%"
PITCH = "-2Hz"
VOLUME = "+0%"
TARGET_DURATIONS = [5.9, 7.4, 8.5, 8.1, 7.0, 20.0]
CHUNK_SIZE = 16000

SEGMENTS = [
    "失业后，他试过很多项目，却一个也没做成。",
    "直到有一天，他发现，小商家总在重复回答同样的问题。",
    "他不会写代码，就让人工智能帮他做自动客服。报错就改，失败就重来。",
    "他删掉复杂功能，只留下上传资料、顾客提问、人工智能回答，和付款。",
    "第一笔二十九元到账时，他突然相信，这条路能走通。",
    "他开始联系更多小店。没有融资，没有团队，只有一个能用的工具。草根逆袭不是暴富，而是普通人终于能把想法做成产品。Codex不会替你创业，但能让你迈出第一步。",
]


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def duration(path: Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return float(result.stdout.strip())


def atempo_chain(factor: float) -> str:
    filters: list[str] = []
    while factor > 2.0:
        filters.append("atempo=2.0")
        factor /= 2.0
    while factor < 0.5:
        filters.append("atempo=0.5")
        factor /= 0.5
    filters.append(f"atempo={factor:.8f}")
    return ",".join(filters)


async def main() -> None:
    out = Path("output")
    transfer = Path("transfer")
    out.mkdir(parents=True, exist_ok=True)
    transfer.mkdir(parents=True, exist_ok=True)

    slot_files: list[Path] = []
    for index, (text, target) in enumerate(zip(SEGMENTS, TARGET_DURATIONS), start=1):
        source = out / f"yunxi_{index:02d}.mp3"
        communicate = edge_tts.Communicate(
            text=text,
            voice=VOICE,
            rate=RATE,
            pitch=PITCH,
            volume=VOLUME,
        )
        await communicate.save(str(source))

        source_duration = duration(source)
        slot = out / f"slot_{index:02d}.wav"
        if source_duration > target:
            factor = source_duration / target
            audio_filter = f"{atempo_chain(factor)},atrim=duration={target:.3f}"
        else:
            pad = target - source_duration
            audio_filter = f"apad=pad_dur={pad:.3f},atrim=duration={target:.3f}"

        run(
            "ffmpeg",
            "-y",
            "-i",
            str(source),
            "-af",
            audio_filter,
            "-ar",
            "24000",
            "-ac",
            "1",
            "-c:a",
            "pcm_s16le",
            str(slot),
        )
        slot_files.append(slot)

    concat_file = out / "slots.txt"
    concat_file.write_text(
        "".join(f"file '{slot.resolve()}'\n" for slot in slot_files),
        encoding="utf-8",
    )
    full_wav = out / "yunxi_aligned.wav"
    run(
        "ffmpeg",
        "-y",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(concat_file),
        "-c:a",
        "pcm_s16le",
        str(full_wav),
    )

    compressed = out / "yunxi_aligned.ogg"
    run(
        "ffmpeg",
        "-y",
        "-i",
        str(full_wav),
        "-c:a",
        "libopus",
        "-b:a",
        "8k",
        "-vbr",
        "on",
        "-application",
        "voip",
        "-frame_duration",
        "60",
        str(compressed),
    )

    raw = compressed.read_bytes()
    encoded = base64.b64encode(raw).decode("ascii")
    chunks = [encoded[i : i + CHUNK_SIZE] for i in range(0, len(encoded), CHUNK_SIZE)]
    for old in transfer.glob("chunk_*.txt"):
        old.unlink()
    for index, chunk in enumerate(chunks, start=1):
        (transfer / f"chunk_{index:03d}.txt").write_text(chunk, encoding="ascii")

    manifest = {
        "format": "ogg-opus",
        "voice": VOICE,
        "rate": RATE,
        "pitch": PITCH,
        "duration_seconds": sum(TARGET_DURATIONS),
        "base64_length": len(encoded),
        "chunk_size": CHUNK_SIZE,
        "chunk_count": len(chunks),
        "sha256": hashlib.sha256(raw).hexdigest(),
    }
    (transfer / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    asyncio.run(main())
