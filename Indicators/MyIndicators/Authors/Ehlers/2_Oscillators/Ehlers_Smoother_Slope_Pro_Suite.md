# John Ehlers' Ehlers Smoother Slope Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Ehlers Smoother Slope Pro Suite** is an institutional-grade, low-latency trend-velocity and cycle-reversal tracking engine. It comprises two highly advanced indicators: `Ehlers_Smoother_Slope_Pro` (Standard) and `Ehlers_Smoother_Slope_Pro` (Multi-Timeframe variant).

Traditional momentum oscillators (such as ROC, MACD, or standard moving average differences) are heavily distorted by high-frequency market noise, producing jagged, erratic lines that trigger frequent whipsaws.

This suite resolves the noise-latency trade-off by calculating the **first derivative (Slope / Velocity)** of John Ehlers' highly optimized **SuperSmoother** and **UltimateSmoother** filters:

$$\text{Slope}_t = \text{Filter}_t - \text{Filter}_{t-1}$$

Unlike other moving averages, Ehlers' smoothers are mathematically engineered using 2-pole Butterworth topologies with custom coefficients designed to:

* **SuperSmoother:** Completely eliminate overshoot (ringing) following sudden price shocks.
* **UltimateSmoother:** Achieve near-zero phase delay in the trend direction by combining low-pass and high-pass transfer functions.

Taking the first difference of these pristine baselines yields an exceptionally clean, responsive, and fourier-stable **sine-wave profile**. By classifying this velocity wave into a symmetrical 5-zone thermal momentum matrix, the suite identifies trend exhaustion and trend acceleration zones with maximum accuracy and minimal lag.

---

## 2. Mathematical & Quant Foundations

The indicator calculates the first difference (velocity) of a stateful, recursive SuperSmoother or UltimateSmoother filter.

### A. Recursive Smoothers Baseline Formulas

On each bar $t$, the decimal price $P_t$ (Standard or Heikin Ashi) is processed through the selected smoother configuration. The baseline coefficients are calculated using the smoothing period ($T$):

$$a_1 = e^{-\frac{\sqrt{2}\pi}{T}}, \quad b_1 = 2a_1 \cos \left(\frac{\sqrt{2}\pi}{T} \right), \quad c_2 = b_1, \quad c_3 = -a_1^2$$

#### 1. SuperSmoother Filter

The coefficient $c_1$ is calculated to ensure a flat passband response:

$$c_1 = 1.0 - c_2 - c_3$$

$$\text{Filter}_t = c_1 \times \frac{P_t + P_{t-1}}{2} + c_2 \times \text{Filter}_{t-1} + c_3 \times \text{Filter}_{t-2}$$

#### 2. UltimateSmoother Filter

The coefficient $c_1$ is adjusted to incorporate high-pass characteristics for zero-lag tracking:

$$c_1 = \frac{1.0 + c_2 - c_3}{4}$$

$$\text{Filter}_t = (1.0 - c_1) P_t + (2.0 c_1 - c_2) P_{t-1} - (c_1 + c_3) P_{t-2} + c_2 \text{Filter}_{t-1} + c_3 \text{Filter}_{t-2}$$

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

| Asset Class | Timeframe | Smoother Type | Period ($T$) | Threshold ($\epsilon$) | Quant Tactical Objective |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Major FX Pairs** | M15 / H1 | `SUPERSMOOTHER` | `20` | `0.00005` | **Intraday Cycle Pivot.** Captures clean swing highs and lows with zero overshoot. |
| **Equity Indices** | H1 / H4 | `ULTIMATESMOOTHER` | `15` | `0.15000` | **Zero-Lag Breakout.** Sharp reaction to trend pivots. Perfect for trading index opens. |
| **Cryptocurrencies** | H4 / Daily | `SUPERSMOOTHER` | `25` | `2.50000` | **Macro Trend Filter.** Filters extreme retail volatility, exposing institutional trend waves. |

---

## 4. Visual & Technical Highlights

* **Perfect Harmonic Symmetry:**
  Because Ehlers' smoothers completely eliminate high-frequency chatter and overshoot, their derivative forms near-perfectly symmetrical, regular sine waves. This visual regularity makes it an outstanding tool for cyclical peak/trough detection.
* **Double-Smoothed VWMA Signal Line:**
  When configured to VWMA, the indicator converts the platform volume arrays to a `double` cache array, applying volume weighting to the Signal MA. This ensures crossovers are backed by institutional transaction volume.
* **Chronological Safety Guards:**
  The engine enforces chronological array indexing (`ArraySetAsSeries(..., false)`) across all internal persistent buffers, preventing index corruption during template switches.

---

## 5. Advanced MQL5 MTF Implementation Details

Running higher-order recursive filters like the SuperSmoother across multiple timeframes requires robust engineering:

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

### A. The Symmetrical Cycle Pivot Strategy (0-Line Reversal)

Because the Smoother Slope forms highly regular, harmonic cycles, the zero-line crossover represents a very high probability trend reversal pivot.

1. **Strategy Setup:**
   * **Ehlers Smoother Slope Pro:** Period = `20`, Type = `ULTIMATESMOOTHER`, Threshold = `0.00005`.
   * **Signal Line:** Disabled.
2. **Execution Rules:**
   * **BUY Trigger:** Enter Long when the histogram crosses **above the zero line** (transitioning from Crimson/LightCoral to MediumSeaGreen).
   * **SELL Trigger:** Enter Short when the histogram crosses **below the zero line** (transitioning from MediumSeaGreen/PaleGreen to Crimson).
3. **Strategic Advantage:** Ehlers' UltimateSmoother has near-zero phase delay in the trend direction, meaning that the zero-line crossover reacts precisely at the cycle valleys and peaks with minimal lag compared to traditional MACD crossovers.

```text
       [ Bearish Slope (Crimson) ]  ==> [ ZERO CROSS ] ==> [ Bullish Slope (Green) ]
       (Cyclical Cycle Valley)                             (BUY ENTRY TRIGGERED)
```

### B. The Volume-Weighted Deceleration Pullback Strategy (VWMA + Slope)

This strategy is based on entering ongoing trends during brief corrective pullbacks, confirmed by volume-weighted smoothing to prevent buying into a true reversal.

1. **Strategy Setup:**
   * **Ehlers Smoother Slope Pro:** Period = `20`, Type = `SUPERSMOOTHER`, Threshold = `0.00005`.
   * **Signal MA:** Enabled, Period = `5`, Type = `VWMA`.
2. **Execution Rules:**
   * **BUY Entry (Trend Pullback):** In a confirmed bullish macro trend (histogram bars are mostly positive and above the zero line):
     * Wait for a corrective pullback where the histogram bars drop and cross **below the VWMA Signal Line**.
     * **Trigger:** Enter Long on the first bar where the histogram crosses **back above the VWMA Signal Line** from below.
   * **SELL Entry (Trend Pullback):** In a confirmed bearish macro trend (histogram bars are mostly negative and below the zero line):
     * Wait for a corrective pullback where the histogram bars rise and cross **above the VWMA Signal Line**.
     * **Trigger:** Enter Short on the first bar where the histogram crosses **back below the VWMA Signal Line** from above.
3. **Strategic Advantage:** The VWMA smoothing ensures that the reentry trigger is backed by institutional volume, confirming that the pullback has exhausted and the trend is resuming.
