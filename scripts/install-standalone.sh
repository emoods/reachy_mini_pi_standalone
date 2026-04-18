#!/usr/bin/env bash
#
# install-standalone.sh — One-command setup for Reachy Mini Lite on a standalone Raspberry Pi
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/emoods/reachy_mini_pi_standalone/main/scripts/install-standalone.sh | bash
#
#   Or clone the repo first and run locally:
#   ./scripts/install-standalone.sh
#
# What this script does (in order):
#   1. Validates the environment (architecture, OS, Debian version, running as non-root)
#   2. Installs system packages via apt (build tools, GStreamer, GObject introspection)
#   3. Writes udev rules for Reachy Mini Lite USB devices (audio 38fb:1001, camera 38fb:1002)
#   4. Downloads and installs the pre-built webrtcsink GStreamer plugin (libgstrswebrtc.so)
#   5. Clones the reachy_mini repository (or uses existing clone)
#   6. Creates a Python virtual environment and installs dependencies via uv (or pip)
#   7. Creates a systemd user service for auto-start at boot
#   8. Verifies the installation
#
# Requirements:
#   - ARM64 (aarch64) Raspberry Pi running 64-bit Debian Trixie (13)
#   - Internet connection
#   - sudo access
#   - Reachy Mini Lite connected via USB
#
# The script is idempotent — safe to run multiple times. It will skip steps that are
# already completed and update components that have changed.
#
# Exit codes:
#   0 — success
#   1 — environment check failed (wrong arch, wrong OS, etc.)
#   2 — package installation failed
#   3 — webrtcsink download/install failed
#   4 — repository clone/install failed
#   5 — systemd service setup failed
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — override these with environment variables if needed
# ---------------------------------------------------------------------------

# Where to clone the reachy_mini repository
REACHY_DIR="${REACHY_DIR:-$HOME/reachy_mini}"

# GitHub repository to clone from
REACHY_REPO="${REACHY_REPO:-https://github.com/emoods/reachy_mini_pi_standalone.git}"

# Branch to checkout
REACHY_BRANCH="${REACHY_BRANCH:-main}"

# Where to install the webrtcsink GStreamer plugin
GST_PLUGIN_DIR="${GST_PLUGIN_DIR:-/opt/gst-plugins-rs/lib/aarch64-linux-gnu/gstreamer-1.0}"

# URL for the pre-built webrtcsink binary
WEBRTCSINK_URL="${WEBRTCSINK_URL:-https://github.com/emoods/reachy_mini_pi_standalone/releases/download/standalone-v1.0/libgstrswebrtc.so}"

# systemd service name
SERVICE_NAME="reachy-mini-daemon"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log()   { echo -e "${GREEN}[OK]${NC}    $*"; }
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit "${2:-1}"; }

step_header() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Step $1: $2${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ---------------------------------------------------------------------------
# Step 1: Environment validation
# ---------------------------------------------------------------------------
step_header "1/7" "Validating environment"

# Must not be root (systemd user services don't work as root)
if [ "$(id -u)" -eq 0 ]; then
    fail "Do not run this script as root. Run as your normal user (sudo will be used where needed)." 1
fi

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    fail "This script requires ARM64 (aarch64). Detected: $ARCH" 1
fi
log "Architecture: $ARCH"

# Check OS
if [ ! -f /etc/os-release ]; then
    fail "Cannot detect OS — /etc/os-release not found." 1
fi
# shellcheck source=/dev/null
. /etc/os-release
if [ "${ID:-}" != "debian" ] && [ "${ID:-}" != "raspbian" ]; then
    warn "Expected Debian or Raspbian, detected: ${ID:-unknown}. Proceeding anyway."
fi
log "OS: ${PRETTY_NAME:-$ID $VERSION_ID}"

# Check Debian version (Trixie = 13). Warn but don't fail for other versions.
if [ "${VERSION_ID:-}" != "13" ]; then
    warn "Expected Debian 13 (Trixie). Detected: ${VERSION_CODENAME:-$VERSION_ID}."
    warn "The pre-built webrtcsink binary may not work. You may need to build from source."
    warn "See: https://github.com/emoods/reachy_mini_pi_standalone#building-webrtcsink-from-source"
    if [ -t 0 ]; then
        # Interactive terminal — ask the user
        echo ""
        read -r -p "Continue anyway? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY]) info "Continuing..." ;;
            *) fail "Aborted by user." 1 ;;
        esac
    else
        # Non-interactive (piped or SSH without TTY) — continue with warning
        warn "Non-interactive mode — continuing despite version mismatch."
    fi
fi
log "Debian version: ${VERSION_CODENAME:-$VERSION_ID} ($VERSION_ID)"

# Check sudo access (use -n for non-interactive/SSH, fall back to group check)
if sudo -n true 2>/dev/null; then
    log "sudo access: OK (passwordless)"
elif groups | grep -qw sudo; then
    log "sudo access: OK (in sudo group)"
else
    fail "sudo access required. Make sure your user is in the sudo group." 1
fi

