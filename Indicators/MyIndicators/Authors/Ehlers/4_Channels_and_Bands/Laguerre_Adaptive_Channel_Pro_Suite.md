# John Ehlers' Laguerre Adaptive Channel Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Laguerre Adaptive Channel Pro Suite** is an institutional-grade, low-latency volatility channel and structural envelope system. It comprises two highly optimized indicators: `Laguerre_Adaptive_Channel_Pro` (Standard) and its Multi-Timeframe (MTF) counterpart.

Standard envelope systems, such as Bollinger Bands or Keltner Channels, calculate their upper and lower boundaries around static moving average baselines (such as SMA or EMA). During violent trend reversals, these static baselines lag significantly, causing the bands to react too late and rendering price breakouts visually distorted.

This suite resolves this limitation by wrapping volatility-based boundaries around a **John Ehlers' Adaptive Laguerre Filter baseline**.

Because the baseline dynamically adapts its Gamma ($\gamma$) in real-time using Kaufman's Efficiency Ratio (ER), ATR, or Standard Deviation:

* **In trending markets:** The baseline accelerates, tracking price closely with near-zero lag. The boundaries expand quickly, signaling high-velocity breakout entries at the immediate start of the trend.
* **In sideways consolidations:** The baseline decelerates, drawing a smooth, flat median line. The boundaries contract tightly, isolating market noise and highlighting a clean consolidation squeeze.

To prevent configuration errors and ensure absolute structural consistency, the channel width calculation is restricted via a dedicated, type-safe leg legordülő menu supporting **ATR (Keltner-style)** or **Standard Deviation (Bollinger-style)** volatility width.

---

## 2. Mathematical & Quant Foundations

The indicator represents a highly optimized, stateful mathematical pipeline plotted directly on the main chart:

### A. The Adaptive Laguerre Median Baseline

The core median line represents Ehlers' 4-dimensional polynomial Laguerre Filter. It dynamically scales its feedback coefficient $\gamma_t$ based on the normalized adaptive metric $M_t \in [0.0, 1.0]$:

$$\gamma_t = \gamma_{\max} - M_t \times (\gamma_{\max} - \gamma_{\min})$$

The baseline mean is calculated recursively:

$$\text{Baseline}_t = \frac{L_{0, t} + 2 \times L_{1, t} + 2 \times L_{2, t} + L_{3, t}}{6}$$

### B. Channel Width Volatility Methods

To compute the upper and lower boundaries, the user selects one of two physical volatility metrics, which are then multiplied by the multiplier coefficient ($\kappa$):

#### 1. Average True Range (ATR Keltner-style Width)

Calculates range-based volatility using Wilder's smoothed ATR over the width period $W$:

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \times (W - 1) + \text{TR}_t}{W}$$

$$\text{Upper Band}_t = \text{Baseline}_t + \kappa \times \text{ATR}_t$$

$$\text{Lower Band}_t = \text{Baseline}_t - \kappa \times \text{ATR}_t$$

#### 2. Standard Deviation (StDev Bollinger-style Width)

Calculates price dispersion relative to the Simple Moving Average (SMA) over the width period $W$:

$$\text{Mean}_t = \frac{1}{W} \sum_{j=0}^{W-1} P_{t-j}$$

$$\text{Variance}_t = \frac{1}{W} \sum_{j=0}^{W-1} (P_{t-j} - \text{Mean}_t)^2$$

$$\text{Upper Band}_t = \text{Baseline}_t + \kappa \times \sqrt{\text{Variance}_t}$$

$$\text{Lower Band}_t = \text{Baseline}_t - \kappa \times \sqrt{\text{Variance}_t}$$

---

## 3. Recommended Calibration Presets

| Asset Class | Timeframe | Baseline Adaptive Method | Width Method | Multiplier ($\kappa$) | Quant Tactical Role |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Major FX Pairs** | M5 / M15 | `METHOD_EFFICIENCY_RATIO` | `WIDTH_METHOD_ATR` | `1.5` | **Intraday Scalping Channels.** Captures quick, volatility-backed breakouts while squeezing flat during news-pauses. |
| **Equity Indices** | M30 / H1 | `METHOD_ATR` | `WIDTH_METHOD_STAND_DEV` | `2.0` | **Dynamic Trend Envelope.** Tracks index expansions tightly. Excellent for riding momentum waves. |
| **Commodities (Gold)** | H1 / H4 | `METHOD_STAND_DEV` | `WIDTH_METHOD_ATR` | `2.2` | **Volatility Envelope.** Identifies structural over-extension pivots. Bypasses macro market noise. |

