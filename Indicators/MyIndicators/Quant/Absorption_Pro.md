# Absorption Pro (Indicator)

## 1. Summary

**Absorption Pro** is a specialized Volume Price Analysis (VPA) tool designed to detect **Institutional Intervention** (Smart Money activity). It identifies specific candles where massive volume is traded but price movement is restricted ("Effort vs. Result" anomaly), signaling that a large player is absorbing the order flow.

The indicator visualizes these events not just as signals, but as **Active Supply/Demand Zones** that remain valid until the price breaks through them.

## 2. Methodology & Logic

The indicator combines volatility, volume, and candle structure to identify three specific market conditions:

### A. The Signal Logic

1. **High Effort:** Relative Volume (`RVOL`) > 2.0. (Volume is 200% of average).
2. **Low Result:** Candle Body < 0.35 * ATR. (Price failed to move proportionally to the volume).
3. **Direction:** Determined by the Close position within the High-Low range.
    * **Bullish Absorption:** Close in the upper 66% (Buying absorbed the selling pressure).
    * **Bearish Absorption:** Close in the lower 33% (Selling absorbed the buying pressure).

### B. The Climax Logic

* **Condition:** `RVOL > 3.5` AND `Body < 0.6 * ATR`.
* **Meaning:** Extreme volume exhaustion. Often marks the exact top or bottom of a trend.

## 3. Visualization

* **Arrows:** Marks the signal candle immediately.
  * 🟢 **Green Arrow:** Bullish Absorption (Potential Bottom).
  * 🔴 **Red Arrow:** Bearish Absorption (Potential Top).
* **Active Zones (Rectangles):** Draws a shaded box covering the High/Low of the signal candle.
  * **Dynamic Extension:** The box automatically extends to the right into the future.
  * **Breakout Detection:** The box stops extending (terminates) the moment a future candle closes *beyond* the zone limits. This keeps the chart clean and shows only valid, untested levels.

## 4. Parameters

* `InpATRPeriod`: Lookback for volatility normalization (Default: `14`).
* `InpRVOLPeriod`: Lookback for volume average (Default: `20`).
* `InpHistoryBars`: How far back to scan for signals (Default: `500`). Keep this reasonable to save performance.
* `InpShowObjects`: Toggle drawing of the Supply/Demand rectangles. (Buffers are always calculated).

## 5. Strategic Usage

1. **Reversal Entry:**
    If price approaches a support level and **Absorption Pro** prints a Green Arrow + Zone, it is a high-confidence reversal signal (Limit orders are active).
2. **Breakout Failure (Fakeout):**
    If price breaks out of a range but immediately prints an opposing Absorption signal, the breakout has likely failed (Trapped Traders).
3. **Target Selection:**
    The extended rectangles act as magnets. If you are in a trade, use the *next* active Absorption Zone as your Take Profit target.
