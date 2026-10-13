#!/bin/bash
# Gera os prints da cena (renderizador de compatibilidade, sem GPU)
cd "$(dirname "$0")"
timeout 600 xvfb-run -a -s "-screen 0 1920x1080x24" ../godot/godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 -- --capturar "$@" 2>&1 | grep -v -E "ALSA|audio|snd_pcm|status < 0|^$"
