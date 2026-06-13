import time
from gpiozero import DigitalInputDevice

IR_PIN = 23
RADAR_PIN = 24

print("=== GPIO Sensor Test ===")
print(f"IR:     BCM {IR_PIN} (BOARD 16)")
print(f"Radar:  BCM {RADAR_PIN} (BOARD 18)")
print()

print("Testing normal polarity (pull_up=False)...")
ir = DigitalInputDevice(IR_PIN)
radar = DigitalInputDevice(RADAR_PIN)

try:
    for _ in range(100):
        ir_v = "TRIPPED" if ir.is_active else "------"
        r_v = "TRIPPED" if radar.is_active else "------"
        s = f"IR: {ir_v}  |  Radar: {r_v}"
        print(s, end="\r")
        time.sleep(0.1)
except KeyboardInterrupt:
    pass

ir.close()
radar.close()
print("\n\nTesting inverted polarity for radar (pull_up=True)...")
time.sleep(0.5)

radar_inv = DigitalInputDevice(RADAR_PIN, pull_up=True)

try:
    for _ in range(100):
        r_v = "TRIPPED" if radar_inv.is_active else "------"
        print(f"Radar(inv): {r_v}", end="\r")
        time.sleep(0.1)
except KeyboardInterrupt:
    pass

radar_inv.close()
print("\nDone")
