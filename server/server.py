"""Serveur du robot IA : WebSocket <-> STT -> Claude -> TTS.

Protocole avec l'ESP32 :
  ESP32 -> serveur : texte "start", puis frames binaires PCM16 mono 16 kHz,
                     puis texte "end" (bouton relache).
  serveur -> ESP32 : JSON {"type":"state","state":"thinking|speaking|idle"},
                     frames binaires PCM16 mono 16 kHz (reponse vocale),
                     JSON {"type":"state","state":"idle"} a la fin.
"""
import asyncio
import io
import json
import os
import wave

import httpx
from anthropic import AsyncAnthropic
from websockets.asyncio.server import serve

ELEVEN_KEY = os.environ["ELEVENLABS_API_KEY"]
VOICE_ID = os.environ["ELEVENLABS_VOICE_ID"]  # choisis une voix qui parle ton dialecte
CLAUDE_MODEL = os.environ.get("CLAUDE_MODEL", "claude-haiku-5-5")
SAMPLE_RATE = 16000
CHUNK = 2048  # octets par frame envoyee a l'ESP32
MAX_HISTORY = 12  # messages gardes en memoire par connexion

SYSTEM_PROMPT = os.environ.get(
    "ROBOT_PROMPT",
    "Tu es Shiko, un petit robot de bureau sympathique. Tu reponds dans la "
    "langue et le dialecte de l'utilisateur (arabe dialectal si il parle "
    "dialectal). Reponses tres courtes : 1 a 2 phrases, sans emoji, sans "
    "listes, car elles sont lues a voix haute.",
)

claude = AsyncAnthropic()  # lit ANTHROPIC_API_KEY
http = httpx.AsyncClient(timeout=60)


def pcm_to_wav(pcm: bytes) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm)
    return buf.getvalue()


async def speech_to_text(pcm: bytes) -> str:
    r = await http.post(
        "https://api.elevenlabs.io/v1/speech-to-text",
        headers={"xi-api-key": ELEVEN_KEY},
        data={"model_id": "scribe_v1"},  # langue detectee automatiquement
        files={"file": ("audio.wav", pcm_to_wav(pcm), "audio/wav")},
    )
    r.raise_for_status()
    return r.json().get("text", "").strip()


async def ask_claude(history: list, user_text: str) -> str:
    history.append({"role": "user", "content": user_text})
    del history[:-MAX_HISTORY]
    # l'historique doit commencer par un message "user"
    while history and history[0]["role"] != "user":
        history.pop(0)
    resp = await claude.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=300,
        system=SYSTEM_PROMPT,
        messages=history,
    )
    answer = "".join(b.text for b in resp.content if b.type == "text").strip()
    history.append({"role": "assistant", "content": answer})
    return answer


async def stream_tts(text: str, ws) -> None:
    url = (
        f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}/stream"
        f"?output_format=pcm_{SAMPLE_RATE}"
    )
    async with http.stream(
        "POST",
        url,
        headers={"xi-api-key": ELEVEN_KEY},
        json={"text": text, "model_id": "eleven_multilingual_v2"},
    ) as r:
        r.raise_for_status()
        pending = b""
        async for part in r.aiter_bytes():
            pending += part
            while len(pending) >= CHUNK:
                await ws.send(pending[:CHUNK])
                pending = pending[CHUNK:]
        if pending:
            await ws.send(pending + b"\x00" * (len(pending) % 2))


async def set_state(ws, state: str) -> None:
    await ws.send(json.dumps({"type": "state", "state": state}))


async def handle(ws) -> None:
    print("ESP32 connecte")
    history: list = []
    audio = bytearray()
    try:
        async for msg in ws:
            if isinstance(msg, bytes):
                audio.extend(msg)
                continue
            if msg == "start":
                audio.clear()
            elif msg == "end":
                pcm, audio = bytes(audio), bytearray()
                if len(pcm) < SAMPLE_RATE * 2 * 0.3:  # < 0,3 s : ignore
                    await set_state(ws, "idle")
                    continue
                await set_state(ws, "thinking")
                try:
                    text = await speech_to_text(pcm)
                    print("Toi   :", text)
                    if not text:
                        await set_state(ws, "idle")
                        continue
                    answer = await ask_claude(history, text)
                    print("Robot :", answer)
                    await set_state(ws, "speaking")
                    await stream_tts(answer, ws)
                except Exception as e:  # ne pas couper la connexion sur une erreur API
                    print("Erreur :", repr(e))
                await set_state(ws, "idle")
    finally:
        print("ESP32 deconnecte")


async def main() -> None:
    port = int(os.environ.get("PORT", "8765"))
    async with serve(handle, "0.0.0.0", port, max_size=2**22):
        print(f"En ecoute sur ws://0.0.0.0:{port}")
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
