# ai-persona-bootstrap

RunPod bootstrap script for the AI Persona System. Installs ComfyUI and downloads Flux Dev models on first boot.

This is a public mirror of the bootstrap script from the private `ai-persona-system` repo. It's kept separate so RunPod templates can `curl` it without authentication.

## Usage

Set as the RunPod template startup command:

```
bash -c "curl -fsSL https://raw.githubusercontent.com/josiahbotlab/ai-persona-bootstrap/main/runpod_bootstrap.sh | bash"
```

## What it does

1. Installs/updates ComfyUI to `/workspace/ComfyUI`
2. Downloads Flux Dev models (~20GB on first boot):
   - Flux Dev UNET (~12GB)
   - T5-XXL FP16 (~5GB)
   - CLIP-L (~250MB)
   - Flux VAE (~300MB)
3. Starts ComfyUI on `0.0.0.0:8188`

Models are cached on the RunPod persistent volume — subsequent boots skip downloads.
