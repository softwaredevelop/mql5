# Charles LeBeau's Chandelier Exit & Distance Oscillator Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Charles LeBeau's Chandelier Exit & Distance Oscillator Pro Suite** is an institutional-grade, low-latency trend-following, risk-management, and cyclical momentum tracking suite. It comprises two highly synchronized indicators: `Chandelier_Exit_Pro` (plotted on the main chart) and `Chandelier_Exit_Oscillator_Pro` (plotted in a separate subwindow).

Developed by Charles LeBeau, the Chandelier Exit is a stateful trailing stop-loss system designed to keep traders in a trend until a definitive cyclical reversal occurs. It operates on the logic that a trailing stop should be hung from the absolute highest high (or lowest low) of the trend, mimicking a chandelier hanging from a ceiling.

While the main chart indicator manages trailing stops, the **Chandelier Distance Oscillator** measures the *normalized distance* between the close price and the trailing stop line in units of average volatility (ATR).

By upgrading the legacy retail logic with our proprietary **Active-Line Reversal Rule**, the suite completely eliminates the traditional "sawtooth death-loop" during high-volatility regimes. Coupled with a 5-zone swapped thermal color palette, the suite provides a flawless mathematical representation of trend health, velocity, and execution risk.

---

## 2. Mathematical & Quant Foundations

The suite calculations are performed recursively, combining extreme lookback ranges with smoothed Average True Range (ATR) volatility.

### A. Core Volatility Baseline (ATR)

The baseline volatility is calculated using the standard Wilder's smoothed ATR over the configured period ($N$):

$$\text{TR}_t = \max \big( (H_t - L_t), |H_t - C_{t-1}|, |L_t - C_{t-1}| \big)$$

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \times (N - 1) + \text{TR}_t}{N}$$

### B. Raw Chandelier Exit Bands

The raw long and short stop bands are hung from the highest high (or lowest low) over the lookback period $N$, using the ATR multiplier ($\kappa$):

$$\text{LongStop}_t = \max_{j=0 \dots N-1} (H_{t-j}) - \kappa \times \text{ATR}_t$$

$$\text{ShortStop}_t = \min_{j=0 \dots N-1} (L_{t-j}) + \kappa \times \text{ATR}_t$$

### C. The Chandelier Distance Oscillator

The companion oscillator measures the distance of the close price relative to the active stop line, normalized in standard volatility units:

$$\text{Chandelier Oscillator}_t = \frac{P_t - \text{StopLine}_t}{\text{ATR}_t}$$

Where $P_t$ is the close price (Standard or Heikin Ashi). Because $\text{ATR}_t > 1.0e-9$, division-by-zero exceptions are strictly prevented.

---

## 3. Quant Paradigm Shift: Volatility Velocity vs. Mean Reversion

A critical, highly sophisticated distinction exists between the **Chandelier Distance Oscillator** and standard **Z-Score oscillators** (such as the L-Score):

### A. Standard Z-Score (Mean-Reverting Model)

Standard Z-Score oscillators measure price distance relative to a *moving average mean* (which sits in the center of price action). Because the mean acts as a gravitational anchor, extreme positive or negative peaks (e.g., $\ge \pm2.5$) represent high-probability **exhaustion points** where the price is statistically stretched and must regress back to its mean (Mean Reversion).

### B. Chandelier Distance Oscillator (Trend-Following Momentum Model)

The Chandelier Oscillator measures price distance relative to a *trailing stop* (which sits *below* price in a bullish trend and *above* price in a bearish trend).

* **The Ceiling Phenomenon:** During a highly efficient trend breakout, the price expands rapidly away from the stop line. The oscillator spikes to its maximum potential ceiling (equivalent to the multiplier coefficient, $\pm \kappa$).
* **Trend Continuation:** As long as the trend remains powerful and consistent, the price maintains its distance from the trailing stop. The oscillator does **not** revert; instead, it **plateaus at its ceiling** (forming flat, extended peaks).
* **The Trading Logic:** Consequently, a peak in the Chandelier Oscillator does **not** signify a reversal. It represents **maximum trend velocity and strong continuation**. A contraction back towards the zero-line (e.g., from `+2.5` to `+1.0`) represents a temporary, healthy **trend consolidation** (price pulling back to test its stop-loss floor). A true trend reversal is triggered **strictly and only when the oscillator crosses the zero (0.0) line**.

```text

    Mean Reversion (LScore):     [Peak/Extreme Deviation]  ====>  Expected Reversal (Pivot)
    Trend Following (Chandelier): [Peak/Ceiling Plateau]   ====>  Strong Trend Continuation

```

---

## 4. Visual Symmetrical 5-Zone Thermal Matrix

To track trend velocity and consolidation risk, the oscillator histogram is mapped to a 5-zone swapped thermal color palette (matching the exact colors of our institutional suite):

