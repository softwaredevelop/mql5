# John Ehlers' Butterworth Slope Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Butterworth Slope Pro Suite** is an institutional-grade quantitative momentum oscillator comprising two highly advanced indicators: `Butterworth_Slope_Pro` (Standard) and `Butterworth_Slope_Pro` (Multi-Timeframe variant).

Traditional momentum oscillators (such as ROC, MACD, or standard Moving Average differences) are heavily distorted by high-frequency market noise, producing jagged, erratic lines that trigger frequent whipsaws.

This suite resolves the noise-latency trade-off by calculating the **first derivative (Slope / Velocity)** of John Ehlers' higher-order **Butterworth Filter**:

$$\text{Slope}_t = \text{Filter}_t - \text{Filter}_{t-1}$$

Unlike other low-pass filters (such as SMA or EMA), the Butterworth Filter is mathematically engineered to have a **maximally flat passband response** with zero ripple and an extremely sharp roll-off. Because it cleanly eliminates high-frequency noise without introducing severe phase distortion (lag) in the passband, its first derivative yields an exceptionally smooth, regular, and harmonic **sine-wave profile**.

By classifying this pristine velocity wave into a symmetrical 5-zone thermal momentum matrix, the suite identifies cyclical turning points, trend exhaustion, and explosive acceleration zones with maximum accuracy and clarity.

---

## 2. Mathematical & Quant Foundations

The indicator calculates the first difference (velocity) of a stateful, recursive 2-pole or 3-pole IIR Butterworth Filter.

### A. Recursive Butterworth Baseline Formulas

On each bar $t$, the decimal price $P_t$ (Standard or Heikin Ashi) is processed through the selected poles configuration:

#### 1. 2-Pole Butterworth Filter

The dampening coefficients are calculated using the critical period ($T$):

$$a = e^{-\frac{\sqrt{2}\pi}{T}}, \quad b = 2a \cos \left(\frac{\sqrt{2}\pi}{T} \right), \quad c_1 = \frac{1 - b + a^2}{4}$$

$$\text{Filter}_t = b \times \text{Filter}_{t-1} - a^2 \times \text{Filter}_{t-2} + c_1 \times (P_t + 2 \times P_{t-1} + P_{t-2})$$

#### 2. 3-Pole Butterworth Filter

The 3-pole configuration offers an even sharper roll-off (vágási meredekség) using three recursive states:

$$a = e^{-\frac{\pi}{T}}, \quad b = 2a \cos \left(\frac{1.738\pi}{T} \right), \quad c = a^2, \quad c_1 = \frac{(1 - b + c)(1 - c)}{8}$$

$$\text{Filter}_t = (b + c) \text{Filter}_{t-1} - (c + bc) \text{Filter}_{t-2} + c^2 \text{Filter}_{t-3} + c_1 (P_t + 3 P_{t-1} + 3 P_{t-2} + P_{t-3})$$

### B. Symmetrical 5-Zone Momentum Classification

The derivative $\text{Slope}_t = \text{Filter}_t - \text{Filter}_{t-1}$ is evaluated against a user-defined noise threshold ($\epsilon$):

| Color Index | Momentum State | Mathematical Condition | Visual Representation |
| :---: | :--- | :--- | :--- |
| **`0.0`** | **Neutral / Noise** | $\text{Slope}_t \le \epsilon$ | **`clrGray`** (Flat, consolidation phase) |
| **`1.0`** | **Strong Bullish Acceleration** | $\text{Slope}_t > \epsilon \quad \text{AND} \quad \text{Slope}_t > \text{Slope}_{t-1}$ | **`clrMediumSeaGreen`** (Accelerating uptrend) |
| **`2.0`** | **Weak Bullish Deceleration** | $\text{Slope}_t > \epsilon \quad \text{AND} \quad \text{Slope}_t \le \text{Slope}_{t-1}$ | **`clrPaleGreen`** (Uptrend is slowing down) |
| **`3.0`** | **Strong Bearish Acceleration** | $\text{Slope}_t < -\epsilon \quad \text{AND} \quad \text{Slope}_t < \text{Slope}_{t-1}$ | **`clrCrimson`** (Accelerating downtrend) |
| **`4.0`** | **Weak Bearish Deceleration** | $\text{Slope}_t < -\epsilon \quad \text{AND} \quad \text{Slope}_t \ge \text{Slope}_{t-1}$ | **`clrLightCoral`** (Downtrend is slowing down) |

