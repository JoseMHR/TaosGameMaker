# 09 — FAQ und Fehlerbehebung

## Allgemein & Editor

**Muss ich GDScript beherrschen, um diese Vorlage zu nutzen?**  
Nein. Mehr als 90 % der Spielentwicklung erfolgt im visuellen Web-Editor. GDScript ist nur nötig, wenn Sie gänzlich neue Kernmechaniken erfinden wollen.

**Benötigt der Web-Editor Node.js oder npm?**  
Nein. Er wird nativ über Python (`serve.py`) bereitgestellt und bindet Vue 3 über ein CDN ein.

**Ich habe Änderungen im Editor gespeichert, sehe sie aber nicht im Spiel.**  
Godot lädt die JSON-Dateien beim Start. Starten Sie das Spiel einfach neu (▶️) oder rufen Sie `Design.reload()` auf.

**Warum zeigen manche POIs kein ausgeschnittenes Charakterporträt in der Bildschirmmitte?**  
In dieser Vorlage sind Händler und Figuren bei vielen 16:9-Illustrationen (`assets/vn/bg/`) direkt in die Szene hineingemalt. Ist kein separates `npc_<id>.png`-Sprite zugewiesen, zeigt der Motor (`ViewPlace.gd`) den Hintergrund unverdeckt mit dem Emoji-Avatar an.

---

## Daten & Sprachen

**Wie funktioniert die Mehrsprachigkeit?**  
Textfelder besitzen 7 Sprachschlüssel (`de`, `en`, `es`, `fr`, `it`, `zh`, `ja`). Wenn Sie Ihr Spiel nur auf Deutsch veröffentlichen, können Sie nur diesen Schlüssel befüllen; das System schaltet bei fehlenden Texten automatisch auf den Fallback um.

**Wo werden die Spielstände gespeichert?**  
Im Benutzerordner (`user://save_slot_*.json`), verwaltet durch `SaveManager.gd`, unabhängig von den Designdaten in `data/`.
