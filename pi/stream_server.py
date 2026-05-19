import subprocess
import threading
import time
from flask import Flask, Response

from config import DEVICE_CODE, STREAM_PORT

app = Flask(__name__)
streaming = True

def frame_generator():
    cmd = [
        "rpicam-vid",
        "-t", "0",
        "--inline",
        "--codec", "mjpeg",
        "--width", "640",
        "--height", "640",
        "--framerate", "15",
        "-o", "-",
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

    SOI = b"\xff\xd8"
    EOI = b"\xff\xd9"
    buf = b""

    try:
        while streaming:
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


@app.route("/video_feed")
def video_feed():
    return Response(
        frame_generator(),
        mimetype="multipart/x-mixed-replace; boundary=--jpgboundary",
    )


@app.route("/health")
def health():
    return {"status": "ok", "device_code": DEVICE_CODE}


if __name__ == "__main__":
    print(f"[STREAM] Starting on port {STREAM_PORT}")
    app.run(host="0.0.0.0", port=STREAM_PORT, debug=False, threaded=True)