---

## 3. Recommended Calibration Presets

| Asset Class | Timeframe | Poles Selection | Period ($T$) | Threshold ($\epsilon$) | Quant Tactical Objective |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Major FX Pairs** | M15 / H1 | `POLES_TWO` | `20` | `0.00005` | **Intraday Cycle Pivot.** Captures clean swing highs and lows with standard transaction efficiency. |
| **Equity Indices** | H1 / H4 | `POLES_THREE` | `15` | `0.15000` | **Momentum Expansion.** Sharp roll-off is ideal for breakout trading. Bypasses pre-market noise. |
| **Cryptocurrencies** | H4 / Daily | `POLES_THREE` | `25` | `2.50000` | **Macro Trend Filter.** Filters extreme retail volatility, exposing institutional trend waves. |

---

## 4. Visual & Technical Highlights

* **Perfect Harmonic Symmetry:**
  Because the Butterworth filter has zero passband ripple, its derivative forms near-perfectly symmetrical, regular sine waves. This visual regularity makes it an outstanding tool for cyclical peak/trough detection.
* **Double-Smoothed VWMA Signal Line:**
  When configured to VWMA, the indicator converts the platform volume arrays to a `double` cache array, applying volume weighting to the Signal MA. This ensures crossovers are backed by institutional transaction volume.
* **Chronological Safety Guards:**
  The engine enforces chronological array indexing (`ArraySetAsSeries(..., false)`) across all internal persistent buffers, preventing index corruption during template switches.

---

## 5. Advanced MQL5 MTF Implementation Details

Running higher-order recursive filters like the Butterworth 3-pole across multiple timeframes requires robust engineering:

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

Since the Butterworth Filter relies on deep historical states ($\text{Filter}_{t-1}, \text{Filter}_{t-2}, \text{Filter}_{t-3}$), calling calculations continuously on the live forming bar on every tick can cause feedback decay. To solve this, the MTF engine uses **State Mocking** during live ticks by passing `prev_calculated = g_htf_count`, which updates only the active live register while keeping historical closed states completely locked.

---

## 6. Quantitative Trading Strategies

### A. The Symmetrical Cycle Pivot Strategy (0-Line Reversal)

Because the Butterworth Slope forms highly regular, harmonic cycles, the zero-line crossover represents a very high probability trend reversal pivot.

1. **Strategy Setup:**
   * **Butterworth Slope Pro:** Period = `20`, Poles = `POLES_THREE`, Threshold = `0.00005`.
   * **Signal Line:** Disabled.
2. **Execution Rules:**
   * **BUY Trigger:** Enter Long when the histogram crosses **above the zero line** (transitioning from Crimson/LightCoral to MediumSeaGreen).
   * **SELL Trigger:** Enter Short when the histogram crosses **below the zero line** (transitioning from MediumSeaGreen/PaleGreen to Crimson).
3. **Strategic Advantage:** Ehlers' 3-pole Butterworth Filter has an extremely sharp cut-off, meaning that the zero-line crossover reacts precisely at the cycle valleys and peaks with minimal lag compared to traditional MACD crossovers.

```text
       [ Bearish Slope (Crimson) ]  ==> [ ZERO CROSS ] ==> [ Bullish Slope (Green) ]
       (Cyclical Cycle Valley)                             (BUY ENTRY TRIGGERED)
```

### B. The 2/3 Pole Phase-Crossover Strategy (Lead-Lag Crossover)

By combining a fast 2-pole Butterworth Slope (higher sensitivity, leading) and a smooth 3-pole Butterworth Slope (higher smoothing, lagging), we create a highly responsive phase crossover system.

1. **Strategy Setup:**
   * On the same separate window, load two instances of `Butterworth_Slope_Pro`:
     * **Fast Slope:** Period = `15`, Poles = `POLES_TWO` (plotted in clrDodgerBlue).
     * **Slow Slope:** Period = `20`, Poles = `POLES_THREE` (plotted in clrMaroon).
2. **Execution Rules:**
   * **BUY Entry:** Enter Long when the **Fast Slope line crosses above the Slow Slope line** from below.
   * **SELL Entry:** Enter Short when the **Fast Slope line crosses below the Slow Slope line** from above.
3. **Strategic Advantage:** Because both lines utilize maximally flat Butterworth filtering, the crossover is incredibly clean with zero whipsaws in range-bound markets, allowing the trader to capture early trend-expansions with absolute precision.
