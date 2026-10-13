#!/bin/bash
cd "$(dirname "$0")"
timeout 200 ../godot/godot --headless --path . --import 2>&1 | grep -E "ERROR|at: GDScript|WARNING" | grep -v -E "audio|ALSA" | head -20
