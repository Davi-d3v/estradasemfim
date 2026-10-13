#!/bin/bash
# Gera um .zip com o projeto inteiro (sem cache do Godot e sem prints) em /mnt/user-data/outputs
cd "$(dirname "$0")/.."
d=$(TZ=America/Sao_Paulo date +%Y-%m-%d_%Hh%M)
mkdir -p /mnt/user-data/outputs
out=/mnt/user-data/outputs/EstradaSemFim_backup_$d.zip
zip -q -r "$out" trailer_game -x "trailer_game/.godot/*" "trailer_game/prints/*" "trailer_game/.git/*"
echo "$out"
