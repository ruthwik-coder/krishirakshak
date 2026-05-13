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
├── server/             # Camera server (runs on laptop/PI)
│   ├── camera_server.py
│   ├── requirements.txt
│   └── SETUP.md
├── build/              # APK output
└── README.md
```

## Quick Start

### Flutter App

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build APK
flutter build apk --release
```

### Camera Server

```bash
cd server

# Install dependencies
pip install -r requirements.txt

# Run server
python camera_server.py
```

## Requirements

### App
- Flutter SDK 3.11+
- Android SDK
- Supabase account

### Camera Server
- Python 3.8+
- Webcam or IP camera
- ngrok account (free tier works)
- YOLOv8 model (best.pt)

## Configuration

### Supabase Setup

1. Create a Supabase project
2. Get your URL and anon key
3. Update keys in:
   - `lib/main.dart`
   - `server/camera_server.py`

### Database Schema

**device_registrations**
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

**alerts**
```sql
id BIGSERIAL PRIMARY KEY
device_code TEXT
intruder_type TEXT
image_url TEXT
owner_id UUID
created_at TIMESTAMPTZ
```

### ngrok Setup

```bash
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

Get token from: https://dashboard.ngrok.com

## Detected Classes

The model detects: goat, buffalo, elephant, zebra, bird, pig, leopard, cheetah, bear, bull, horse, deer, monkey, sheep, person

## License

MIT