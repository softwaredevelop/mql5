# John Ehlers' Ehlers Smoother Acceleration Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Ehlers Smoother Acceleration Pro Suite** is an institutional-grade, low-latency trend-deceleration and trend-exhaustion tracking engine. It consists of two highly optimized indicators: `Ehlers_Smoother_Acceleration_Pro` (Standard) and `Ehlers_Smoother_Acceleration_Pro` (Multi-Timeframe variant).

In physical dynamics, an object must decelerate before it can reverse direction. Similarly, in financial markets, the force of buying or selling pressure decelerates before price forms a structural swing pivot. While the first derivative (Velocity or Slope) shows the direction and speed of a trend, the **second derivative (Acceleration)** measures the *rate of change of that velocity*.

Standard market acceleration indicators (such as the second difference of raw price) are un-tradable because mathematical differentiation exponentially amplifies high-frequency market noise (chatter).

This suite resolves this noise-amplification bottleneck by calculating the second difference of John Ehlers' highly optimized **SuperSmoother** and **UltimateSmoother** filters:

$$\text{Acceleration}_t = \text{Filter}_t - 2 \times \text{Filter}_{t-1} + \text{Filter}_{t-2}$$

Because these filters are fourier-engineered using 2-pole Butterworth topologies designed to completely eliminate overshoot (ringing) and minimize phase delay, they completely eliminate the noise floor. Taking the second difference of this pristine baseline results in an exceptionally smooth, fourier-stable acceleration wave.

By classifying this clean acceleration wave into a symmetrical 5-zone thermal matrix (using blues for bullish acceleration and reds/corals for bearish acceleration), the suite allows quant traders to identify the exact market inflection points (inflexiós pontok) with near-zero lag.

---

## 2. Mathematical & Quant Foundations

The indicator calculates the second difference of a stateful, recursive SuperSmoother or UltimateSmoother filter.

### A. Recursive Smoothers Baseline Formulas

On each bar $t$, the decimal price $P_t$ (Standard or Heikin Ashi) is processed through the selected smoother configuration. The baseline coefficients are calculated using the smoothing period ($T$):

$$a_1 = e^{-\frac{\sqrt{2}\pi}{T}}, \quad b_1 = 2a_1 \cos \left(\frac{\sqrt{2}\pi}{T} \right), \quad c_2 = b_1, \quad c_3 = -a_1^2$$

#### 1. SuperSmoother Filter

The coefficient $c_1$ is calculated to ensure a flat passband response with zero overshoot:

$$c_1 = 1.0 - c_2 - c_3$$

$$\text{Filter}_t = c_1 \times \frac{P_t + P_{t-1}}{2} + c_2 \times \text{Filter}_{t-1} + c_3 \times \text{Filter}_{t-2}$$

#### 2. UltimateSmoother Filter

The coefficient $c_1$ is adjusted to incorporate high-pass characteristics for zero-lag tracking:

$$c_1 = \frac{1.0 + c_2 - c_3}{4}$$

$$\text{Filter}_t = (1.0 - c_1) P_t + (2.0 c_1 - c_2) P_{t-1} - (c_1 + c_3) P_{t-2} + c_2 \text{Filter}_{t-1} + c_3 \text{Filter}_{t-2}$$

### B. The Acceleration Equation

The Acceleration ($A_t$) represents the change in Slope ($\text{Slope}_t - \text{Slope}_{t-1}$). It is derived mathematically as:

$$A_t = (\text{Filter}_t - \text{Filter}_{t-1}) - (\text{Filter}_{t-1} - \text{Filter}_{t-2})$$

$$A_t = \text{Filter}_t - 2 \times \text{Filter}_{t-1} + \text{Filter}_{t-2}$$

Due to requiring two lookback periods of history, calculations are strictly restricted to indices $t \ge 2$.

### C. 5-Zone Symmetrical Thermal Acceleration Matrix

The acceleration $A_t$ is classified into a specific visual state based on an adjustable noise threshold ($\epsilon$):

| Color Index | Market State | Mathematical Condition | Visual Representation |
| :---: | :--- | :--- | :--- |
| **`0.0`** | **Neutral / Noise** | $A_t \le \epsilon$ | **`clrGray`** (No directional acceleration) |
| **`1.0`** | **Strong Bullish Acceleration** | $A_t > \epsilon \quad \text{AND} \quad A_t > A_{t-1}$ | **`clrDodgerBlue`** (Buying force is accelerating) |
| **`2.0`** | **Weak Bullish Deceleration** | $A_t > \epsilon \quad \text{AND} \quad A_t \le A_{t-1}$ | **`clrLightSkyBlue`** (Buying force is slowing down) |
| **`3.0`** | **Strong Bearish Acceleration** | $A_t < -\epsilon \quad \text{AND} \quad A_t < A_{t-1}$ | **`clrCrimson`** (Selling force is accelerating) |
| **`4.0`** | **Weak Bearish Deceleration** | $A_t < -\epsilon \quad \text{AND} \quad A_t \ge A_{t-1}$ | **`clrCoral`** (Selling force is slowing down) |

---

## 3. Recommended Calibration & Volatility Presets

