# KRISHI RAKSHAK - Camera Server Setup

## Prerequisites

### 1. Install Python 3.8+
Download from python.org

### 2. Install ngrok
1. Go to https://ngrok.com/download
2. Create free account at https://dashboard.ngrok.com
3. Download and extract ngrok
4. Connect your account:
   ```
   ngrok config add-authtoken YOUR_AUTH_TOKEN
   ```
   Get your auth token from: https://dashboard.ngrok.com/get-started

### 3. Place your model
Copy your trained model file (best.pt) to:
```
server/best.pt
```

## Installation

```bash
cd server
pip install -r requirements.txt
```

## Configuration

Edit `camera_server.py` if needed:
```python
DEVICE_CODE = "LAPTOP001"      # Unique ID for this camera
MODEL_PATH = "best.pt"         # Your YOLO model
CAMERA_INDEX = 0               # 0 for default webcam
CONFIDENCE_THRESHOLD = 0.6    # Detection sensitivity
```

## Running

```bash
cd server
python camera_server.py
```

## Features

### What this does:
1. **Streams video** to the app via MJPEG at `/video_feed`
2. **Object detection** using YOLOv8 model
3. **Captures images** when intruder detected (saved to `captures/`)
4. **Posts alerts** to Supabase → app gets notified
5. **Two-way audio** - app can talk through the camera
6. **Siren control** - app can trigger alarm
7. **Auto-deterrence** - plays predator sounds automatically

### ngrok Requirements:
- **YES, ngrok needs authentication**
- Free tier works fine
- Get auth token from: https://dashboard.ngrok.com
- Run: `ngrok config add-authtoken YOUR_TOKEN`

## Troubleshooting

### "Camera not available"
- Check CAMERA_INDEX (try 0, 1, 2)
- Or use IP camera URL:
  ```python
  CAMERA_INDEX = "rtsp://username:password@camera_ip:554/stream"
  ```

### "Model not loading"
- Verify `best.pt` is in the server folder
- Check ultralytics can load it

### "Supabase connection failed"
- Verify project is active at cnbrwbibvlbzzztenfzr.supabase.co
- Check internet connection

### "ngrok tunnel not starting"
- Run `ngrok config add-authtoken YOUR_AUTH_TOKEN` first
- Check ngrok is in your PATH

## Sound Files (Optional)

Create `sounds/` folder with predator sounds:
- hawk.wav
- wolf.wav
- lion.wav
- bear.wav

These play when auto-deterrence is enabled.

## Supabase Database Schema

The server expects these tables in Supabase:

### device_registrations
| Column | Type | Description |
|--------|------|-------------|
| device_code | text | Primary key |
| password | text | Device auth |
| owner_id | uuid | User ID (set when app links device) |
| stream_url | text | ngrok URL |
| siren_active | bool | Control siren |
| auto_deterrence | bool | Auto predator sounds |
| is_live_requested | bool | App watching stream |
| is_talking | bool | App transmitting audio |
| is_activated | bool | Device active |

### alerts
| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Auto-increment |
| device_code | text | Camera ID |
| intruder_type | text | Detected class |
| confidence | float | Detection confidence |
| image_url | text | Storage URL |
| created_at | timestamp | Alert time |