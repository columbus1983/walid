// Robot IA de bureau - ESP32-S3
// Micro I2S (INMP441) + ampli I2S (MAX98357A) + ecran ST7789 240x240.
// Maintenir le bouton = parler. L'audio part en WebSocket vers server.py,
// la reponse vocale revient en PCM16 16 kHz.
#include <Arduino.h>
#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>
#include <TFT_eSPI.h>
#include <driver/i2s.h>
#include "config.h"

#define SAMPLE_RATE 16000
#define MIC_PORT I2S_NUM_0
#define SPK_PORT I2S_NUM_1
#define MIC_FRAMES 512  // echantillons lus par iteration

enum State { IDLE, LISTENING, THINKING, SPEAKING };
volatile State state = IDLE;

WebSocketsClient ws;
TFT_eSPI tft;
TFT_eSprite eyes(&tft);  // bande 240x140 pour les yeux (evite le scintillement)

bool wsConnected = false;
bool recording = false;

static const uint16_t COL_EYE = 0xBEDF;  // bleu clair

// ---------- Audio ----------
void audioInit() {
  i2s_config_t mic = {};
  mic.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX);
  mic.sample_rate = SAMPLE_RATE;
  mic.bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT;  // INMP441 : 24 bits dans un slot 32
  mic.channel_format = I2S_CHANNEL_FMT_ONLY_LEFT;   // pin L/R de l'INMP441 a GND
  mic.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  mic.intr_alloc_flags = ESP_INTR_FLAG_LEVEL1;
  mic.dma_buf_count = 6;
  mic.dma_buf_len = 256;
  i2s_pin_config_t micPins = {I2S_PIN_NO_CHANGE, PIN_MIC_BCLK, PIN_MIC_WS,
                              I2S_PIN_NO_CHANGE, PIN_MIC_SD};
  i2s_driver_install(MIC_PORT, &mic, 0, NULL);
  i2s_set_pin(MIC_PORT, &micPins);

  i2s_config_t spk = {};
  spk.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX);
  spk.sample_rate = SAMPLE_RATE;
  spk.bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT;
  spk.channel_format = I2S_CHANNEL_FMT_ONLY_LEFT;
  spk.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  spk.intr_alloc_flags = ESP_INTR_FLAG_LEVEL1;
  spk.dma_buf_count = 8;
  spk.dma_buf_len = 512;
  spk.tx_desc_auto_clear = true;
  i2s_pin_config_t spkPins = {I2S_PIN_NO_CHANGE, PIN_SPK_BCLK, PIN_SPK_LRC,
                              PIN_SPK_DIN, I2S_PIN_NO_CHANGE};
  i2s_driver_install(SPK_PORT, &spk, 0, NULL);
  i2s_set_pin(SPK_PORT, &spkPins);
}

// Lit un bloc du micro en PCM16 ; renvoie le nombre d'echantillons et le niveau RMS.
int readMic(int16_t *pcm, float &rms) {
  static int32_t raw[MIC_FRAMES];
  size_t got = 0;
  i2s_read(MIC_PORT, raw, sizeof(raw), &got, 40 / portTICK_PERIOD_MS);
  int n = got / 4;
  double sum = 0;
  for (int i = 0; i < n; i++) {
    pcm[i] = (int16_t)(raw[i] >> 14);  // 24 bits -> 16 bits (+gain)
    sum += (double)pcm[i] * pcm[i];
  }
  rms = n ? sqrt(sum / n) : 0;
  return n;
}

void playChunk(const uint8_t *data, size_t len) {
  size_t written = 0;
  i2s_write(SPK_PORT, data, len, &written, portMAX_DELAY);
}

// ---------- Yeux ----------
void drawEyes() {
  static uint32_t lastBlink = 0, blinkUntil = 0;
  uint32_t now = millis();
  if (state == IDLE && now - lastBlink > 3500 + (esp_random() % 2500)) {
    lastBlink = now;
    blinkUntil = now + 140;
  }
  bool blink = now < blinkUntil;

  int w = 56, h = 84, dx = 0, dy = 0;
  switch (state) {
    case LISTENING: w = 62; h = 96; break;                      // grands yeux attentifs
    case THINKING:  w = 50; h = 70; dx = 12; dy = -14; break;   // regarde en haut a droite
    case SPEAKING:  h = 84 + (int)(10 * sin(now / 90.0)); break; // yeux qui "parlent"
    default: break;
  }
  if (blink) h = 8;

  eyes.fillSprite(TFT_BLACK);
  int cy = 70 + dy;
  eyes.fillEllipse(75 + dx, cy, w / 2, h / 2, COL_EYE);
  eyes.fillEllipse(165 + dx, cy, w / 2, h / 2, COL_EYE);
  if (state == THINKING) {
    eyes.setTextColor(TFT_WHITE);
    eyes.drawString("?", 205, 8, 4);
  }
  if (!wsConnected) {
    eyes.setTextColor(TFT_RED);
    eyes.drawString("offline", 8, 8, 2);
  }
  eyes.pushSprite(0, 50);
}

