import subprocess
import numpy as np
import scipy.signal

print("Extracting audio from both videos for sync check...")

cmd1 = [
    "ffmpeg", "-y", "-ss", "30", "-t", "60",
    "-i", "video_edition/media/raw/presentacion_entorno_screen_and_audio.mp4",
    "-ar", "16000", "-ac", "1", "-f", "f32le", "temp_audio_screen.raw"
]
cmd2 = [
    "ffmpeg", "-y", "-ss", "30", "-t", "60",
    "-i", "video_edition/media/raw/presentacion_entorno_over_shoulder.mp4",
    "-ar", "16000", "-ac", "1", "-f", "f32le", "temp_audio_camera.raw"
]

subprocess.run(cmd1, check=True)
subprocess.run(cmd2, check=True)

a1 = np.fromfile("temp_audio_screen.raw", dtype=np.float32)
a2 = np.fromfile("temp_audio_camera.raw", dtype=np.float32)

corr = scipy.signal.correlate(a1, a2, mode='full')
lags = scipy.signal.correlation_lags(len(a1), len(a2), mode='full')
lag = lags[np.argmax(corr)]
offset_sec = lag / 16000.0

print(f"Detected sync offset: {offset_sec:.3f} seconds (lag: {lag} samples)")

# Clean up
import os
os.remove("temp_audio_screen.raw")
os.remove("temp_audio_camera.raw")
