import cv2
import numpy as np
import onnxruntime as ort
import os
import time
import threading
import subprocess
import signal
from datetime import datetime

from config import (
    MODEL_PATH, CONFIDENCE_THRESHOLD, ALERT_COOLDOWN,
    SPEAKER_RELAY_PIN, IR_SENSOR_PIN, RADAR_SENSOR_PIN,
    PREDATOR_SOUNDS, SIREN_URL, CLASSES, TEMP_IMAGE,
    DEVICE_CODE, STREAM_PORT,
)
import supabase as sb

print("--- Krishi Rakshak RPi Guardian ---")

# ── GPIO ──────────────────────────────────────────────────────
try:
    import RPi.GPIO as GPIO
    GPIO.setmode(GPIO.BOARD)
    GPIO.setwarnings(False)
    GPIO.setup(SPEAKER_RELAY_PIN, GPIO.OUT)
    GPIO.output(SPEAKER_RELAY_PIN, GPIO.HIGH)
    GPIO.setup(IR_SENSOR_PIN, GPIO.IN)
    GPIO.setup(RADAR_SENSOR_PIN, GPIO.IN)
    GPIO_AVAILABLE = True
    print("[GPIO] Initialized")
except Exception as e:
    print(f"[GPIO] Not available (using mock): {e}")
    GPIO_AVAILABLE = False

# ── MODEL ─────────────────────────────────────────────────────
if not os.path.exists(MODEL_PATH):
    print(f"[MODEL] File not found: {MODEL_PATH}")
    print("[MODEL] Place best.onnx in the pi/ folder")
    exit(1)

print(f"[MODEL] Loading {MODEL_PATH}...")
session = ort.InferenceSession(MODEL_PATH)
input_name = session.get_inputs()[0].name
print("[MODEL] ONNX loaded")

# ── STATE ─────────────────────────────────────────────────────
last_alert_time = 0
siren_active = False
auto_deterrence = False
is_live_requested = False
stream_process = None
running = True

# ── SENSOR HELPERS ────────────────────────────────────────────
def sensor_tripped():
    if not GPIO_AVAILABLE:
        return False
    return GPIO.input(IR_SENSOR_PIN) or GPIO.input(RADAR_SENSOR_PIN)


def relay_on():
    if GPIO_AVAILABLE:
        GPIO.output(SPEAKER_RELAY_PIN, GPIO.LOW)


def relay_off():
    if GPIO_AVAILABLE:
        GPIO.output(SPEAKER_RELAY_PIN, GPIO.HIGH)


# ── AUDIO ────────────────────────────────────────────────────
def play_audio(url):
    data = sb.download_audio(url)
    if not data:
        return

    ext = ".mp3" if ".mp3" in url else ".wav"
    tmp = f"/tmp/audio_{int(time.time())}{ext}"
    with open(tmp, "wb") as f:
        f.write(data)

    relay_on()
    time.sleep(1.5)

    try:
        if ext == ".mp3":
            subprocess.run(["mpg123", "-q", tmp], timeout=8)
        else:
            subprocess.run(["aplay", tmp], timeout=8)
    except:
        pass

    time.sleep(0.5)
    relay_off()
    try:
        os.remove(tmp)
    except:
        pass


def activate_siren():
    print("[SIREN] Playing siren")
    data = sb.download_audio(SIREN_URL)
    if not data:
        return

    tmp = "/tmp/siren.mp3"
    with open(tmp, "wb") as f:
        f.write(data)

    relay_on()
    time.sleep(1.5)

    try:
        subprocess.run(["mpg123", "-q", tmp], timeout=8)
    except:
        pass

    relay_off()
    try:
        os.remove(tmp)
    except:
        pass


def play_predator_sound(detected_class):
    sound_url = PREDATOR_SOUNDS.get(detected_class.lower())
    if not sound_url:
        print(f"[AUDIO] No sound for {detected_class}")
        return
    print(f"[AUDIO] Predator sound for {detected_class}")
    play_audio(sound_url)


# ── CAPTURE + INFERENCE ──────────────────────────────────────
def capture_frame():
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

    print(f"[DETECT] {detected_classes}")

    _, buf = cv2.imencode(".jpg", frame)
    image_data = buf.tobytes()

    image_url = sb.upload_image(image_data)
    for cls in detected_classes:
        sb.post_alert(cls, image_url)

    maybe_siren = siren_active
    maybe_auto = auto_deterrence

    if maybe_auto:
        play_predator_sound(detected_classes[0])

    if maybe_siren:
        activate_siren()


# ── STREAM MANAGER ───────────────────────────────────────────
def start_stream():
    global stream_process
    if stream_process is not None:
        return
    print("[STREAM] Starting stream server")
    script = os.path.join(os.path.dirname(__file__), "stream_server.py")
    stream_process = subprocess.Popen(
        ["python3", script],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(3)

    import httpx
    try:
        ip = subprocess.run(
            ["hostname", "-I"], capture_output=True, text=True
        ).stdout.strip().split()[0]
        url = f"http://{ip}:{STREAM_PORT}"
        sb.update_stream_url(url)
        print(f"[STREAM] URL updated: {url}")
    except:
        pass


def stop_stream():
    global stream_process
    if stream_process is None:
        return
    print("[STREAM] Stopping stream server")
    stream_process.terminate()
    try:
        stream_process.wait(timeout=5)
    except:
        stream_process.kill()
    stream_process = None
    sb.update_stream_url("")


# ── COMMAND POLLER ───────────────────────────────────────────
def poll_loop():
    global siren_active, auto_deterrence, is_live_requested

    while running:
        device = sb.poll_commands()
        if device:
            new_siren = device.get("siren_active", False)
            new_auto = device.get("auto_deterrence", False)
            new_live = device.get("is_live_requested", False)

            if new_siren and not siren_active:
                print("[CMD] Siren ON")
                siren_active = True
                threading.Thread(target=activate_siren, daemon=True).start()
            elif not new_siren:
                siren_active = False

            auto_deterrence = new_auto

            if new_live and not is_live_requested:
                is_live_requested = True
                start_stream()
            elif not new_live and is_live_requested:
                is_live_requested = False
                stop_stream()

        time.sleep(1)


# ── MAIN ──────────────────────────────────────────────────────
def main():
    global running

    sb.register_device()

    poll_thread = threading.Thread(target=poll_loop, daemon=True)
    poll_thread.start()

    print("\n=== Guardian active – waiting for sensors ===")
    print(f"  Device: {DEVICE_CODE}")
    print(f"  Model:  {MODEL_PATH}")
    print(f"  IR pin: {IR_SENSOR_PIN}  Radar pin: {RADAR_SENSOR_PIN}")
    print("=" * 40)

    try:
        while running:
            if sensor_tripped():
                print(f"\n[SENSOR] Triggered at {datetime.now().strftime('%H:%M:%S')}")

                ok = capture_frame()
                if not ok:
                    print("[CAM] Capture failed")
                    time.sleep(0.5)
                    continue

                result = run_inference()
                os.remove(TEMP_IMAGE)

                if result is None:
                    print("[INF] No animal detected (false alarm)")
                else:
                    detected, frame = result
                    handle_detection(detected, frame)

                print("[SENSOR] Cooldown 5s")
                time.sleep(5)

            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n[EXIT] Shutting down...")
    finally:
        running = False
        stop_stream()
        if GPIO_AVAILABLE:
            GPIO.cleanup()
        print("[EXIT] Done")


if __name__ == "__main__":
    main()
