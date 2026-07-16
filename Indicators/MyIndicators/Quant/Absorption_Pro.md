# Institutional Absorption Pro Detector (VSA-Optimized)

## 1. Summary (Introduction)

The **Institutional Absorption Pro Detector** is an advanced market-microstructure trading tool designed to identify where large institutional orders are absorbing directional price flow.

In financial markets, institutions cannot execute massive block orders all at once without causing severe price slippage. Instead, they use passive limit orders to "absorb" incoming market orders. This behavior is invisible on standard charts but leaves a distinct footprint in the relationship between volume and price spread.

Based on the core principles of **Volume Spread Analysis (VSA)** pioneered by Richard Wyckoff, the indicator tracks the concept of **Effort vs. Result**. When high volume (Effort) is injected into the market, but the resulting candle body is extremely small (Lack of Result), it indicates that passive institutional limit orders are absorbing all active market orders.

The indicator dynamically maps these absorption areas as Supply, Demand, or Climax zones directly on the chart, using soft, semi-transparent watermark colors. These zones are automatically extended in real-time until future price action breaks their boundaries.

---

## 2. Mathematical & Quant Foundations

The indicator utilizes two high-performance mathematical engines to evaluate volume effort and volatility spread:

### A. Volatility Baseline via ATR (Average True Range)

To calculate whether a candle body is statistically "small," the indicator normalizes current price spread against market volatility using Wilder's smoothed Average True Range (ATR):

$$\text{TR}_t = \max \big( (H_t - L_t), |H_t - C_{t-1}|, |L_t - C_{t-1}| \big)$$

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \times (N - 1) + \text{TR}_t}{N}$$

Where $N$ represents the ATR period (typically `14`).

### B. Relative Volume (RVOL) - The Effort Metric

Relative Volume measures current trading volume against the average volume of the preceding $M$ bars (excluding the active bar), identifying institutional participation:

$$\text{RVOL}_t = \frac{V_t}{\frac{1}{M}\sum_{j=1}^{M} V_{t-j}}$$

Where $V$ is the tick volume (or exchange volume) and $M$ is the RVOL lookback period (typically `20`).

### C. VSA Absorption & Climax Logic

On each bar $t$, the indicator evaluates the interaction between Effort (RVOL) and Result (Spread / Candle Body):

1. **High Effort:** $\text{RVOL}_t > 2.0$ (Volume is more than double the rolling average).
2. **Low Result:** $\text{Spread}_t < 0.35 \times \text{ATR}_t$ (Candle body is tight, indicating heavy resistance).
3. **Close Position ($CP$):** Measures where the candle closed relative to its high-low range:
   $$CP_t = \frac{C_t - L_t}{H_t - L_t}$$

* **Bullish Demand Absorption (Buyers absorbing Sellers):**
  Meets High Effort and Low Result conditions, and closes in the top third:
  $$CP_t > 0.66 \implies \text{BufState}_t = 1.0 \quad (\text{color: } \textbf{clrLightSteelBlue})$$

* **Bearish Supply Absorption (Sellers absorbing Buyers):**
  Meets High Effort and Low Result conditions, and closes in the bottom third:
  $$CP_t < 0.33 \implies \text{BufState}_t = -1.0 \quad (\text{color: } \textbf{clrMistyRose})$$

* **Volume Climax / Exhaustion Peak:**
  Triggered when absolute volume is extremely high, representing a massive exhaustion climax:
  $$\text{RVOL}_t > 3.5 \quad \text{AND} \quad \text{Spread}_t < 0.60 \times \text{ATR}_t \implies \text{BufState}_t = 2.0 \quad (\text{color: } \textbf{clrWheat})$$

---

## 3. Recommended Parameter Calibration

The sensitivity of the absorption zones can be customized depending on the asset class and timeframe:

