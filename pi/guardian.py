import cv2
import numpy as np
import onnxruntime as ort
import os
import time
import threading
import subprocess
from datetime import datetime
from gpiozero import DigitalInputDevice, DigitalOutputDevice
from flask import Flask, Response

from config import (
    MODEL_PATH, CONFIDENCE_THRESHOLD, ALERT_COOLDOWN,
    SPEAKER_RELAY_PIN, IR_SENSOR_PIN, RADAR_SENSOR_PIN,
    PREDATOR_SOUNDS, SIREN_URL, CLASSES, TEMP_IMAGE,
    DEVICE_CODE, STREAM_PORT, SOUNDS_DIR,
)
import supabase as sb

print("--- Krishi Rakshak RPi Guardian ---")

# ── GPIO INITIALIZATION (GPIOZERO FOR RPI 5) ──────────────────
# Map physical BOARD pins to Raspberry Pi Broadcom (BCM) numbers
_BOARD_TO_BCM = {
    13: 27,  # Speaker Relay Signal
    16: 23,  # IR Sensor Signal
    18: 24   # Radar Sensor Signal
}

print("[GPIO] Initializing hardware lines via gpiozero...")
try:
    ir_sensor = DigitalInputDevice(_BOARD_TO_BCM[IR_SENSOR_PIN])
    radar_sensor = DigitalInputDevice(_BOARD_TO_BCM[RADAR_SENSOR_PIN])
    
    # active_high=False with initial_value=False means the relay pin boots up
    # in an open/HIGH state, keeping your amplifier completely powered OFF.
    speaker_relay = DigitalOutputDevice(
        _BOARD_TO_BCM[SPEAKER_RELAY_PIN], 
        active_high=False, 
        initial_value=False
    )
    print("[GPIO] Hardware lines linked successfully.")
except KeyError as e:
    print(f"[GPIO] Setup Error: Physical Board pin {e} is not in the BCM translation table!")
    exit(1)

# ── MODEL INITIALIZATION ──────────────────────────────────────
if not os.path.exists(MODEL_PATH):
    print(f"[MODEL] File not found: {MODEL_PATH}")
    print("[MODEL] Place best.onnx in the pi/ folder")
    exit(1)

print(f"[MODEL] Loading {MODEL_PATH}...")
session = ort.InferenceSession(MODEL_PATH)
input_name = session.get_inputs()[0].name
print("[MODEL] ONNX loaded")

# ── STATE MANAGEMENT ──────────────────────────────────────────
last_alert_time = 0
_last_sensor_time = 0
siren_active = False
auto_deterrence = False
is_live_requested = False
running = True

# ── SENSOR UTILITY METHODS ────────────────────────────────────
def sensor_tripped():
    """Returns True if either the IR wall beam or Radar sensor detects a breach."""
    return ir_sensor.is_active or radar_sensor.is_active


def relay_on():
    """Engages the relay circuit, sending power to the speaker amplifier."""
    speaker_relay.on()


def relay_off():
    """Drops the relay circuit, cutting power to the speaker amplifier."""
    speaker_relay.off()


# ── AUDIO HOOKS ───────────────────────────────────────────────
def _local_path(url):
    name = url.rsplit("/", 1)[-1]
    path = os.path.join(SOUNDS_DIR, name)
    if not os.path.exists(path):
        os.makedirs(SOUNDS_DIR, exist_ok=True)
        print(f"[AUDIO] Downloading {name}...")
        data = sb.download_audio(url)
        if data:
            with open(path, "wb") as f:
                f.write(data)
            print(f"[AUDIO] Cached: {path}")
        else:
            return None
    return path


def play_audio(url):
    path = _local_path(url)
    if not path:
        return

    relay_on()
    print(">>> Waiting for amplifier to stabilize...")
    time.sleep(2.0)

    ext = ".mp3" if ".mp3" in url else ".wav"
    try:
        if ext == ".mp3":
            subprocess.run(["mpg123", "-q", path], timeout=8)
        else:
            subprocess.run(["aplay", "-D", "plughw:1,0", path], timeout=8)
    except Exception as e:
        print(f"[AUDIO] Playback error: {e}")

    time.sleep(0.5)
    relay_off()


