# Shiko-like : robot IA de bureau (ESP32-S3)

Un petit robot avec des yeux animés sur écran, un micro et un haut-parleur, qui discute avec une IA.

```
[Voix détectée (ou bouton)] -> ESP32-S3 --WebSocket (PCM16 16 kHz)--> server.py
                                                  STT (ElevenLabs) -> Claude -> TTS (ElevenLabs)
ESP32-S3 <--WebSocket (PCM16 16 kHz + états)------ server.py
```

> Liste complète, tableaux et schémas de câblage : voir [docs/MATERIEL_ET_CABLAGE.md](docs/MATERIEL_ET_CABLAGE.md).
> Écoute continue : le robot détecte ta voix tout seul (seuil d'énergie). Règle `VAD_MIN_RMS` dans `config.h` avec les logs du moniteur série.

## Matériel (liste proposée, pas testée ici)
| Rôle | Composant |
|---|---|
| Carte | ESP32-S3 DevKitC-1 |
| Écran | ST7789 1,3" IPS 240x240 (7 broches : GND VCC SCL SDA RES DC BLK) |
| Micro | INMP441 (I2S) |
| Ampli + HP | MAX98357A + petit haut-parleur 4-8 Ω |
| Batterie (option) | LiPo 3,7 V + module de charge TP4056 / ou une carte avec charge intégrée |

## Câblage (modifiable dans `firmware/include/config.example.h` et `platformio.ini`)
- Écran : SCL→GPIO12, SDA→GPIO11, DC→GPIO9, RES→GPIO8, VCC→3V3, GND, BLK→3V3
- INMP441 : SCK→GPIO4, WS→GPIO5, SD→GPIO6, L/R→GND, VDD→3V3, GND
- MAX98357A : BCLK→GPIO15, LRC→GPIO16, DIN→GPIO17, VIN→5V, GND
- Bouton : le bouton BOOT (GPIO0) de la carte (parler de force, facultatif).

## Installation
1. **Serveur** (PC ou Raspberry sur le même Wi-Fi) :
   ```bash
   cd server
   pip install -r requirements.txt
   export ANTHROPIC_API_KEY=...
   export ELEVENLABS_API_KEY=...
   export ELEVENLABS_VOICE_ID=...   # une voix qui parle ton dialecte
   python server.py
   ```
2. **Firmware** (PlatformIO) :
   ```bash
   cd firmware
   cp include/config.example.h include/config.h   # puis édite Wi-Fi + IP du serveur
   pio run -t upload
   ```

## Limites et points à vérifier (honnêtement)
- **Rien de ceci n'a été compilé ni flashé** : je n'ai pas de PlatformIO ni de matériel dans mon environnement. Seule la syntaxe Python a été vérifiée. Attends-toi à corriger des détails (broches, versions de bibliothèques) au premier essai.
- Le code des endpoints ElevenLabs (STT `scribe_v1`, TTS en `pcm_16000`) est écrit de mémoire : à valider avec leur documentation actuelle.
- **Dialecte arabe** : la qualité de la reconnaissance et de la voix varie beaucoup selon le dialecte. À tester avec ta voix ; si c'est mauvais, on changera de moteur STT/TTS.
- L'écoute continue utilise une détection de voix simple par niveau sonore : elle peut réagir à un bruit fort (porte, musique) ou rater une voix basse. Le réglage de `VAD_MIN_RMS` est empirique. Le robot n'écoute pas pendant qu'il parle (pas d'interruption possible).
- Coûts : STT, TTS et Claude sont facturés à l'usage.
- Boîtier 3D et batterie : non inclus ici.
