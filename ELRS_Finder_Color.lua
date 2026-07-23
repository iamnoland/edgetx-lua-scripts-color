-- ELRS_Finder_Color.lua  (EdgeTX color radios: TX16S MKII/MKIII, TX15, etc.)
-- ELRS/CRSF RSSI-based lost model finder (Geiger style)
--
-- Based on ELRS_Finder.lua by Sunil Chahal (MIT License):
--   https://github.com/iamsunilchahal/edgetx-lua-scripts-bw
-- Color screen adaptation (c) 2026 Ray Noland / FPV Guidebook
-- Finder logic is identical to the original B/W version; only the
-- display layout was redesigned for color screens. MIT License.
--
-- Tested: Radiomaster TX15 (480x320), TX16S MKIII (800x480). EdgeTX 2.8+.

local lastBeep = 0
local avg = -120
local have = { rssi=false, snr=false, rql=false }

local function readSignal()
  -- Prefer 1RSS (CRSF dBm), else RSNR (dB), else RQly (%)
  local rssi = getValue("1RSS")  -- typically negative dBm, eg -95..-40
  if rssi and rssi ~= 0 then have.rssi=true; return rssi, "dBm" end
  local snr = getValue("RSNR")   -- -20..+20 dB typical
  if snr and snr ~= 0 then have.snr=true; return (snr*2-120), "SNR" end
  local rql = getValue("RQly")   -- 0..100 %
  if rql and rql ~= 0 then have.rql=true; return (rql-120), "LQ" end
  return -120, "NA"
end

local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end

-- ---------- display-only stuff below ----------

local W = LCD_W or 480
local H = LCD_H or 272

-- Colors (dark background, OSD-green accent)
local C_BG     = lcd.RGB(18, 22, 18)     -- near-black background
local C_HEADER = lcd.RGB(10, 60, 30)     -- dark green header bar
local C_TEXT   = lcd.RGB(240, 240, 240)  -- primary text
local C_DIM    = lcd.RGB(150, 160, 150)  -- secondary text
local C_GREEN  = lcd.RGB(0, 220, 90)
local C_YELLOW = lcd.RGB(240, 200, 40)
local C_RED    = lcd.RGB(230, 60, 50)
local C_FRAME  = lcd.RGB(90, 100, 90)

-- EdgeTX builds differ: some define CENTERED, others CENTER
local CTR = CENTERED or CENTER or 0

local function strengthColor(s)
  if s >= 66 then return C_GREEN
  elseif s >= 33 then return C_YELLOW
  else return C_RED end
end

local function run_func(event)
  local now = getTime() -- 10ms ticks
  local raw, kind = readSignal()
  -- Exponential moving average for stability
  avg = 0.8*avg + 0.2*(raw)

  -- Map avg (~-110..-40) to 0..100 "strength"
  local strength = clamp( (avg + 110) * (100/(70)), 0, 100 )  -- -110→0, -40→100

  -- Beep cadence: stronger => shorter interval
  local period = clamp( 120 - strength, 10, 120 )  -- ticks (10ms each): 120→1.2s, 10→0.1s
  if now - lastBeep >= period then
    local freq = 600 + (strength*6)                -- 600..1200 Hz
    playTone(freq, 30, 0, 0)
    lastBeep = now
  end

  -- ---------- UI ----------
  lcd.clear()
  lcd.drawFilledRectangle(0, 0, W, H, C_BG)

  -- Header bar
  local headH = math.floor(H * 0.15)          -- ~40px on 272
  lcd.drawFilledRectangle(0, 0, W, headH, C_HEADER)
  lcd.drawText(12, math.floor(headH/2) - 12, "ELRS FINDER", DBLSIZE + C_TEXT)
  lcd.drawText(W - 12, math.floor(headH/2) - 8, "Src: " .. kind, MIDSIZE + RIGHT + C_TEXT)

  -- Big strength percentage, centered
  local pctY = headH + math.floor(H * 0.06)
  lcd.drawText(W/2, pctY, string.format("%d%%", strength), XXLSIZE + CTR + strengthColor(strength))

  -- Large strength bar
  local barMargin = math.floor(W * 0.05)
  local barY = pctY + math.floor(H * 0.32)
  local barH = math.floor(H * 0.14)           -- ~38px on 272
  local barW = W - 2*barMargin
  lcd.drawRectangle(barMargin, barY, barW, barH, C_FRAME)
  lcd.drawRectangle(barMargin+1, barY+1, barW-2, barH-2, C_FRAME)  -- thicker frame
  local fill = math.floor((barW - 6) * strength / 100)
  if fill > 0 then
    lcd.drawFilledRectangle(barMargin+3, barY+3, fill, barH-6, strengthColor(strength))
  end

  -- Raw / Avg readouts
  local infoY = barY + barH + math.floor(H * 0.05)
  lcd.drawText(barMargin, infoY, string.format("Raw: %d", raw), MIDSIZE + C_TEXT)
  lcd.drawText(W - barMargin, infoY, string.format("Avg dBm est: %d", avg), MIDSIZE + RIGHT + C_TEXT)

  -- Tip line at the bottom
  lcd.drawText(W/2, H - 22, "Tip: Lower TX power as you get close.", CTR + C_DIM)

  return 0
end

return { run=run_func }
