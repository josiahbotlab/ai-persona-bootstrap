#!/usr/bin/env bash
# RunPod bootstrap script — runs on pod startup
# Installs ComfyUI, downloads models, starts server
set -euo pipefail

# Detect if we're on a barebones image and install deps
if ! command -v curl >/dev/null 2>&1 || \
   ! command -v git >/dev/null 2>&1 || \
   ! command -v python3 >/dev/null 2>&1; then
  echo "=== Installing system deps (vanilla image detected) ==="
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    curl wget git python3 python3-pip python3-venv \
    ca-certificates build-essential
fi

WORKSPACE="/workspace"
COMFYUI_DIR="$WORKSPACE/ComfyUI"
MODELS_DIR="$COMFYUI_DIR/models"

echo "=== RunPod Bootstrap ==="

# Pre-flight: verify HF token can access gated Flux Dev model
if [ -z "${HF_TOKEN:-}" ]; then
    echo "WARNING: HF_TOKEN not set — gated model downloads will fail"
fi
if ! curl -sf -H "Authorization: Bearer ${HF_TOKEN:-}" \
    "https://huggingface.co/api/models/black-forest-labs/FLUX.1-dev" \
    > /dev/null 2>&1; then
    echo "ERROR: HF token cannot access FLUX.1-dev (gated model)"
    echo ""
    echo "Fix: visit https://huggingface.co/black-forest-labs/FLUX.1-dev"
    echo "     and click 'Agree and access repository', then verify your"
    echo "     HF_TOKEN has 'read' scope."
    exit 1
fi
echo "HF token verified — Flux Dev access OK"

# Install ComfyUI if not present (persisted on volume)
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "Installing ComfyUI..."
    cd "$WORKSPACE"
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd "$COMFYUI_DIR"
    pip install -r requirements.txt
else
    echo "ComfyUI already installed, updating..."
    cd "$COMFYUI_DIR"
    git pull || true
    pip install -r requirements.txt --quiet
fi

# Download Flux Dev models if not cached
UNET_PATH="$MODELS_DIR/unet/flux1-dev.safetensors"
VAE_PATH="$MODELS_DIR/vae/ae.safetensors"
CLIP_L_PATH="$MODELS_DIR/clip/clip_l.safetensors"
CLIP_T5_PATH="$MODELS_DIR/clip/t5xxl_fp16.safetensors"

mkdir -p "$MODELS_DIR"/{unet,vae,clip,ipadapter,loras,checkpoints}

if [ ! -f "$UNET_PATH" ]; then
    echo "Downloading Flux Dev UNET..."
    wget -q --show-progress -O "$UNET_PATH" \
        "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
        --header="Authorization: Bearer ${HF_TOKEN:-}"
fi

if [ ! -f "$VAE_PATH" ]; then
    echo "Downloading Flux VAE..."
    wget -q --show-progress -O "$VAE_PATH" \
        "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
        --header="Authorization: Bearer ${HF_TOKEN:-}"
fi

if [ ! -f "$CLIP_L_PATH" ]; then
    echo "Downloading CLIP-L..."
    wget -q --show-progress -O "$CLIP_L_PATH" \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
fi

if [ ! -f "$CLIP_T5_PATH" ]; then
    echo "Downloading T5-XXL..."
    wget -q --show-progress -O "$CLIP_T5_PATH" \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
fi

# Symlink UNET as checkpoint for workflows that use CheckpointLoaderSimple
ln -sf "$UNET_PATH" "$MODELS_DIR/checkpoints/flux1-dev.safetensors"

echo "All models ready."

# Start ComfyUI
echo "Starting ComfyUI on 0.0.0.0:8188..."
cd "$COMFYUI_DIR"
exec python main.py --listen 0.0.0.0 --port 8188
