import httpx
import os
import time
from datetime import datetime
from config import (
    SUPABASE_URL, SERVICE_ROLE_KEY, DEVICE_CODE, OWNER_ID,
    SUPABASE_PUBLIC
)

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

STORAGE_HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "image/jpeg",
}


def _retry(fn, *args, retries=3, delay=2, **kwargs):
    for attempt in range(retries):
        try:
            return fn(*args, **kwargs)
        except Exception as e:
            if attempt == retries - 1:
                raise
            print(f"[RETRY] {e} – retrying in {delay}s ({attempt+1}/{retries})")
            time.sleep(delay)


def upload_image(image_data):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{DEVICE_CODE}/{timestamp}.jpg"

    try:
        r = _retry(httpx.post, f"{SUPABASE_URL}/storage/v1/object/detections/{filename}",
                   headers=STORAGE_HEADERS, content=image_data, timeout=30)
        if r.status_code in (200, 201):
            url = f"{SUPABASE_PUBLIC}/detections/{filename}"
            print(f"[STORAGE] Uploaded: {url}")
            return url
        print(f"[STORAGE] Upload failed: {r.status_code} {r.text}")
    except Exception as e:
        print(f"[STORAGE] Error: {e}")
    return ""


def post_alert(intruder_type, image_url):
    payload = {
        "device_code": DEVICE_CODE,
        "intruder_type": intruder_type,
        "image_url": image_url,
        "owner_id": OWNER_ID,
    }

    try:
        r = _retry(httpx.post, f"{SUPABASE_URL}/rest/v1/alerts",
                   headers=HEADERS, json=payload, timeout=10)
        if r.status_code in (200, 201):
            print(f"[ALERT] Logged: {intruder_type}")
        else:
            print(f"[ALERT] Failed: {r.status_code} {r.text}")
    except Exception as e:
        print(f"[ALERT] Error: {e}")


def register_device(stream_url=""):
    payload = {
        "device_code": DEVICE_CODE,
        "is_activated": True,
        "stream_url": stream_url,
        "siren_active": False,
        "auto_deterrence": False,
        "is_live_requested": False,
        "is_talking": False,
    }

    try:
        r = _retry(httpx.post, f"{SUPABASE_URL}/rest/v1/device_registrations",
                   headers={**HEADERS, "Prefer": "resolution=merge-duplicates"},
                   json=payload, timeout=10)
        print(f"[REGISTER] Device registered: {r.status_code}")
    except Exception as e:
        print(f"[REGISTER] Error: {e}")


def update_stream_url(url):
    if url and not url.endswith("/video_feed"):
        url = f"{url}/video_feed"
    try:
        r = _retry(httpx.patch, f"{SUPABASE_URL}/rest/v1/device_registrations?device_code=eq.{DEVICE_CODE}",
                   headers=HEADERS, json={"stream_url": url}, timeout=10)
        print(f"[UPDATE] Stream URL: {r.status_code}")
    except Exception as e:
        print(f"[UPDATE] Error: {e}")


def poll_commands():
    try:
        r = _retry(httpx.get, f"{SUPABASE_URL}/rest/v1/device_registrations?device_code=eq.{DEVICE_CODE}",
                   headers=HEADERS, timeout=10, retries=1)
        if r.status_code == 200:
            data = r.json()
            if data:
                return data[0]
    except Exception as e:
        print(f"[POLL] Error: {e}")
    return None


def download_audio(url):
    try:
        r = _retry(httpx.get, url, timeout=10, follow_redirects=True, retries=2)
        if r.status_code == 200:
            return r.content
    except Exception as e:
        print(f"[AUDIO] Download error: {e}")
    return None
