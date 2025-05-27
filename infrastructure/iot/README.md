# 🌐 Raspberry Pi Network Emulator

This project provides a Python script to emulate various network conditions (Ethernet, WiFi, 4G, 5G) on a Raspberry Pi using Linux traffic control (`tc`). It’s useful for testing applications under different simulated network environments.

---

## 📦 Requirements

- Raspberry Pi (or any Linux-based system)
- Python 3
- `tc` from the `iproute2` package

### Install Dependencies

```bash
sudo apt update
sudo apt install iproute2 python3
```

## 🚀 Usage

- Run the Script

```bash
sudo python3 network_emulator.py <profile> <interface>
```

> [!note]
> ⚠️ You must run this script with sudo to apply network configurations.

## 📁 Available Profiles

Profile Description Delay Bandwidth Packet Loss

| Profile    | Description                       | Delay | Bandwidth | Packet Loss |
| ---------- | --------------------------------- | ----- | --------- | ----------- |
| `ethernet` | Simulates wired Ethernet          | 1ms   | Unlimited | 0%          |
| `wifi`     | Simulates typical WiFi connection | 20ms  | Unlimited | 1%          |
| `4g`       | Simulates a 4G mobile network     | 50ms  | 20mbit    | 1%          |
| `5g`       | Simulates a 5G mobile network     | 10ms  | 100mbit   | 0%          |
| `clear`    | Resets all network emulation      | -     | -         | -           |

## Example

```bash

# Simulate 4G connection
sudo python3 network_emulator.py 4g eth0

# Simulate WiFi connection
sudo python3 network_emulator.py wifi eth0

# Clear all emulation settings
sudo python3 network_emulator.py clear eth0
```
