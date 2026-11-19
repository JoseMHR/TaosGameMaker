# 05 — Spielmechaniken (Die 4 Säulen)

---

## 1. 🗺️ 3D-Top-Down-Oberwelt
- Kachelbasierte Navigation mit Kriegsnebel und dynamischen Wettereffekten.
- **Ressourcensammeln**: Passende Werkzeuge für jeden Knotentyp (Axt für Holz, Spitzhacke für Erz, Angel, Schaufel für Schätze).
- **Lager**: Zelt zum Ausruhen und Vorspulen der Zeit; Lagerfeuer zum Kochen von Buff-Mahlzeiten.
- **Dynamische Transformationen**: Kacheländerungen in Echtzeit bei Story-Fortschritt (`world_transforms.json`).

---

## 2. 🏰 Ego-Dungeons
- Schrittweise Erkundung im 3D-Gitter mit Minikarte und 2D-Billboard-Monstern.
- **6 Erkundungsfähigkeiten**: Kinetikwelle (Schalter & Kisten), Psychogreifer (Ringe), Jägersicht (Geheimgänge), Elementaraffinität (Fackeln & Eis), Reinigung (Giftnebel), Zeitschleife (bewegliche Plattformen).

---

## 3. ⚔️ Taktischer Rundenkampf
- Klassische JRPG-Seitenansicht: Gruppe links, Gegner rechts.
- **ATB-Leiste & Aktionspunkte (AP)**: Reiht mehrere Zauber und Attacken in einer Runde aneinander.
- **Synergien**: Bestimmte aufeinanderfolgende Fähigkeiten verschmelzen zu verheerenden Kombos.
- **Aktive QTE-Verteidigung**: Timing-Kreis zur Schadensreduktion oder für eine Perfekte Abwehr.

---

## 4. 📖 Narrativ & Visual Novel
- Panorama-Hintergründe in 16:9 (`assets/vn/bg/`) mit Charakterporträts.
- **5 Persönlichkeitsfacetten** (`Mut`, `Güte`, `Charme`, `Intelligenz`, `Besonnenheit`), die exklusive Dialoge freischalten.
- 7-Sprachen-Dialogbäume in `data/npcs/<id>.json`.
