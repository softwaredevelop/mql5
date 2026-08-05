# Wyckoff Institutional Absorption Pro Suite (Standard & MTF)

## Technical Specification & Integration Manual

## 1. Summary (Introduction)

The **Wyckoff Institutional Absorption Pro Suite** is an institutional-grade quantitative trade-execution, liquidity-profiling, and key-reversal detection suite. It comprises two advanced indicators: `Absorption_Pro` (Standard, local timeframe tracer) and `Absorption_MTF_Pro` (Multi-Timeframe, higher-regime boundary tracer).

Developed upon the core tenets of **Volume Spread Analysis (VSA)** originated by Richard Wyckoff, the suite monitors the essential law of **Effort vs. Result**. In financial markets, institutional participants (smart money) cannot execute massive block orders without causing slippage. Instead, they accumulate or distribute positions using passive limit orders that "absorb" incoming aggressive market orders.

This absorption leaves a distinct footprint: a massive surge in trading volume (Effort) paired with a very narrow candle body (Lack of Result), indicating that an opposing wall of passive liquidity has halted price progression.

The suite provides traders with two synchronized instruments:

1. **`Absorption_Pro` (Standard):** Designed for active trading on the local timeframe. It features highly responsive entry arrows (`BufBull[]` and `BufBear[]`) and real-time local supply/demand zones.
2. **`Absorption_MTF_Pro` (Multi-Timeframe):** Designed strictly on a higher-timeframe (HTF) grid to project macro institutional blocks on lower timeframe charts. It is optimized for algorithmic scan integrations (such as the `Market_Scanner_Pro` script) by providing stateful calculations without any timeframe translation gaps.

---

## 2. Mathematical & Quant Foundations

The core engines calculate volatility-adjusted spread and relative volume values on every bar:

### A. Volatility Baseline via ATR (Average True Range)

To determine if a candle body is statistically "small," the spread is normalized against immediate market volatility using Wilder's smoothed ATR:

$$\text{TR}_t = \max \big( (H_t - L_t), |H_t - C_{t-1}|, |L_t - C_{t-1}| \big)$$

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \times (N - 1) + \text{TR}_t}{N}$$

Where $N$ represents the ATR period (typically `14`).

### B. Relative Volume (RVOL) - The Effort Metric

Relative Volume measures current trading volume against the average volume of the preceding $M$ bars (excluding the active bar), identifying institutional participation:

$$\text{RVOL}_t = \frac{V_t}{\frac{1}{M}\sum_{j=1}^{M} V_{t-j}}$$

Where $V$ represents tick volume (or exchange-supported real volume) and $M$ represents the RVOL lookback window (typically `20`).

### C. VSA Absorption & Climax Logic

On each bar $t$, the indicator evaluates the interaction between Effort (RVOL) and Result (Price Spread):

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

| Market Asset | Recommended Timeframe | ATR / RVOL Periods | History Bars Limit | Quantitative Objective |
| :--- | :--- | :---: | :---: | :--- |
| **Intraday FX / Indices** | M5 to M30 | `14` / `20` | `200` to `500` | Captures quick institutional blocks on M5/M15 charts. Limits lag during heavy session opens. |
| **Swing Commodities** | H1 to H4 | `14` / `24` | `500` | Tracks structural liquidity pools on H1/H4 charts. Identifies major reversal pivots. |
| **Cryptocurrencies** | M15 to H4 | `20` / `30` | `300` | Normalizes extreme exchange-driven volume spikes on highly volatile assets. |

---

## 4. Visual & Technical Highlights

* **Subtle Multi-Template Watermark Colors:**
  To prevent visual clutter on light or dark background templates, the indicators replace harsh, neon retail colors with soft, pastel MQL5 constants that act as native translucent background overlays:
  * **Demand Zone (Bullish):** `clrLightSteelBlue` (Soft Slate-Blue)
  * **Supply Zone (Bearish):** `clrMistyRose` (Soft Rose-Pink)
  * **Climax Zone (Exhaustion):** `clrWheat` (Soft Sand-Beige)
* **Chronological Array Safety:**
  The engines enforce strict chronological array indexing (`ArraySetAsSeries(..., false)`) across all price inputs and indicator buffers, completely eliminating phase shift errors or out-of-range array crashes.

---

## 5. Broken Zone Lookahead (Breaker Candle Scanning)

Once an absorption candle is identified, the indicators create a visual zone (rectangle object) starting at the signal bar. To determine how long this zone remains valid, the engines run a forward-scanning lookahead loop on every tick to find when the zone is broken by a future close price.

### A. Standard Mode (`Absorption_Pro` - LTF Close Break)

On standard local timeframe charts, the zóna is extended until the LTF Close price breaks the boundaries, converting the border style to a dotted format (`STYLE_DOT`):

```mql5
for(int k = i + 1; k < rates_total; k++)
  {
   if(is_bull && close[k] < low[i]) { end_time = time[k]; broken = true; break; }
   if(is_bear && close[k] > high[i]) { end_time = time[k]; broken = true; break; }
  }
```

### B. Unified HTF-Grid MTF Mode (`Absorption_MTF_Pro` - Unified HTF Close Break)

To prevent visual warping on lower timeframe charts (e.g., when viewing H1 zónas on M5), the MTF engine calculates the VSA criteria and draws the rectangle coordinates **strictly on the HTF grid**. Since MT5 charts share the same horizontal time axis, a rectangle drawn at `h_time[i]` will automatically align with micro-precision on the lower timeframe chart.

The forward-scanning breaker loop is executed on the **HTF close prices (`h_close[]`)**, ensuring absolute architectural stability and preventing memory lag or out-of-range errors caused by incomplete LTF history synchronization:

```mql5
for(int k = i + 1; k < g_htf_count; k++)
  {
   if(is_bull && h_close[k] < h_low[i]) { end_time = h_time[k]; broken = true; break; }
   if(is_bear && h_close[k] > h_high[i]) { end_time = h_time[k]; broken = true; break; }
  }
```

### C. Gapped-Safe Staircase Mapping for Scanners/EAs

To allow Expert Advisors or the `Market_Scanner_Pro` script to query the MTF indicators, the MTF version populates the calculation buffers `BufATR`, `BufRVOL`, and `BufState` down to the lower timeframe using the non-repainting Staircase Solution. This ensures that the state buffer values are available on every LTF tick.

---

## 6. Quantitative VSA Trading Strategies

### A. The Institutional Demand Rebound (Long Entry)

This strategy seeks to enter the market when price returns to test an intact institutional Demand Absorption zone.

```text
       [ Bearish Price Correction ]  ======>  [ Rebound / Touch ]
                                                     │
                                                     ▼
                                            [ INTACT DEMAND ZONE ]
                                            (clrLightSteelBlue Box)
```

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
   * Locate an intact **Climax Zone** (`clrWheat` rectangle) on an H1 or H4 chart (or via `Absorption_MTF_Pro` mapped to your active chart).
2. **Entry Conditions:**
   * Wait for the market to consolidate tightly inside or near the Climax Zone.
   * **BUY Breakout Trigger:** Enter Long when a strong bullish candle breaks out and closes completely above the high boundary of the Climax Zone.
   * **SELL Breakout Trigger:** Enter Short when a strong bearish candle breaks out and closes completely below the low boundary of the Climax Zone.
3. **Execution Edge:** Because the Climax Zone represents a level of heavy institutional absorption, the side that finally wins the battle and breaks the zone will drive the price rapidly, generating low-lag breakout momentum.
