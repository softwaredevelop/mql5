# John Ehlers' Laguerre Acceleration Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Laguerre Acceleration Pro Suite** is an institutional-grade quantitative momentum tool comprising two high-performance indicators: `Laguerre_Acceleration_Pro` (Standard) and `Laguerre_Acceleration_Pro` (Multi-Timeframe variant).

While the first derivative of price (Velocity or Slope) shows the direction and speed of a trend, the **second derivative (Acceleration)** measures the *rate of change of that velocity*. In physical dynamics, an object must slow down before it can reverse direction. Similarly, in financial markets, the force of buying or selling pressure decelerates before price forms a structural swing pivot.

By calculating the mathematical acceleration of John Ehlers' stateful 4-dimensional Laguerre Filter, this suite isolates these deceleration phases with near-zero lag. Unlike traditional momentum oscillators (such as ROC, Price-Velocity, or CCI) which produce jagged, noisy signals that trigger frequent whipsaws, the Laguerre Acceleration suite leverages Ehlers' fourier-aligned smoothing to produce a highly organic, noise-filtered acceleration profile.

Equipped with an adjustable volatility-neutralizer threshold, an optional volume-weighted (VWMA) signal line, and a symmetrical 5-zone thermal acceleration color palette, this suite offers quant traders an unparalleled early warning system for trend exhaustion and explosive breakouts.

---

## 2. Mathematical Foundations

The indicator calculates acceleration by taking the second difference of Ehlers' recursive low-pass IIR Laguerre Filter.

### A. Recursive Polynomial States

At any given bar $t$, the chosen price source $P_t$ (Standard or Heikin Ashi) is transformed into four independent polynomial state registers ($L_0$ to $L_3$), governed by the Gamma ($\gamma$) feedback coefficient:

$$L_{0, t} = (1 - \gamma) P_t + \gamma L_{0, t-1}$$

$$L_{1, t} = -\gamma L_{0, t} + L_{0, t-1} + \gamma L_{1, t-1}$$

$$L_{2, t} = -\gamma L_{1, t} + L_{1, t-1} + \gamma L_{2, t-1}$$

$$L_{3, t} = -\gamma L_{2, t} + L_{2, t-1} + \gamma L_{3, t-1}$$

The baseline low-pass filter represents the weighted sum of these states:

$$\text{Filter}_t = \frac{L_{0, t} + 2 \times L_{1, t} + 2 \times L_{2, t} + L_{3, t}}{6}$$

### B. The Acceleration Equation

The Acceleration ($A_t$) represents the change in Slope ($\text{Slope}_t - \text{Slope}_{t-1}$). It is derived mathematically as:

$$A_t = (\text{Filter}_t - \text{Filter}_{t-1}) - (\text{Filter}_{t-1} - \text{Filter}_{t-2})$$

$$A_t = \text{Filter}_t - 2 \times \text{Filter}_{t-1} + \text{Filter}_{t-2}$$

Due to requiring two lookback periods of history, calculations are strictly restricted to indices $t \ge 2$.

### C. 5-Zone Symmetrical Acceleration Matrix

To track the expansion and contraction of these market forces, each bar is mapped into a specific visual state based on an adjustable noise threshold ($\epsilon$):

| Color Index | Acceleration State | Mathematical Condition | Visual Representation |
| :---: | :--- | :--- | :--- |
| **`0.0`** | **Neutral / Noise** | $A_t \le \epsilon$ | **`clrGray`** (No accelerating force) |
| **`1.0`** | **Strong Bullish Acceleration** | $A_t > \epsilon \quad \text{AND} \quad A_t > A_{t-1}$ | **`clrDodgerBlue`** (Buying force is accelerating) |
| **`2.0`** | **Weak Bullish Deceleration** | $A_t > \epsilon \quad \text{AND} \quad A_t \le A_{t-1}$ | **`clrLightSkyBlue`** (Buying force is slowing down) |
| **`3.0`** | **Strong Bearish Acceleration** | $A_t < -\epsilon \quad \text{AND} \quad A_t < A_{t-1}$ | **`clrCrimson`** (Selling force is accelerating) |
| **`4.0`** | **Weak Bearish Deceleration** | $A_t < -\epsilon \quad \text{AND} \quad A_t \ge A_{t-1}$ | **`clrCoral`** (Selling force is slowing down) |

---

## 3. Volatility Calibration & Settings

Because acceleration is highly sensitive to the volatility profile of the target market, the noise-filtering threshold ($\epsilon$) must be calibrated appropriately to separate true market expansions from low-volume consolidation zones.

### Recommended Volatility Presets

| Asset Class | Typical Volatility | Recommended Gamma ($\gamma$) | Recommended Threshold ($\epsilon$) | Quant Objective |
| :--- | :--- | :--- | :--- | :--- |
| **Major FX Pairs** | Low | **`0.500`** (Balanced) | `0.000005` to `0.000015` | Captures structural macro currency reversals on M15/H1 charts. |
| **Equity Indices** | Medium-High | **`0.618`** (Golden Anchor) | `0.000020` to `0.000050` | Filters out market-open volatility spikes. |
| **Gold / Commodities** | High | **`0.618`** (Golden Anchor) | `0.000100` to `0.000250` | Follows commodity trend cycles while bypassing whipsaws. |
| **Cryptocurrencies** | Ultra-High | **`0.764`** (Strong) | `0.000500` to `0.001500` | Smooths out extreme retail-driven volatile swings. |