# ---------------------------------------------------------------------------
# Step 2: Install system packages
# ---------------------------------------------------------------------------
step_header "2/7" "Installing system packages"

PACKAGES=(
    # Build tools and runtime libraries
    git git-lfs pkg-config cmake
    libcairo2-dev libgl1 libportaudio2

    # GObject introspection (GStreamer Python bindings)
    libgirepository1.0-dev gir1.2-glib-2.0 libglib2.0-dev

    # GStreamer runtime + plugins + introspection typelibs
    gstreamer1.0-tools
    gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good
    gstreamer1.0-plugins-bad
    gstreamer1.0-alsa
    gstreamer1.0-pipewire
    gstreamer1.0-nice
    gir1.2-gstreamer-1.0
    gir1.2-gst-plugins-base-1.0
)

info "Updating package lists..."
sudo apt-get update -qq || fail "apt-get update failed. Check your internet connection." 2

info "Installing ${#PACKAGES[@]} packages (this may take a minute)..."
sudo apt-get install -y --no-install-recommends "${PACKAGES[@]}" \
    || fail "apt-get install failed." 2

log "System packages installed"

# ---------------------------------------------------------------------------
# Step 3: udev rules for Reachy Mini Lite USB devices
# ---------------------------------------------------------------------------
step_header "3/7" "Configuring udev rules"

UDEV_RULES_FILE="/etc/udev/rules.d/99-reachy-mini-lite.rules"
UDEV_RULES_CONTENT='# Reachy Mini Lite USB devices — grant access to all users
# Audio/DOA (XVF3800 with Pollen firmware)
SUBSYSTEM=="usb", ATTR{idVendor}=="38fb", ATTR{idProduct}=="1001", MODE="0666"
# Camera
SUBSYSTEM=="usb", ATTR{idVendor}=="38fb", ATTR{idProduct}=="1002", MODE="0666"'

if [ -f "$UDEV_RULES_FILE" ]; then
    EXISTING=$(cat "$UDEV_RULES_FILE")
    if [ "$EXISTING" = "$UDEV_RULES_CONTENT" ]; then
        log "udev rules already installed (unchanged)"
    else
        warn "udev rules file exists but differs — updating"
        echo "$UDEV_RULES_CONTENT" | sudo tee "$UDEV_RULES_FILE" > /dev/null
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        log "udev rules updated and reloaded"
    fi
else
    echo "$UDEV_RULES_CONTENT" | sudo tee "$UDEV_RULES_FILE" > /dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    log "udev rules installed and reloaded"
fi

# ---------------------------------------------------------------------------
# Step 4: Install webrtcsink (pre-built binary)
# ---------------------------------------------------------------------------
step_header "4/7" "Installing webrtcsink GStreamer plugin"

WEBRTCSINK_PATH="$GST_PLUGIN_DIR/libgstrswebrtc.so"

if [ -f "$WEBRTCSINK_PATH" ]; then
    # Verify it actually loads
    if GST_PLUGIN_PATH="$GST_PLUGIN_DIR" gst-inspect-1.0 webrtcsink &>/dev/null; then
        log "webrtcsink already installed and working"
    else
        warn "libgstrswebrtc.so exists but doesn't load — re-downloading"
        rm -f "$WEBRTCSINK_PATH"
    fi
fi

if [ ! -f "$WEBRTCSINK_PATH" ]; then
    info "Downloading pre-built webrtcsink (~163MB)..."
    sudo mkdir -p "$GST_PLUGIN_DIR"

    TMP_SO=$(mktemp /tmp/libgstrswebrtc.XXXXXX.so)
    if ! curl -fSL --progress-bar -o "$TMP_SO" "$WEBRTCSINK_URL"; then
        rm -f "$TMP_SO"
        fail "Failed to download webrtcsink from $WEBRTCSINK_URL" 3
    fi

    # Basic sanity check — should be an ELF shared library
    if ! file "$TMP_SO" | grep -q "ELF.*shared object.*aarch64"; then
        rm -f "$TMP_SO"
        fail "Downloaded file is not a valid ARM64 shared library." 3
    fi

    sudo cp "$TMP_SO" "$WEBRTCSINK_PATH"
    sudo chmod 644 "$WEBRTCSINK_PATH"
    rm -f "$TMP_SO"

    # Verify it loads
    if ! GST_PLUGIN_PATH="$GST_PLUGIN_DIR" gst-inspect-1.0 webrtcsink &>/dev/null; then
        fail "webrtcsink installed but GStreamer cannot load it. Version mismatch?" 3
    fi

    log "webrtcsink installed and verified"
fi

# ---------------------------------------------------------------------------
# Step 5: Clone repository and install Python dependencies
# ---------------------------------------------------------------------------
step_header "5/7" "Setting up reachy_mini"

if [ -d "$REACHY_DIR/.git" ]; then
    info "Repository already exists at $REACHY_DIR"
    info "Pulling latest changes from $REACHY_BRANCH..."
    cd "$REACHY_DIR"
    git fetch origin
    git checkout "$REACHY_BRANCH"
    git pull origin "$REACHY_BRANCH" || warn "git pull failed — continuing with existing code"
    log "Repository updated"
