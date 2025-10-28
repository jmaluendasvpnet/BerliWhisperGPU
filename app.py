from processing_whisper import run_transcription_internal
from flask import Flask, request, jsonify
from waitress import serve
import os

app = Flask(__name__)

INTERNAL_API_KEY = os.environ.get("INTERNAL_API_KEY", "JMalu-BerliDATA")

@app.route('/api/v1/process/transcribe', methods=['POST'])
def transcribe_api_flask():
    api_key = request.headers.get('X-Internal-API-Key')
    if not api_key or api_key != INTERNAL_API_KEY:
        return jsonify({'error': 'No autorizado'}), 403

    try:
        if 'audio_file' not in request.files:
            return jsonify({'error': 'No se proporcionó "audio_file"'}), 400

        audio_file = request.files['audio_file']
        file_extension = request.form.get('file_extension', 'ogg')
        audio_data = audio_file.read()

        transcription = run_transcription_internal(audio_data, file_extension)

        return jsonify({'transcription': transcription, 'status': 'ok'})

    except Exception as e:
        print(f"Error vista transcribe_api_flask: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    host = '0.0.0.0'
    port = 3109
    print(f"Iniciando servidor Whisper en http://{host}:{port}")
    serve(app, host=host, port=port)