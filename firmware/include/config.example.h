// Copie ce fichier en config.h et remplis-le. config.h est ignore par git.
#pragma once

#define WIFI_SSID "TON_WIFI"
#define WIFI_PASS "TON_MOT_DE_PASSE"

// IP locale du PC / Raspberry qui fait tourner server/server.py
#define SERVER_HOST "192.168.1.50"
#define SERVER_PORT 8765

// Broches (ESP32-S3)
#define PIN_MIC_BCLK 4   // INMP441 SCK
#define PIN_MIC_WS   5   // INMP441 WS
#define PIN_MIC_SD   6   // INMP441 SD
#define PIN_SPK_BCLK 15  // MAX98357A BCLK
#define PIN_SPK_LRC  16  // MAX98357A LRC
#define PIN_SPK_DIN  17  // MAX98357A DIN
#define PIN_BUTTON   0   // bouton BOOT de la carte : maintenir pour parler

// Seuil minimum de detection de voix (RMS PCM16). Regle-le avec les logs
// "rms=... seuil=..." du moniteur serie : mets-le un peu au-dessus du bruit de la piece.
#define VAD_MIN_RMS 400