// ---------- WebSocket ----------
void onWsEvent(WStype_t type, uint8_t *payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED: wsConnected = true; break;
    case WStype_DISCONNECTED: wsConnected = false; break;
    case WStype_TEXT: {
      JsonDocument doc;
      if (deserializeJson(doc, payload, length)) break;
      String s = doc["state"] | "";
      if (s == "thinking") state = THINKING;
      else if (s == "speaking") state = SPEAKING;
      else if (s == "idle") state = IDLE;
      break;
    }
    case WStype_BIN:
      playChunk(payload, length & ~1);
      break;
    default: break;
  }
}

// ---------- Setup / loop ----------
void setup() {
  Serial.begin(115200);
  pinMode(PIN_BUTTON, INPUT_PULLUP);

  tft.init();
  tft.setRotation(0);
  tft.fillScreen(TFT_BLACK);
  eyes.setColorDepth(16);
  eyes.createSprite(240, 140);

  audioInit();

  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print('.');
  }
  Serial.println(WiFi.localIP());

  ws.begin(SERVER_HOST, SERVER_PORT, "/");
  ws.onEvent(onWsEvent);
  ws.setReconnectInterval(2000);
}

// Ecoute continue : detection de voix par energie (RMS) + bruit ambiant adaptatif.
#define PREROLL_CHUNKS 10      // ~320 ms gardes avant le debut de la voix
#define END_SILENCE_MS 900     // silence qui termine la phrase
#define MAX_RECORD_MS 15000
#define IGNORE_AFTER_REPLY_MS 700  // evite d'ecouter l'echo de sa propre voix

void listenLoop() {
  static int16_t preroll[PREROLL_CHUNKS][MIC_FRAMES];
  static int prHead = 0, prCount = 0, loudRun = 0;
  static float noise = 300;
  static uint32_t lastVoice = 0, recStart = 0, ignoreUntil = 0, lastLog = 0;
  static State prevState = IDLE;
  static int16_t buf[MIC_FRAMES];

  uint32_t now = millis();
  bool pressed = digitalRead(PIN_BUTTON) == LOW;

  // Retour a IDLE apres une reponse : on vide le micro et on attend un peu.
  if (prevState != IDLE && state == IDLE) {
    i2s_zero_dma_buffer(MIC_PORT);
    ignoreUntil = now + IGNORE_AFTER_REPLY_MS;
    loudRun = 0;
    prCount = 0;
  }
  prevState = state;

  if (!wsConnected || (state != IDLE && !recording) || now < ignoreUntil) return;

  float rms;
  int n = readMic(buf, rms);
  if (n == 0) return;
  float thr = max((float)VAD_MIN_RMS, noise * 3.0f);

  if (!recording) {
    memcpy(preroll[prHead], buf, n * 2);
    prHead = (prHead + 1) % PREROLL_CHUNKS;
    if (prCount < PREROLL_CHUNKS) prCount++;
    if (rms < thr) noise = 0.98f * noise + 0.02f * rms;
    loudRun = rms > thr ? loudRun + 1 : 0;
    if (now - lastLog > 500) {  // pour regler VAD_MIN_RMS
      lastLog = now;
      Serial.printf("rms=%.0f seuil=%.0f\n", rms, thr);
    }
    if (loudRun >= 3 || pressed) {
      recording = true;
      state = LISTENING;
      recStart = lastVoice = now;
      ws.sendTXT("start");
      int first = (prHead - prCount + PREROLL_CHUNKS) % PREROLL_CHUNKS;
      for (int k = 0; k < prCount; k++)
        ws.sendBIN((uint8_t *)preroll[(first + k) % PREROLL_CHUNKS], MIC_FRAMES * 2);
      prCount = 0;
    }
  } else {
    ws.sendBIN((uint8_t *)buf, n * 2);
    if (rms > thr || pressed) lastVoice = now;
    if (now - lastVoice > END_SILENCE_MS || now - recStart > MAX_RECORD_MS) {
      recording = false;
      ws.sendTXT("end");
      state = THINKING;
    }
  }
}

void loop() {
  ws.loop();
  listenLoop();

  static uint32_t lastFrame = 0;
  if (millis() - lastFrame > 40) {  // ~25 images/s
    lastFrame = millis();
    drawEyes();
  }
}
