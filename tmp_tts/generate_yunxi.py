import asyncio
from pathlib import Path
import edge_tts

VOICE = "zh-CN-YunxiNeural"
RATE = "-8%"
PITCH = "-2Hz"
VOLUME = "+0%"

SEGMENTS = [
    "失业后，他试过很多项目，却一个也没做成。",
    "直到有一天，他发现，小商家总在重复回答同样的问题。",
    "他不会写代码，就让人工智能帮他做自动客服。报错就改，失败就重来。",
    "他删掉复杂功能，只留下上传资料、顾客提问、人工智能回答，和付款。",
    "第一笔二十九元到账时，他突然相信，这条路能走通。",
    "他开始联系更多小店。没有融资，没有团队，只有一个能用的工具。草根逆袭不是暴富，而是普通人终于能把想法做成产品。Codex不会替你创业，但能让你迈出第一步。",
]

async def main() -> None:
    out = Path("output")
    out.mkdir(parents=True, exist_ok=True)
    for index, text in enumerate(SEGMENTS, start=1):
        communicate = edge_tts.Communicate(
            text=text,
            voice=VOICE,
            rate=RATE,
            pitch=PITCH,
            volume=VOLUME,
        )
        await communicate.save(str(out / f"yunxi_{index:02d}.mp3"))

if __name__ == "__main__":
    asyncio.run(main())