---

## 4. Visual & Technical Highlights

* **High-End UI Type Safety:**
  By implementing a dedicated `ENUM_CHANNEL_WIDTH_METHOD` instead of reusing dimensionless adaptive enums, the indicator strictly prevents the user from selecting illogical methods (like Kaufman ER) for physical price-width calculations. The dropdown menu is restricted natively to **ATR** and **StDev**.
* **Elegantly Subdued Visual Comfort:**
  To maintain professional visual cleanliness on the chart, the upper and lower bands are plotted as thin, dashed palaszürke lines (`clrSlateGray`, `STYLE_DASH`, width 1). The core adaptive baseline is highlighted as a solid DodgerBlue line (`clrDodgerBlue`, width 2) to ensure clear structural direction.
* **Chronological Safety Guards:**
  The engine enforces chronological array indexing (`ArraySetAsSeries(..., false)`) across all price arrays, internal perisistent buffers, and indicator buffers, completely eliminating phase shift errors during template changes.

---

## 5. Advanced MQL5 MTF Implementation Details

Displaying volatility bands across multiple timeframes requires precise architectural safeguards to ensure stable visual steps and prevent real-time repainting:

### A. Non-Warping Staircase Solution

To prevent the active, forming HTF candle from drawing a warped diagonal slope on lower timeframe charts, the indicator runs a backward-scanning block-force loop. It identifies the beginning of the active forming HTF block and rewrites the entire block flat on every tick, keeping steps historically stable:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Anchor start of current HTF period block

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

### B. State Mocking for IIR Baseline Stability

Because the adaptive Laguerre baseline is highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states ($L_0$ to $L_3$). To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 6. Quantitative Channel Trading Strategies

### A. The Adaptive Laguerre Volatility Squeeze (Bollinger-style Squeeze)

Consolidation zones occur when price efficiency is low and price dispersion contracts. This strategy enters on explosive breakouts following tight volatility squeezes.

1. **Strategy Setup:**
   * **Laguerre Adaptive Channel:** Baseline = `METHOD_EFFICIENCY_RATIO`, Width Method = `WIDTH_METHOD_STAND_DEV`, Multiplier = `2.0`.
2. **Strategy Mechanics:**
   * During consolidation, ER is low, Gamma dilates towards `0.882`, and Standard Deviation contracts. The Upper and Lower bands squeeze tightly around a flat DodgerBlue baseline.
   * **BUY Trigger:** Enter Long when a strong bullish candle breaks out and **closes completely above the Upper Band** while the baseline starts bending upwards.
   * **SELL Trigger:** Enter Short when a strong bearish candle breaks out and **closes completely below the Lower Band** while the baseline bends downwards.
3. **Execution Edge:** Entering at the breakout of a tight Adaptive Squeeze ensures high momentum, as the adaptive baseline immediately accelerates to catch the new trend, keeping your stop-loss close.

### B. The Dynamic Keltner Trend Rider (Pullback Reentry)

This strategy enters established trends when price pulls back to test the low-lag adaptive baseline acting as dynamic support or resistance.

1. **Strategy Setup:**
   * **Laguerre Adaptive Channel:** Baseline = `METHOD_ATR`, Width Method = `WIDTH_METHOD_ATR`, Multiplier = `1.5` or `2.0`.
2. **Execution Rules:**
   * **BUY Trend Entry:** In a confirmed bullish trend (price is consistently trading in the upper half of the channel, above the DodgerBlue baseline):
     * Wait for a temporary corrective pullback where price touches or slightly penetrates the baseline from above.
     * **Trigger:** Enter Long on the first bullish reversal candle that closes back above the baseline.
   * **SELL Trend Entry:** In a confirmed bearish trend (price trading below the baseline):
     * Wait for a corrective pullback where price touches the baseline from below.
     * **Trigger:** Enter Short on the first bearish reversal candle that closes back below the baseline.
3. **Risk Management:**
   * Place the Stop Loss strictly below the Lower Band (for Long entries) or above the Upper Band (for Short entries).
   * Trail the Stop Loss along the baseline as the trend accelerates.
