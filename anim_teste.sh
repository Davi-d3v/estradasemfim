#!/bin/bash
cd "$(dirname "$0")"
timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" ../godot/godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x700 -s tools/teste_anims.gd -- "$@" 2>&1 | grep -E "salvo|SCRIPT ERROR|at: res" | head