Because second differences yield extremely small fractional values, configuring the neutral noise threshold ($\epsilon$) correctly is key to isolating consolidations:

| Asset Class | Timeframe | Smoother Type | Period ($T$) | Threshold ($\epsilon$) | Quant Tactical Objective |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Major FX Pairs** | M15 / H1 | `SUPERSMOOTHER` | `20` | `0.000010` | **Execution Reversal.** Catches early intraday cyclical pivots with minimum lag. |
| **Equity Indices** | H1 / H4 | `ULTIMATESMOOTHER` | `15` | `0.000050` | **Volatility Breakout.** Zero-lag response is ideal for breakout trading. |
| **Cryptocurrencies** | H4 / Daily | `SUPERSMOOTHER` | `25` | `0.000250` | **Exhaustion Detection.** Bypasses heavy retail noise to expose macro exhaustion points. |

---

## 4. Visual & Technical Highlights

* **Micro-Point Precision Settings:**
  Since second differences represent tiny fractional shifts, the indicator automatically increases the chart decimal display to four decimals past standard digit precision (`_Digits + 4`) to prevent visual rounding anomalies:

  ```mql5
  IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 4);
  ```

* **Performance-First O(1) Updates:**
  By avoiding dynamic memory allocation (`new`/`delete`) inside the `OnCalculate()` tick loop, the indicator prevents heap fragmentation. Calculations are performed on the stack using localized, state-safe dynamic structures.
* **Double-Smoothed VWMA Signal Line:**
  When configured to VWMA, the indicator converts the platform volume arrays to a `double` cache array, applying volume weighting to the Signal MA. This ensures crossovers are backed by institutional transaction volume.

---

## 5. Advanced MQL5 MTF Implementation Details

Running higher-order recursive filters like the UltimateSmoother across multiple timeframes requires robust engineering:

### A. Non-Warping Staircase Solution

To prevent the active, forming HTF candle from drawing a warped diagonal slope on lower timeframe charts, the indicator runs a backward-scanning block-force loop. It identifies the beginning of the active forming HTF block and rewrites the entire block flat on every tick:

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

### B. High-Order IIR State Mocking

Since Ehlers' smoothers rely on deep historical states ($\text{Filter}_{t-1}, \text{Filter}_{t-2}$), calling calculations continuously on the live forming bar on every tick can cause feedback decay. To solve this, the MTF engine uses **State Mocking** during live ticks by passing `prev_calculated = g_htf_count`, which updates only the active live register while keeping historical closed states completely locked.

---

## 6. Quantitative Trading Strategies

### A. The Calculus Inflection Strategy (0-Line Reversal)

According to calculus, when the second derivative (Acceleration) crosses the zero line, the first derivative (Velocity) has reached its absolute peak, and the underlying curve is at an inflection point.

1. **Indicator Setup:**
   * **Ehlers Smoother Acceleration Pro:** Period = `20`, Type = `ULTIMATESMOOTHER`, Threshold = `0.000010`.
   * **Signal Line:** Disabled.
2. **Execution Rules:**
   * **BUY Trigger:** Enter Long when the histogram crosses **above the zero line** (turning from Crimson/Coral to DodgerBlue). This indicates that downward pressure has exhausted and buying acceleration has taken control.
   * **SELL Trigger:** Enter Short when the histogram crosses **below the zero line** (turning from DodgerBlue/LightSkyBlue to Crimson).
3. **Strategic Edge:** By entering on the zero-crossing of the *second derivative* (Acceleration), you enter the market at the exact inflection point of Ehlers' filter, capturing the trend far earlier than standard MACD or EMA crossover systems.

```text
       [ Bearish Accel (Crimson) ]  ==> [ ZERO CROSS ] ==> [ Bullish Accel (Blue) ]
       (Downward Force Exhausted)                          (BUY ENTRY TRIGGERED)
```

### B. The Volume-Weighted Deceleration Exit Strategy

This strategy uses the transition from strong acceleration to weak deceleration, backed by volume, to exit trend-following trades at the absolute peak before the price reverses.

1. **Indicator Setup:**
   * **Ehlers Smoother Acceleration Pro:** Period = `20`, Type = `SUPERSMOOTHER`, Threshold = `0.000010`.
   * **Signal MA:** Enabled, Period = `5`, Type = `VWMA`.
2. **Execution Rules:**
   * **Bullish Exit (Exit Longs):** When holding a Long position and the histogram is in **Strong Bullish Acceleration** (`clrDodgerBlue`), exit the trade immediately when the histogram bar transitions to **Weak Bullish Deceleration** (`clrLightSkyBlue`) AND **crosses below the VWMA Signal Line**.
   * **Bearish Exit (Exit Shorts):** When holding a Short position and the histogram is in **Strong Bearish Acceleration** (`clrCrimson`), exit the trade immediately when the histogram bar transitions to **Weak Bearish Deceleration** (`clrCoral`) AND **crosses above the VWMA Signal Line**.
3. **Strategic Advantage:** Traditional trailing stops require price to drop significantly before triggering an exit, giving back a large portion of accrued profits. This strategy detects when the *volume-backed acceleration* of the trend begins to slow down, allowing you to exit at the optimal crest of the wave.