| Market Regime | Asset Class | ATR / RVOL Periods | History Bars Limit | Quantitative Objective |
| :--- | :--- | :---: | :---: | :--- |
| **Intraday Scalping** | Majors FX / Indices | `14` / `20` | `200` to `500` | Captures quick institutional blocks on M5/M15 charts. Limits lag during heavy session opens. |
| **Swing Trading** | FX / Commodities | `14` / `24` | `500` to `1000` | Tracks structural liquidity pools on H1/H4 charts. Identifies major reversal pivots. |
| **Crypto Volatility** | BTC / ETH | `20` / `30` | `300` | Normalizes extreme exchange-driven volume spikes on highly volatile assets. |

---

## 4. Visual & Technical Highlights

* **Subtle Multi-Template Watermark Colors:**
  To prevent visual clutter on light or dark background templates, the indicator replaces harsh, neon retail colors with soft, pastel MQL5 constants that act as native translucent background overlays:
  * **Demand Zone (Bullish):** `clrLightSteelBlue` (Soft Slate-Blue)
  * **Supply Zone (Bearish):** `clrMistyRose` (Soft Rose-Pink)
  * **Climax Zone (Exhaustion):** `clrWheat` (Soft Sand-Beige)
* **Chronological Safety Enforcement:**
  To guarantee perfect synchronization between indicators and prices, the wrapper strictly forces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs and calculations inside `OnCalculate()`. This eliminates indexing mismatches when custom chart templates are applied.

---

## 5. Broken Zone Lookahead (Breaker Candle Scanning)

Once an absorption candle is identified, the indicator creates a visual zone (rectangle object) starting at the signal bar. To determine how long this zone remains valid, the engine runs a forward-scanning lookahead loop on every tick:

```mql5
// Forward scan looking for the break candle
datetime end_time = time[rates_total - 1] + PeriodSeconds() * 5; // Default: Live bar
bool broken = false;

for(int k = i + 1; k < rates_total; k++)
  {
   if(is_bull && close[k] < low[i])
     {
      end_time = time[k];
      broken = true;
      break;
     }
   if(is_bear && close[k] > high[i])
     {
      end_time = time[k];
      broken = true;
      break;
     }
  }
```

* **Intact Zones:** The rectangle extends continuously to the right edge of the chart (live bar), indicating that institutional liquidity is still protecting this price level.
* **Broken Zones:** The rectangle is anchored and locked at the exact timestamp ($time[k]$) of the breaker candle, and its border style is dynamically converted to a dotted format (`STYLE_DOT`), alerting the trader that the support/resistance level has been invalidated.

---

## 6. Quantitative VSA Trading Strategies

### A. The Institutional Demand Rebound (Long Entry)

This strategy seeks to enter the market when price returns to test an intact institutional Demand Absorption zone.

1. **Strategy Setup:**
   * Run `Absorption_Pro` on an M30 or H1 chart.
   * Identify a newly formed, intact **Demand Zone** (`clrLightSteelBlue` rectangle).
2. **Entry Conditions:**
   * Wait for price to correct back downwards and touch the upper boundary of the intact Demand Zone.
   * The touch candle must show a low or average volume, indicating a lack of selling pressure (No Supply Test).
   * **BUY Trigger:** Enter Long when a bullish rejection candle forms and closes above the Demand Zone.
3. **Risk Management:**
   * **Stop Loss:** Place Stop Loss 2-3 points below the lower boundary of the Demand Zone rectangle.
   * **Take Profit:** Exit at the opposing intact Supply Zone or at a 1:2 Risk-to-Reward ratio.

### B. The Climax Zone Breakout (Momentum Entry)

Volume Climax zones (`clrWheat`) represent major battlefields between bulls and bears where massive liquidity changed hands. Breaking this zone triggers explosive trend acceleration.

1. **Strategy Setup:**
   * Locate an intact **Climax Zone** (`clrWheat` rectangle).
2. **Entry Conditions:**
   * Wait for the market to consolidate tightly inside or near the Climax Zone.
   * **BUY Breakout Trigger:** Enter Long when a strong bullish candle closes completely above the high boundary of the Climax Zone.
   * **SELL Breakout Trigger:** Enter Short when a strong bearish candle closes completely below the low boundary of the Climax Zone.
3. **Execution Edge:** Because the Climax Zone represents a level of heavy institutional absorption, the side that finally wins the battle and breaks the zone will drive the price rapidly, generating low-lag breakout momentum.