else
    info "Cloning $REACHY_REPO into $REACHY_DIR..."
    git clone --branch "$REACHY_BRANCH" "$REACHY_REPO" "$REACHY_DIR" \
        || fail "git clone failed. Check the URL and your internet connection." 4
    cd "$REACHY_DIR"
    log "Repository cloned"
fi

# Install uv if not present
if ! command -v uv &>/dev/null; then
    info "Installing uv (fast Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v uv &>/dev/null; then
        fail "uv installed but not found in PATH. Try: export PATH=\$HOME/.local/bin:\$PATH" 4
    fi
    log "uv installed"
else
    log "uv already available: $(uv --version)"
fi

# Create venv and install
info "Installing Python dependencies (this may take a few minutes on first run)..."
cd "$REACHY_DIR"
uv sync || fail "uv sync failed. Check pyproject.toml for details." 4

# Verify the daemon entry point exists
DAEMON_BIN="$REACHY_DIR/.venv/bin/reachy-mini-daemon"
if [ ! -x "$DAEMON_BIN" ]; then
    fail "reachy-mini-daemon not found at $DAEMON_BIN after install." 4
fi
log "Python environment ready — $(uv run python --version)"

# ---------------------------------------------------------------------------
# Step 6: systemd user service
# ---------------------------------------------------------------------------
step_header "6/7" "Configuring systemd user service"

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/$SERVICE_NAME.service"

mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_FILE" << EOF
# Reachy Mini Daemon — standalone mode
# Installed by install-standalone.sh
# Manage with: systemctl --user {start,stop,restart,status,logs} $SERVICE_NAME

[Unit]
Description=Reachy Mini Daemon (standalone)
After=pipewire.service
Wants=pipewire.service

[Service]
Type=simple
WorkingDirectory=$REACHY_DIR
Environment=GST_PLUGIN_PATH=$GST_PLUGIN_DIR
ExecStart=$DAEMON_BIN --standalone
Restart=on-failure
RestartSec=5

# Logging — stdout and stderr go to journald by default.
# View with: journalctl --user -u $SERVICE_NAME -f

[Install]
WantedBy=default.target
EOF

# Reload systemd, enable the service, enable lingering
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME" 2>/dev/null

# Enable linger so user services start at boot without login
if ! loginctl show-user "$USER" --property=Linger 2>/dev/null | grep -q "yes"; then
    sudo loginctl enable-linger "$USER"
    log "Login lingering enabled (service starts at boot)"
fi

log "systemd user service installed at $SERVICE_FILE"

# ---------------------------------------------------------------------------
# Step 7: Verification
# ---------------------------------------------------------------------------
step_header "7/7" "Verifying installation"

ERRORS=0

# Check webrtcsink
if GST_PLUGIN_PATH="$GST_PLUGIN_DIR" gst-inspect-1.0 webrtcsink &>/dev/null; then
    log "GStreamer webrtcsink: loaded"
else
    warn "GStreamer webrtcsink: NOT loaded"
    ERRORS=$((ERRORS + 1))
fi

# Check daemon binary
if [ -x "$DAEMON_BIN" ]; then
    log "Daemon binary: $DAEMON_BIN"
else
    warn "Daemon binary: NOT found"
    ERRORS=$((ERRORS + 1))
fi

# Check udev rules
if [ -f "$UDEV_RULES_FILE" ]; then
    log "udev rules: installed"
else
    warn "udev rules: NOT found"
    ERRORS=$((ERRORS + 1))
fi

# Check systemd service
if systemctl --user is-enabled "$SERVICE_NAME" &>/dev/null; then
    log "systemd service: enabled"
else
    warn "systemd service: NOT enabled"
    ERRORS=$((ERRORS + 1))
fi

# Check if Reachy Mini Lite USB devices are connected
if lsusb 2>/dev/null | grep -q "38fb:1001"; then
    log "Reachy Mini Audio (38fb:1001): connected"
else
    warn "Reachy Mini Audio (38fb:1001): NOT detected — is the Lite plugged in?"
fi
if lsusb 2>/dev/null | grep -q "38fb:1002"; then
    log "Reachy Mini Camera (38fb:1002): connected"
else
    warn "Reachy Mini Camera (38fb:1002): NOT detected — is the Lite plugged in?"
fi

# Summary
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
else
    echo -e "${YELLOW}${BOLD}  Installation complete with $ERRORS warning(s).${NC}"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Start the daemon now:"
echo "    systemctl --user start $SERVICE_NAME"
echo ""
echo "  View logs:"
echo "    journalctl --user -u $SERVICE_NAME -f"
echo ""
echo "  Check status:"
echo "    systemctl --user status $SERVICE_NAME"
echo ""
echo "  The daemon will auto-start on boot. To disable:"
echo "    systemctl --user disable $SERVICE_NAME"
echo ""
echo "  Dashboard: open the Reachy Mini desktop app and connect to this Pi's IP."
echo ""
