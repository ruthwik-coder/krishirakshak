import os

# Supabase
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://cnbrwbibvlbzzztenfzr.supabase.co")
SUPABASE_PUBLIC = f"{SUPABASE_URL}/storage/v1/object/public"
SERVICE_ROLE_KEY = os.getenv("SERVICE_ROLE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
)

DEVICE_CODE = os.getenv("DEVICE_CODE", "RPI001")
OWNER_ID = os.getenv("OWNER_ID", "1394378f-581f-4a69-9367-7d46b72649c3")

# Model
MODEL_PATH = os.getenv("MODEL_PATH", "best.onnx")
CONFIDENCE_THRESHOLD = float(os.getenv("CONFIDENCE_THRESHOLD", "0.4"))
ALERT_COOLDOWN = int(os.getenv("ALERT_COOLDOWN", "10"))

# GPIO pins (BOARD layout)
SPEAKER_RELAY_PIN = int(os.getenv("SPEAKER_RELAY_PIN", "13"))
IR_SENSOR_PIN = int(os.getenv("IR_SENSOR_PIN", "16"))
RADAR_SENSOR_PIN = int(os.getenv("RADAR_SENSOR_PIN", "18"))

# Audio
PREDATOR_SOUNDS = {
    "goat":     f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "buffalo":  f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "elephant": f"{SUPABASE_PUBLIC}/assets/sounds/elephant/Bee_1.mp3",
    "zebra":    f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "bird":     f"{SUPABASE_PUBLIC}/assets/sounds/elephant/Bee_1.mp3",
    "pig":      f"{SUPABASE_PUBLIC}/assets/sounds/pig/dog_1.wav",
    "leopard":  f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "cheetah":  f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "bear":     f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "bull":     f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "horse":     f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "deer":     f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "monkey":   f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "sheep":    f"{SUPABASE_PUBLIC}/assets/sounds/cow/Tiger_1.mp3",
    "person":   f"{SUPABASE_PUBLIC}/assets/sounds/person/siren.mp3",
}
SIREN_URL = f"{SUPABASE_PUBLIC}/assets/siren.mp3"

# YOLO class names (14 classes, matching your model)
CLASSES = {
    0: "buffalo", 1: "elephant", 2: "zebra", 3: "bird", 4: "pig",
    5: "leopard", 6: "cheetah", 7: "bear", 8: "bull", 9: "horse",
    10: "deer", 11: "monkey", 12: "goat", 13: "sheep", 14: "person",
}

TEMP_IMAGE = "/dev/shm/snapshot.jpg"
STREAM_PORT = 5000
