#!/usr/bin/env bash
echo "Iniciando servidor local de Taos Game Maker en http://localhost:8000/ ..."
python3 editor/serve.py || python editor/serve.py
