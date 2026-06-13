import time
from gpiozero import DigitalInputDevice

IR_PIN = 23
RADAR_PIN = 24

print("=== GPIO Sensor Test ===")
print(f"IR:     BCM {IR_PIN} (BOARD 16)")
print(f"Radar:  BCM {RADAR_PIN} (BOARD 18)")
print()

ir = DigitalInputDevice(IR_PIN)
radar = DigitalInputDevice(RADAR_PIN)
radar_inv = DigitalInputDevice(RADAR_PIN, pull_up=True)  # inverted polarity

print(" Wave hand over each sensor. Ctrl+C to quit.\n")

try:
    while True:
        ir_v = "TRIPPED" if ir.is_active else "------"
        r_v = "TRIPPED" if radar.is_active else "------"
        r2_v = "TRIPPED" if radar_inv.is_active else "------"
        s = f"IR: {ir_v}  |  Radar: {r_v}  |  Radar(inv): {r2_v}"
        print(s, end="\r")
        time.sleep(0.05)
except KeyboardInterrupt:
    print("\nDone")
