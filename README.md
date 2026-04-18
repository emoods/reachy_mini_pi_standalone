# Reachy Mini 🤖

[![Ask on HuggingChat](https://img.shields.io/badge/Read_the-Documentation-yellow?logo=huggingface&logoColor=yellow)](https://huggingface.co/docs/reachy_mini/)
[![Discord](https://img.shields.io/badge/Discord-Join_the_Community-7289DA?logo=discord&logoColor=white)](https://discord.gg/Y7FgMqHsub)

**Reachy Mini is an open-source, expressive robot made for hackers and AI builders.**

🛒 [**Buy Reachy Mini**](https://www.hf.co/reachy-mini/)

[![Reachy Mini Hello](/docs/assets/reachy_mini_hello.gif)](https://www.pollen-robotics.com/reachy-mini/)

## ⚡️ Build and start your own robot

**Choose your platform to access the specific guide:**

| **🤖 Reachy Mini (Wireless)** | **🔌 Reachy Mini Lite** | **💻 Simulation** | **🖥️ Standalone** |
| :---: | :---: | :---: | :---: |
| The full autonomous experience.<br>Raspberry Pi CM4 + Battery + WiFi. | The developer version.<br>USB connection to your computer. | No hardware required.<br>Prototype in MuJoCo. | Run a Lite untethered on a<br>Raspberry Pi 4/5 over WiFi. |
| 👉 [**Go to Wireless Guide**](https://huggingface.co/docs/reachy_mini/platforms/reachy_mini/get_started) | 👉 [**Go to Lite Guide**](https://huggingface.co/docs/reachy_mini/platforms/reachy_mini_lite/get_started) | 👉 [**Go to Simulation**](https://huggingface.co/docs/reachy_mini/platforms/simulation/get_started) | 👉 [**Standalone Setup**](#%EF%B8%8F-standalone-mode-reachy-mini-lite-on-raspberry-pi) |



> ⚡ **Pro tip:** Install [uv](https://docs.astral.sh/uv/getting-started/installation/) for 10-100x faster app installations (auto-detected, falls back to `pip`).

<br>

## 📱 Apps & Ecosystem

Reachy Mini comes with an app store powered by Hugging Face Spaces. You can install these apps directly from your robot's dashboard with one click!

* **🗣️ [Conversation App](https://huggingface.co/spaces/pollen-robotics/reachy_mini_conversation_app):** Talk naturally with Reachy Mini (powered by LLMs).
* **📻 [Radio](https://huggingface.co/spaces/pollen-robotics/reachy_mini_radio):** Listen to the radio with Reachy Mini!
* **👋 [Hand Tracker](https://huggingface.co/spaces/pollen-robotics/hand_tracker_v2):** The robot follows your hand movements in real-time.

👉 [**Browse all apps on Hugging Face**](https://hf.co/reachy-mini/#/apps)

<br>

## 🚀 Getting Started with Reachy Mini SDK

### User guides
* **[Installation](https://huggingface.co/docs/reachy_mini/SDK/installation)**: 5 minutes to set up your computer
* **[Quickstart Guide](https://huggingface.co/docs/reachy_mini/SDK/quickstart)**: Run your first behavior on Reachy Mini
* **[Python SDK](https://huggingface.co/docs/reachy_mini/SDK/python-sdk)**: Learn to move, see, speak, and hear.
* **[AI Integrations](https://huggingface.co/docs/reachy_mini/SDK/integration)**: Connect LLMs, build Apps, and publish to Hugging Face.
* **[Core Concepts](https://huggingface.co/docs/reachy_mini/SDK/core-concept)**: Architecture, coordinate systems, and safety limits.
* 🤗[**Share your app with the community**](https://huggingface.co/blog/pollen-robotics/make-and-publish-your-reachy-mini-apps)
* 📂 [**Browse the Examples Folder**](examples)
* 📓 [**Tutorial Notebooks**](docs/notebooks): Step-by-step Jupyter notebooks covering connection, movement, camera, and audio

### 🤖 AI-Assisted Development

Using an AI coding agent (Claude Code, Codex, Copilot, etc.)? You can start building apps right away. Paste this prompt to your agent:

> *I'd like to create a Reachy Mini app. Start by reading https://github.com/pollen-robotics/reachy_mini/blob/develop/AGENTS.md*

This [**AGENTS.md**](AGENTS.md) guide gives AI agents everything they need: SDK patterns, best practices, example apps, and step-by-step skills.

### Quick Look
After [installing the SDK](https://huggingface.co/docs/reachy_mini/SDK/installation), once your robot is awake, you can control it in just **a few lines of code**:

```python
from reachy_mini import ReachyMini
from reachy_mini.utils import create_head_pose

with ReachyMini() as mini:
    # Look up and tilt head
    mini.goto_target(
        head=create_head_pose(z=10, roll=15, degrees=True, mm=True),
        duration=1.0
    )
```

<br>

## 🛠 Hardware Overview

Reachy Mini robots are sold as kits and generally take **2 to 3 hours** to assemble. Detailed step-by-step guides are available in the platform-specific folders linked above.

* **Reachy Mini (Wireless):** Runs onboard (RPi CM4), autonomous, includes IMU. [See specs](https://huggingface.co/docs/reachy_mini/platforms/reachy_mini/hardware).
* **Reachy Mini Lite:** Runs on your PC, powered via wall outlet. [See specs](https://huggingface.co/docs/reachy_mini/platforms/reachy_mini_lite/hardware).

<br>

## 🖥️ Standalone Mode: Reachy Mini Lite on Raspberry Pi

Run a USB-tethered Reachy Mini Lite on a standalone Raspberry Pi (4, 5, or similar Linux SBC) as a network-accessible daemon — giving you the wireless Reachy Mini experience without the CM4 Compute Module.

Tested on **Raspberry Pi 4** (4GB RAM) running Debian Trixie. Should also work on **Raspberry Pi 5**, **Raspberry Pi Zero 2 W**, or other ARM64 Linux boards with USB ports.

### What it does

The `--standalone` flag:
- Uses USB serial (CH34x) for motor control — no UART, no IMU
- Reports as wireless-capable so the desktop app enables WebRTC camera streaming
- Binds to all network interfaces (accessible from other machines on your LAN)
- Auto-generates `~/.asoundrc` for the Reachy Mini Audio card at startup
- Uses hardware H.264 encoding (`v4l2h264enc`) when available, falls back to software VP8

### Prerequisites

| Component | Details |
|-----------|---------|
| **Board** | Raspberry Pi 3/4/5 (4GB+ RAM recommended), 64-bit Raspberry Pi OS or Debian Trixie |
| **System packages** | See [apt install](#system-dependencies) below |
| **webrtcsink** | `gst-plugins-rs` v0.14.x — [download pre-built binary](#installing-webrtcsink) or [build from source](#building-webrtcsink-from-source) |
| **udev rules** | Grant USB access to the Lite's audio/camera devices (VID `38fb`) |

### System dependencies

```bash
# Build tools and runtime libraries for reachy_mini Python packages
sudo apt install -y \
  git git-lfs pkg-config cmake \
  libcairo2-dev libgl1 libportaudio2

# GObject introspection (required for GStreamer Python bindings)
sudo apt install -y \
  libgirepository1.0-dev gir1.2-glib-2.0 libglib2.0-dev

# GStreamer runtime + tools + introspection typelibs
sudo apt install -y \
  gstreamer1.0-tools \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-alsa \
  gstreamer1.0-pipewire \
  gstreamer1.0-nice \
  gir1.2-gstreamer-1.0 \
  gir1.2-gst-plugins-base-1.0
```

### Quick start

**Option A: Automated install** (recommended)

```bash
curl -sSL https://raw.githubusercontent.com/emoods/reachy_mini/main/scripts/install-standalone.sh | bash
```

This installs everything in one go: system packages, udev rules, webrtcsink, the repository, Python dependencies, and a systemd service. Takes ~2-3 minutes. See [`scripts/install-standalone.sh`](scripts/install-standalone.sh) for details.

**Option B: Manual install**

```bash
# Clone and install
git clone https://github.com/pollen-robotics/reachy_mini.git
cd reachy_mini
uv sync

# Set GStreamer plugin path (adjust if you installed elsewhere)
export GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/aarch64-linux-gnu/gstreamer-1.0

# Run the daemon
reachy-mini-daemon --standalone
```

### udev rules

Create `/etc/udev/rules.d/99-reachy-mini-lite.rules`:

```
SUBSYSTEM=="usb", ATTR{idVendor}=="38fb", ATTR{idProduct}=="1001", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="38fb", ATTR{idProduct}=="1002", MODE="0666"
```

Then reload: `sudo udevadm control --reload-rules && sudo udevadm trigger`

### systemd user service (auto-start at boot)

```ini
# ~/.config/systemd/user/reachy-mini-daemon.service
[Unit]
Description=Reachy Mini Daemon
After=pipewire.service
Wants=pipewire.service

[Service]
Type=simple
WorkingDirectory=/home/pi/reachy_mini
Environment=GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/aarch64-linux-gnu/gstreamer-1.0
ExecStart=/home/pi/reachy_mini/.venv/bin/reachy-mini-daemon --standalone
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable reachy-mini-daemon
loginctl enable-linger $USER   # start service at boot without login
```

### Installing webrtcsink

The `webrtcsink` GStreamer element is required for WebRTC camera streaming. It is **not** available in Debian/Ubuntu package repos — you need to install it manually.

**Option A: Download the pre-built binary** (Debian Trixie / ARM64 only)

```bash
# Download from the GitHub release
curl -L -o libgstrswebrtc.so \
  https://github.com/emoods/reachy_mini/releases/download/standalone-v1.0/libgstrswebrtc.so

# Install it
sudo mkdir -p /opt/gst-plugins-rs/lib/aarch64-linux-gnu/gstreamer-1.0
sudo cp libgstrswebrtc.so /opt/gst-plugins-rs/lib/aarch64-linux-gnu/gstreamer-1.0/

# Also install the ICE agent (required for WebRTC connectivity)
sudo apt install gstreamer1.0-nice

# Verify
GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/aarch64-linux-gnu/gstreamer-1.0 \
  gst-inspect-1.0 webrtcsink
```

> The pre-built binary is compiled against GStreamer 1.26.x on Debian Trixie (13). If your Pi runs a different Debian version or GStreamer version, build from source instead.

**Option B: Build from source** (any Debian version or architecture)

See [Building webrtcsink from source](#building-webrtcsink-from-source) below.

### Building webrtcsink from source

A Dockerfile is provided at [`docker/Dockerfile.gst-webrtc`](docker/Dockerfile.gst-webrtc) for cross-compiling on an x86 machine using Docker + QEMU emulation. This is much faster than building natively on the Pi (~30 min on a modern PC vs hours on a Pi 4).

The Dockerfile has two build args you can override:

| Build arg | Default | What it controls |
|-----------|---------|------------------|
| `DEBIAN_VERSION` | `trixie` | Debian release — must match your Pi. Controls which GStreamer version the plugin links against. |
| `GST_PLUGINS_RS_VERSION` | `0.14.1` | Git tag from [gst-plugins-rs](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs/-/tags). Must be compatible with your GStreamer version. |

**Rough version compatibility:**

| Debian release | GStreamer version | gst-plugins-rs tag |
|----------------|-------------------|--------------------|
| Trixie (13) | 1.26.x | 0.14.x |
| Bookworm (12) | 1.22.x | 0.12.x or 0.11.x |
| Bullseye (11) | 1.18.x | 0.9.x or 0.8.x |

```bash
# Build for Debian Trixie (default):
docker buildx build --platform linux/arm64 \
  -f docker/Dockerfile.gst-webrtc \
  -t gst-webrtc-build . --load

# Or override for a different Debian version:
docker buildx build --platform linux/arm64 \
  --build-arg DEBIAN_VERSION=bookworm \
  --build-arg GST_PLUGINS_RS_VERSION=0.12.8 \
  -f docker/Dockerfile.gst-webrtc \
  -t gst-webrtc-build . --load

# Extract the .so:
docker create --name gst-extract gst-webrtc-build true
docker cp gst-extract:/output/libgstrswebrtc.so .
docker rm gst-extract

# Copy to your Pi and install:
scp libgstrswebrtc.so pi@<your-pi-ip>:/tmp/
ssh pi@<your-pi-ip> "sudo mkdir -p /opt/gst-plugins-rs/lib/aarch64-linux-gnu/gstreamer-1.0 \
  && sudo cp /tmp/libgstrswebrtc.so /opt/gst-plugins-rs/lib/aarch64-linux-gnu/gstreamer-1.0/"
```

> **Note:** Cross-compilation uses QEMU user-mode emulation. Docker Desktop on macOS/Windows includes this by default. On Linux, install `qemu-user-static` and run `docker run --privileged --rm tonistiigi/binfmt --install all`.

### Platform notes and known issues

| Board | HW H.264 | Notes |
|-------|----------|-------|
| **Raspberry Pi 4** | Yes (`v4l2h264enc` via VideoCore) | Tested. 1080p@30fps works. 60fps does NOT — the VideoCore encoder will fail with "Failed to process frame". |
| **Raspberry Pi 5** | Yes (`v4l2h264enc`) | Should work. Faster encoder may handle higher framerates. Not yet tested. |
| **Raspberry Pi Zero 2 W** | No | Falls back to software VP8 encoding. Expect higher latency and CPU usage. |
| **Other ARM64 SBCs** | Varies | If `gst-inspect-1.0 v4l2h264enc` finds the element, HW encoding will be used automatically. Otherwise falls back to software VP8. |

**Common issues:**

- **Audio card number shifts between reboots.** The Reachy Mini Audio USB device may appear as a different ALSA card number after reboot. The `--standalone` flag regenerates `~/.asoundrc` at every startup to handle this automatically.
- **Camera not detected on startup.** If another process (or a previous daemon instance) holds `/dev/video0`, the GStreamer device monitor may not find the camera. Ensure no other process is using the camera before starting the daemon.
- **`webrtcsink` not found.** The `gst-plugins-rs` package is not available from standard Debian/Ubuntu repos — you must build it from source. See the [build instructions](https://gitlab.freedesktop.org/gstreamer/gst-plugins-rs). Cross-compiling via Docker with `--platform linux/arm64` on an x86 host is significantly faster than building natively on the Pi.
- **`rtpgccbwe` warning.** A non-fatal warning about missing bandwidth estimation. The `gst-plugin-rtp` Rust plugin is not installed. Video streaming works fine without it — you just won't have WebRTC congestion control.
- **PipeWire required for camera detection.** The GStreamer device monitor needs PipeWire running to discover video devices. If running as a system service, the daemon won't have access to PipeWire. Use a **user-level** systemd service (as shown above) instead.

<br>

## ❓ Troubleshooting

Encountering an issue? 👉 **[Check the Troubleshooting & FAQ Guide](https://huggingface.co/docs/reachy_mini/troubleshooting)**

<br>

## 🤝 Community & Contributing

* **Join the Community:** Join [Discord](https://discord.gg/2bAhWfXme9) to share your moments with Reachy, build apps together, and get help.
* **Found a bug?** Open an issue on this repository.
* **Guidelines:** Review our [contributing guidelines](docs/contributing.md) to learn how to contribute code, report issues, or suggest features.


## License

This project is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.
Hardware design files are licensed under Creative Commons BY-SA-NC.
