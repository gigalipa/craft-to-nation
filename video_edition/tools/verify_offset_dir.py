import subprocess
import numpy as np
import scipy.signal

print("Verifying precise offset direction...")

# Extract 10 seconds of both audios around t=60s
cmd1 = [
    "ffmpeg", "-y", "-ss", "60", "-t", "10",
    "-i", "video_edition/media/raw/presentacion_entorno_screen_and_audio.mp4",
    "-ar", "48000", "-ac", "1", "-f", "f32le", "temp_screen_48k.raw"
]
cmd2 = [
    "ffmpeg", "-y", "-ss", "60", "-t", "10",
    "-i", "video_edition/media/raw/presentacion_entorno_over_shoulder.mp4",
    "-ar", "48000", "-ac", "1", "-f", "f32le", "temp_cam_48k.raw"
]
subprocess.run(cmd1, check=True)
subprocess.run(cmd2, check=True)

s1 = np.fromfile("temp_screen_48k.raw", dtype=np.float32)
s2 = np.fromfile("temp_cam_48k.raw", dtype=np.float32)

corr = scipy.signal.correlate(s1, s2, mode='full')
lags = scipy.signal.correlation_lags(len(s1), len(s2), mode='full')
lag = lags[np.argmax(corr)]
offset_sec = lag / 48000.0

print(f"Lag: {lag} samples at 48kHz = {offset_sec:.4f} seconds")
# If lag > 0: s1 is delayed relative to s2, or s2 occurs earlier than s1?
# In correlate(s1, s2):
# corr[k] = sum_n s1[n] * s2[n - lag]
# When lag > 0, s2[n - lag] matches s1[n], so s1 has features shifted to the right (later in time) relative to s2.
# So s1 is behind s2 by `offset_sec`. That means camera started `offset_sec` earlier.
import os
os.remove("temp_screen_48k.raw")
os.remove("temp_cam_48k.raw")