def activate_siren():
    print("[SIREN] Playing siren")
    path = _local_path(SIREN_URL)
    if not path:
        return

    relay_on()
    print(">>> Waiting for amplifier to stabilize...")
    time.sleep(2.0)

    try:
        subprocess.run(["mpg123", "-q", path], timeout=8)
    except Exception as e:
        print(f"[SIREN] Playback error: {e}")

    relay_off()


def play_predator_sound(detected_class):
    sound_url = PREDATOR_SOUNDS.get(detected_class.lower())
    if not sound_url:
        print(f"[AUDIO] No sound mapped for target: {detected_class}")
        return
    print(f"[AUDIO] Playing predator sound for: {detected_class}")
    play_audio(sound_url)


# ── CAPTURE + INFERENCE PIPELINE ──────────────────────────────
def capture_frame():
    """Triggers rpicam-still directly to output a fast image to volatile shared memory."""
    cmd = [
        "rpicam-still",
        "-t", "600",
        "--width", "640",
        "--height", "640",
        "-o", TEMP_IMAGE,
        "--immediate",
    ]
    subprocess.run(cmd, capture_output=True, text=True)
    return os.path.exists(TEMP_IMAGE)


def run_inference():
    frame = cv2.imread(TEMP_IMAGE)
    if frame is None:
        return None

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(rgb, (640, 640))
    input_data = resized.astype(np.float32) / 255.0
    input_data = np.transpose(input_data, (2, 0, 1))
    input_data = np.expand_dims(input_data, axis=0)

    outputs = session.run(None, {input_name: input_data})
    output_data = np.squeeze(outputs[0])
    output_data = np.transpose(output_data, (1, 0))

    scores = output_data[:, 4:]
    max_scores = np.max(scores, axis=1)
    max_class_ids = np.argmax(scores, axis=1)

    confident = np.where(max_scores > CONFIDENCE_THRESHOLD)[0]
    if len(confident) == 0:
        return None

    detected = set()
    for idx in confident:
        class_id = max_class_ids[idx]
        name = CLASSES.get(class_id, f"unknown_{class_id}")
        detected.add(name)

    return list(detected), frame


def handle_detection(detected_classes, frame):
    global last_alert_time

    now = time.time()
    if now - last_alert_time < ALERT_COOLDOWN:
        return
    last_alert_time = now

    print(f"[DETECTED TARGETS] {detected_classes}")

    _, buf = cv2.imencode(".jpg", frame)
    image_data = buf.tobytes()

    # Upload metrics asynchronously to prevent thread freezing
    image_url = sb.upload_image(image_data)
    for cls in detected_classes:
        sb.post_alert(cls, image_url)

    maybe_siren = siren_active
    maybe_auto = auto_deterrence

    if maybe_auto:
        play_predator_sound(detected_classes[0])

    if maybe_siren:
        activate_siren()


# ── STREAM SERVER (IN-PROCESS FLASK) ──────────────────────────
stream_app = Flask(__name__)
_streaming_active = False
ngrok_process = None


