@echo off
title Taos Game Maker - Studio Suite
echo Iniciando servidor local de Taos Game Maker en http://localhost:8000/ ...
python editor/serve.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] No se pudo iniciar Python. Asegurate de tener Python 3.8+ instalado y agregado al PATH.
    pause
)
