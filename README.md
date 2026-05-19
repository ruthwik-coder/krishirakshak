# krishirakshak

Farm security system with real-time object detection, two-way audio, and mobile alerts.

## Features

- **Real-time Object Detection** - YOLOv8-based detection for farm intruders
- **Live Video Streaming** - MJPEG stream via ngrok tunnel
- **Two-Way Audio** - Talk through the camera from your phone
- **Mobile Alerts** - Push notifications when intruders detected
- **Auto-Deterrence** - Plays predator sounds to scare animals
- **Siren Control** - Remote alarm activation

## Project Structure

```
krishirakshak/
├── lib/                 # Flutter app code
├── android/            # Android configuration
├── server/             # Camera server (laptop/desktop)
│   ├── camera_server.py
│   ├── requirements.txt
│   └── SETUP.md
├── pi/                 # Raspberry Pi server (lightweight)
│   ├── guardian.py     #   Sensor-triggered detection loop
│   ├── stream_server.py #   On-demand live streaming
│   ├── supabase.py     #   Shared Supabase helpers
│   ├── config.py       #   Configuration
│   └── requirements.txt
├── assets/
├── build/              # APK output
└── README.md
```

## Quick Start

### Flutter App

```bash
flutter pub get
flutter run
flutter build apk --release
```

### Camera Server (Laptop)

```bash
cd server
pip install -r requirements.txt
python camera_server.py
```

### Camera Server (Raspberry Pi)

```bash
cd pi
pip install -r requirements.txt
python guardian.py
```

## Laptop vs Pi

| Feature | `server/` (Laptop) | `pi/` (Raspberry Pi) |
|---------|-------------------|---------------------|
| Model format | `best.pt` (PyTorch) | `best.onnx` (ONNX) |
| Runtime | Ultralytics YOLOv8 (heavy) | ONNX Runtime (lightweight) |
| Camera access | `cv2.VideoCapture` | `rpicam-still` / `rpicam-vid` |
| Detection mode | 24/7 always-on | Sensor-triggered (IR + Radar) |
| Live stream | Built into Flask server | Separate process on demand |
| GPIO support | ❌ | ✅ IR, Radar, Speaker relay |

## Model Files

Place your trained models (not included in repo):

| Platform | Path | Format |
|----------|------|--------|
| Laptop | `server/best.pt` | PyTorch (YOLOv8) |
| Pi | `pi/best.onnx` | ONNX (exported from YOLOv8) |

To export YOLOv8 to ONNX:
```bash
yolo export model=best.pt format=onnx imgsz=640
# Copy best.onnx to pi/best.onnx
```

## Database Schema

### device_registrations
```sql
device_code TEXT PRIMARY KEY
owner_id UUID
area_name TEXT
stream_url TEXT
is_activated BOOLEAN
siren_active BOOLEAN
auto_deterrence BOOLEAN
is_live_requested BOOLEAN
is_talking BOOLEAN
```

### alerts
```sql
id BIGSERIAL PRIMARY KEY
device_code TEXT
intruder_type TEXT
image_url TEXT
owner_id UUID
created_at TIMESTAMPTZ
```

## Pi Wiring (BOARD pin layout)

| Pin | Component |
|-----|-----------|
| 11  | IR sensor (input) |
| 15  | Radar sensor (input) |
| 13  | Speaker relay (output) |

## ngrok Setup

```bash
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

## Detected Classes

goat, buffalo, elephant, zebra, bird, pig, leopard, cheetah, bear, bull, horse, deer, monkey, sheep, person

## License

MIT