@stream_app.route("/video_feed")
def video_feed():
    def generate():
        proc = subprocess.Popen(
            ["rpicam-vid", "-t", "0", "--inline", "--codec", "mjpeg",
             "--width", "640", "--height", "640", "--framerate", "15", "-o", "-"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        SOI = b"\xff\xd8"
        EOI = b"\xff\xd9"
        buf = b""
        try:
            while _streaming_active:
                chunk = proc.stdout.read(65536)
                if not chunk:
                    break
                buf += chunk
                while True:
                    start = buf.find(SOI)
                    end = buf.find(EOI)
                    if start != -1 and end != -1 and end > start:
                        jpeg = buf[start : end + 2]
                        buf = buf[end + 2 :]
                        yield (
                            b"--jpgboundary\r\n"
                            b"Content-Type: image/jpeg\r\n\r\n"
                            + jpeg
                            + b"\r\n"
                        )
                    else:
                        break
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except:
                proc.kill()

    return Response(generate(), mimetype="multipart/x-mixed-replace; boundary=--jpgboundary")


@stream_app.route("/health")
def health():
    return {"status": "ok", "device_code": DEVICE_CODE}


def run_flask():
    stream_app.run(host="0.0.0.0", port=STREAM_PORT, debug=False, threaded=True)


def start_ngrok():
    global ngrok_process
    print("[NGROK] Starting tunnel...")
    ngrok_process = subprocess.Popen(
        ["ngrok", "http", str(STREAM_PORT)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(3)
    try:
        import httpx
        r = httpx.get("http://localhost:4040/api/tunnels", timeout=5)
        tunnels = r.json().get("tunnels", [])
        for t in tunnels:
            if t.get("proto") == "https":
                url = t["public_url"]
                sb.update_stream_url(f"{url}/video_feed")
                print(f"[NGROK] Public URL: {url}/video_feed")
                return
        print("[NGROK] No HTTPS tunnel found")
    except Exception as e:
        print(f"[NGROK] Error: {e}")
        # fallback to local IP
        try:
            ip = subprocess.run(["hostname", "-I"], capture_output=True, text=True).stdout.strip().split()[0]
            sb.update_stream_url(f"http://{ip}:{STREAM_PORT}/video_feed")
            print(f"[NGROK] Local fallback: http://{ip}:{STREAM_PORT}/video_feed")
        except:
            pass


def stop_ngrok():
    global ngrok_process
    if ngrok_process is not None:
        ngrok_process.terminate()
        try:
            ngrok_process.wait(timeout=5)
        except:
            ngrok_process.kill()
        ngrok_process = None
    sb.update_stream_url("")


# ── COMMAND POLLING SUBSYSTEM ─────────────────────────────────
def poll_loop():
    global siren_active, auto_deterrence, is_live_requested

    while running:
        device = sb.poll_commands()
        if device:
            new_siren = device.get("siren_active", False)
            new_auto = device.get("auto_deterrence", False)
            new_live = device.get("is_live_requested", False)

            if new_siren and not siren_active:
                print("[CMD] Cloud Request: Siren ON")
                siren_active = True
                threading.Thread(target=activate_siren, daemon=True).start()
            elif not new_siren:
                siren_active = False

            auto_deterrence = new_auto
            is_live_requested = new_live

        time.sleep(1)


# ── ENTRY RUNTIME LOOP ────────────────────────────────────────
def main():
    global running, _streaming_active, _last_sensor_time

    sb.register_device()
    _streaming_active = True

    flask_thread = threading.Thread(target=run_flask, daemon=True)
    flask_thread.start()
    time.sleep(1)

    start_ngrok()

    poll_thread = threading.Thread(target=poll_loop, daemon=True)
    poll_thread.start()

    print("\n=== Engine Active: Monitoring Passive Perimeter Lines ===")
    print(f"  Device: {DEVICE_CODE}")
    print(f"  Model:  {MODEL_PATH}")
    print(f"  IR Pin: {IR_SENSOR_PIN} (BOARD) -> BCM {_BOARD_TO_BCM[IR_SENSOR_PIN]}")
    print(f"  Radar Pin: {RADAR_SENSOR_PIN} (BOARD) -> BCM {_BOARD_TO_BCM[RADAR_SENSOR_PIN]}")
    print("=" * 55)

    try:
        while running:
            if sensor_tripped():
                # Wait for cooldown if sensor keeps retriggering
                now = time.time()
                if now - _last_sensor_time < 3:
                    time.sleep(0.1)
                    continue
                _last_sensor_time = now

                print(f"\n[SENSOR BREACH] Signal registered at {datetime.now().strftime('%H:%M:%S')}")

                if is_live_requested:
                    print("[SKIP] Detection paused – camera is in use by live stream")
                    time.sleep(5)
                    continue

                ok = capture_frame()
                if not ok:
                    print("[CAM ERROR] Hardware layer dropped frame request.")
                    time.sleep(0.5)
                    continue

                result = run_inference()
                
                # Delete temporary frame out of RAM disk space instantly
                if os.path.exists(TEMP_IMAGE):
                    os.remove(TEMP_IMAGE)

                if result is None:
                    print("[INF] Target context did not match animal vector profiles (False Alarm).")
                else:
                    detected, frame = result
                    handle_detection(detected, frame)

                print("[SENSOR] Boundary locked for 5s cooldown...")
                time.sleep(5)

            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n[EXIT] Keyboard interrupt captured. Disarming systems safely...")
    finally:
        running = False
        _streaming_active = False
        stop_ngrok()
        print("[EXIT] Done. Core baseline safe offline.")


if __name__ == "__main__":
    main()