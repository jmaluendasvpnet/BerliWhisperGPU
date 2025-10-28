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

def run_transcription_internal(audio_data: bytes, file_extension: str):
    if WHISPER_MODEL == "ERROR":
        raise Exception("Modelo Whisper no cargo.")
    if WHISPER_MODEL is None:
         raise Exception("Modelo Whisper con error.")

    try:
        unique_filename = f"{uuid.uuid4()}.{file_extension}"
        temp_path = os.path.join(tempfile.gettempdir(), unique_filename)

        with open(temp_path, 'wb') as f:
            f.write(audio_data)

        if not os.path.exists(temp_path) or os.path.getsize(temp_path) == 0:
            return None

        segments, _ = WHISPER_MODEL.transcribe(temp_path, language='es')
        transcription = "".join(segment.text for segment in segments)

        if os.path.exists(temp_path):
            os.remove(temp_path)

        return transcription.strip()
    except Exception as e:
        raise e