| Color Index | Oscillator State | Mathematical Condition | Visual Representation |
| :---: | :--- | :--- | :--- |
| **`0.0`** | **Neutral / Consolidation** | $ \text{Osc}_t \le 1.5$ | **`clrGray`** (Price is consolidating close to the Stop) |
| **`1.0`** | **Bullish Flow** | $\text{Osc}_t > 1.5 \quad \text{AND} \quad \text{Osc}_t \le 2.0$ | **`clrLightSkyBlue`** (Stable, healthy uptrend) |
| **`2.0`** | **Bullish Climax (Ceiling)** | $\text{Osc}_t > 2.0$ | **`clrDeepSkyBlue`** (High-velocity, explosive uptrend) |
| **`3.0`** | **Bearish Flow** | $\text{Osc}_t < -1.5 \quad \text{AND} \quad \text{Osc}_t \ge -2.0$ | **`clrCoral`** (Stable, healthy downtrend) |
| **`4.0`** | **Bearish Climax (Ceiling)** | $\text{Osc}_t < -2.0$ | **`clrOrangeRed`** (High-velocity, explosive downtrend) |

---

## 5. Advanced MQL5 Engineering: The Active-Line Reversal Rule

Standard retail Chandelier Exit indicators suffer from a severe logical flaw: during violent trend reversals, they permit the trend to flip falsely, creating a **"sawtooth death-loop"** where the stop line oscillates up and down on every bar, destroying the chart's readability and corrupting the oscillator's output.

### A. The Retail Sawtooth Trap

If the trend is Bearish (Stop line is high above price), and a sudden volatile spike occurs, the price crosses above the deep `ShortStop` sáv, triggering a bullish flip. However, because the trade was just entered, the `LongStop` is calculated using `Highest(High)` of the last 22 bars. Because of the recent crash, the `Highest(High)` is still the **pre-crash high** (extremely high).

The bullish stop line is suddenly plotted *above* the price. On the very next bar, the engine detects that the price is below the bullish stop, and immediately flips back to Bearish. This repeats continuously.

### B. The Active-Line Reversal Safeguard

Our refactored `Chandelier_Exit_Calculator.mqh` solves this by implementing the **Symmetrical Active-Line Reversal Rule**. A trend flip is strictly permitted **only if the price crosses the active trailing stop line AND the new stop line would lie on the correct side of the price**:

```mql5
if(prev_trend == 1.0) // Trend was Bullish (Stop is below price)
  {
   // Flip to bearish ONLY if price closes BELOW active stop AND the new bearish stop is safely ABOVE price
   if(m_price_close[i] < prev_stop && m_short_stop[i] > m_price_close[i])
     {
      m_trend[i]   = -1.0;
      stop_line[i] = m_short_stop[i]; // Reset to ShortStop
     }
   else
     {
      m_trend[i]   = 1.0;
      stop_line[i] = MathMax(m_long_stop[i], prev_stop); // Ratchet
     }
  }
```

This guarantees that a Bullish stop is *always* below the price, a Bearish stop is *always* above the price, and the "sawtooth death-loop" is 100% eliminated, producing clean, smooth, staircase steps even on extremely volatile assets like Bitcoin (BTCUSD).

---

## 6. Symmetrical Quantitative Trading Strategies

### A. The Volatility Breakout Zero-Crossing Trigger (Trend Initiation)

This strategy captures the exact beginning of high-velocity trend expansions.

1. **Indicator Setup:**
   * **Chandelier Exit Pro:** Period = `22`, Multiplier = `3.0`, Source = `PRICE_CLOSE_STD`.
   * **Chandelier Exit Oscillator Pro:** Same settings, Signal Line = `Enabled` (Slowing = `5`, Type = `LWMA`).
2. **Execution Rules:**
   * **BUY Trigger:** Enter Long when the **Chandelier Oscillator crosses above the 0.0 line** (transitioning from Coral/OrangeRed to DodgerBlue/LightSkyBlue). This confirms that price has broken the Trailing Stop, initiating a fresh Bullish trend.
   * **SELL Trigger:** Enter Short when the **Chandelier Oscillator crosses below the 0.0 line**.
3. **Risk Management:**
   * Place the Stop Loss exactly at the newly plotted Chandelier Trailing Stop line on the main chart.
   * Trail the stop in real-time as the trend expands.

### B. The Institutional Pullback Reentry (Flow Zone Touch)

This strategy utilizes the "deceleration pullback" to enter an ongoing trend at the optimal risk-to-reward ratio.

1. **Indicator Setup:**
   * Same indicators loaded. Period = `22`, Multiplier = `2.5`.
2. **Execution Rules:**
   * **BUY Entry (Bullish Pullback):** In an established Bullish trend (oscillator has been plateauing in the `clrDeepSkyBlue` climax zone above `2.0`):
     * Wait for a corrective pullback where the price drops close to the stop line, causing the oscillator to contract from the climax zone into the **Neutral/Consolidation Zone** ($|\text{Osc}_t| \le 1.5$ / `clrGray` bars).
     * **Trigger:** Enter Long on the first bar where the histogram turns **back to `clrLightSkyBlue`** (crossing above $1.5$ with a bullish bounce), or when the histogram crosses above its **LWMA Signal Line** from below.
3. **Strategic Advantage:** Entering during the consolidation pullback allows you to enter the ongoing trend at a minimal distance from the stop-loss floor, achieving an ultra-tight risk profile while riding the institutional trend continuation.