---

## 4. Visual & Architectural Highlights

The Laguerre Acceleration Pro Suite is engineered to run seamlessly under extreme, volatile market conditions:

* **Micro-Point Precision Settings:**
  Since second differences represent tiny fractional shifts, the indicator automatically increases the chart decimal display to four decimals past standard digit precision (`_Digits + 4`):

  ```mql5
  IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 4);
  ```

  This prevents visual rounding anomalies, ensuring that micro-point acceleration values are fully legible.

* **O(1) Memory Footprint:**
  By avoiding dynamic memory allocation (`new`/`delete`) inside the `OnCalculate()` tick loop, the indicator prevents heap fragmentation. Calculations are performed on the stack using localized, state-safe dynamic structures.
* **Dynamic Volume-Type Routing:**
  When Signal MA is configured to Volume-Weighted (VWMA), the engine automatically checks `SYMBOL_VOLUME_LIMIT`. It dynamically extracts `CopyRealVolume()` if Exchange-supported real volume is available, or transparently falls back to `CopyTickVolume()` for FX/CFD brokers.

---

## 5. Advanced MQL5 MTF Implementation Details

Running high-order derivatives like acceleration across multiple timeframes requires robust engineering to prevent repainting, calculation lag, and real-time step warping.

### A. The Non-Warping Staircase Solution

On lower timeframe charts, the higher timeframe values are plotted as flat, horizontal blocks. To prevent the active, forming HTF candle from drawing a warped diagonal slope in real-time, the indicator runs a backward-scanning loop to identify the exact lower-timeframe bar where the active HTF period began. It then forces the entire block to repaint flat on every tick:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start anchor of active forming HTF block

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

### B. State Mocking for IIR Stability

Because the second difference is calculated recursively, calling calculations on the live forming bar on every tick can cause register decay. To solve this, the MTF engine uses **State Mocking** during live ticks by passing `prev_calculated = g_htf_count`, which updates only the active live register while keeping historical closed states completely locked.

---

## 6. Fibonacci & Acceleration Quantitative Strategies

### A. The Calculus Inflection Strategy (0-Line Reversal)

According to calculus, when the second derivative (Acceleration) crosses the zero line, the first derivative (Velocity) has reached its absolute peak, and the underlying curve is at an inflection point.

1. **Indicator Setup:**
   * **Laguerre Acceleration Pro:** Gamma = **`0.500`**, Threshold = `0.000010`.
   * **Signal Line:** Disabled.
2. **Execution Rules:**
   * **BUY Trigger:** Enter Long when the histogram crosses **above the zero line** (turning from Crimson/Coral to DodgerBlue). This indicates that the downward force has exhausted and buying acceleration has taken control.
   * **SELL Trigger:** Enter Short when the histogram crosses **below the zero line** (turning from DodgerBlue/LightSkyBlue to Crimson).
3. **Strategic Edge:** By entering on the zero-crossing of the *second derivative* (Acceleration), you enter the market at the exact inflection point of Ehlers' filter, capturing the trend far earlier than standard MACD or EMA crossover systems.

```text
       [ Bearish Accel (Crimson) ]  ==> [ ZERO CROSS ] ==> [ Bullish Accel (Blue) ]
       (Downward Force Exhausted)                          (BUY ENTRY TRIGGERED)
```

### B. The Volume-Backed Deceleration Exit Strategy

This strategy uses the transition from strong acceleration to weak deceleration, backed by volume, to exit trend-following trades at the absolute peak before the price reverses.

1. **Indicator Setup:**
   * **Laguerre Acceleration Pro:** Gamma = **`0.618`**, Threshold = `0.000020`.
   * **Signal MA:** Enabled, Period = **`5`**, Type = **`VWMA`**.
2. **Execution Rules:**
   * **Bullish Exit (Exit Longs):** When holding a Long position and the histogram is in **Strong Bullish Acceleration** (`clrDodgerBlue`), exit the trade immediately when the histogram bar transitions to **Weak Bullish Deceleration** (`clrLightSkyBlue`) AND **crosses below the VWMA Signal Line**.
   * **Bearish Exit (Exit Shorts):** When holding a Short position and the histogram is in **Strong Bearish Acceleration** (`clrCrimson`), exit the trade immediately when the histogram bar transitions to **Weak Bearish Deceleration** (`clrCoral`) AND **crosses above the VWMA Signal Line**.
3. **Strategic Advantage:** Traditional trailing stops require price to drop significantly before triggering an exit, giving back a large portion of accrued profits. This strategy detects when the *volume-backed acceleration* of the trend begins to slow down, allowing you to exit at the optimal crest of the wave.
