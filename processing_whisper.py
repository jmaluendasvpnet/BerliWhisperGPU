from faster_whisper import WhisperModel as FasterWhisperModel
import tempfile
import uuid
import os

WHISPER_MODEL = None
try:
    WHISPER_MODEL = FasterWhisperModel("medium", device="cuda", compute_type="float16")
    print("Whisper funcionando correctamente")
except Exception as e:
    WHISPER_MODEL = "ERROR"

_ALLOWED_EXT = {"ogg", "oga", "opus", "mp3", "wav", "m4a", "webm", "mp4", "mpeg", "aac"}


def run_transcription_internal(audio_data: bytes, file_extension: str):
    if WHISPER_MODEL == "ERROR" or WHISPER_MODEL is None:
        raise Exception("Modelo Whisper no cargo.")
    if not audio_data or len(audio_data) < 256:
        raise ValueError("Audio vacio o demasiado pequeno")
    ext = (file_extension or "ogg").lower().rsplit(".", 1)[-1]
    if ext not in _ALLOWED_EXT:
        ext = "ogg"
    temp_path = os.path.join(tempfile.gettempdir(), f"{uuid.uuid4()}.{ext}")
    try:
        with open(temp_path, "wb") as f:
            f.write(audio_data)
        try:
            segments, _ = WHISPER_MODEL.transcribe(temp_path, language="es")
        except (IndexError, OSError, RuntimeError, ValueError) as exc:
            raise ValueError("Audio no decodificable") from exc
        return "".join(segment.text for segment in segments).strip()
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
