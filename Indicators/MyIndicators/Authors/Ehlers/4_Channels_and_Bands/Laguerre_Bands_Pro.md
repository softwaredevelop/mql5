# Laguerre Bands Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Laguerre Bands Pro Suite** is a sophisticated quantitative volatility corridor suite comprising two advanced indicators: `Laguerre_Bands_Pro` (Standard) and `Laguerre_Bands_MTF_Pro` (Multi-Timeframe).

Traditional Bollinger Bands® employ a Simple Moving Average (SMA) as their centerline. While mathematically sound, standard moving averages carry significant phase lag, making the resulting bands slow to respond to rapid volatility expansion and contraction. The Laguerre Bands Pro Suite resolves this latency by utilizing **John Ehlers' Laguerre Filter** as its dynamic center line.

By mapping price coordinates into a stateful, low-latency Laguerre polynomial space, the suite establishes an ultra-responsive dynamic centerline ($\mu_L$). It then calculates the population standard deviation ($\sigma_L$) of prices directly around this Laguerre baseline. The result is a highly adaptive volatility channel that contracts during consolidation (Squeezes) and expands during breakouts with significantly less lag than standard Bollinger Bands.

The suite features dynamic Heikin Ashi price integration, three-decimal Gamma formatting to support precise **Fibonacci ratios** (such as `0.236`, `0.382`, and `0.618`), and state-safe multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The statistical calculation of the Laguerre Bands operates in two distinct phases: cycle-isolated filtering and standard deviation normalization over a rolling lookback window of size $N$ (`InpPeriod`):

### A. Dynamic Centerline (John Ehlers' Laguerre Filter $\mu_L$)

At each bar $t$, the price is mapped recursively into a four-dimensional Laguerre space. The dynamic centerline is calculated as a weighted Finite Impulse Response (FIR) combination of the four state registers ($L_0$ to $L_3$), controlled by the dampening coefficient $\gamma$ (`InpGamma`):

$$L_{0, t} = (1 - \gamma) P_t + \gamma L_{0, t-1}$$

$$L_{1, t} = -\gamma L_{0, t} + L_{0, t-1} + \gamma L_{1, t-1}$$

$$L_{2, t} = -\gamma L_{1, t} + L_{1, t-1} + \gamma L_{2, t-1}$$

$$L_{3, t} = -\gamma L_{2, t} + L_{2, t-1} + \gamma L_{3, t-1}$$

$$\mu_{L, t} = \frac{L_{0, t} + 2 \times L_{1, t} + 2 \times L_{2, t} + L_{3, t}}{6}$$

### B. Dynamic Standard Deviation ($\sigma_L$)

Unlike standard Bollinger Bands which calculate variance relative to a slow SMA, the Laguerre Bands calculate standard deviation relative to the responsive Laguerre Filter centerline ($\mu_L$) over the rolling window $N$:

$$\sigma_{L, t} = \sqrt{\frac{1}{N} \sum_{k=0}^{N-1} (P_{t-k} - \mu_{L, t})^2}$$

### C. Volatility Band Boundaries

The upper and lower volatility boundaries are plotted by multiplying the standard deviation $\sigma_{L, t}$ by the user-defined deviation multiplier $D$ (`InpDeviation`) and projecting the corridors around the centerline:

$$\text{Upper Band}_t = \mu_{L, t} + (D \times \sigma_{L, t})$$

$$\text{Lower Band}_t = \mu_{L, t} - (D \times \sigma_{L, t})$$

---

## 3. High-Performance & Precision Enhancements

To meet institutional trading standards, the suite incorporates several advanced MQL5 architectural design patterns:

* **Three-Decimal Gamma Precision:**
  To natively support precise Fibonacci ratios (such as `0.236` and `0.382`) without visual rounding, the indicator formatting is expanded to three decimal places. The dynamic ShortName in `OnInit()` uses a `%.3f` formatting mask:

  ```mql5
  IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre Bands(%.3f, %d, %.1f)", InpGamma, InpPeriod, InpDeviation));
  ```

  This ensures that critical Fibonacci settings are clearly documented on the chart subwindow and inside the terminal legend.

* **Strict Chronological Sorting Safeguards:**
  To prevent calculation corruption caused by reverse-chronological array states (often forced by custom templates or third-party indicators on the chart), the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) at the beginning of `OnCalculate()`. This is also applied inside the `PreparePriceSeries` dynamic buffer resizes inside the `CLaguerreBandsCalculator` class.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations (such as access violation crashes), a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Multi-Timeframe (MTF) Implementation Details

`Laguerre_Bands_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

### A. Forming LTF Block Flat-Force (The Warping Solution)

To prevent real-time step warping and slope distortion on lower timeframe charts, the indicator implements a step-blocking algorithm. On every tick, the indicator isolates the beginning of the active forming HTF block and forces the calculations to rewrite that block completely, keeping the visual lines perfectly flat and historically stable:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Dynamic anchor start

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

### B. State Mocking for IIR State Stability

Since the Laguerre Filter is highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states ($L_0$ to $L_3$). To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 5. Parameters

### A. Laguerre Centerline Settings

* **Gamma Factor (`InpGamma`):** The smoothing coefficient ($\gamma$) that determines baseline speed. Lower values (e.g., `0.500`) increase responsiveness; higher values (e.g., `0.850`) increase smoothing (Default: `0.700`, Fibonacci Recommendations: `0.236`, `0.382`, `0.618`).
* **Source Price (`InpSourcePrice`):** Selects the pricing input, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Bands Volatility Settings

* **StdDev Period (`InpPeriod`):** The lookback period ($N$) used strictly to calculate standard deviation around the Laguerre centerline (Default: `20`).
* **Deviation Multiplier (`InpDeviation`):** The multiplier ($D$) for standard deviation, setting the band width (Default: `2.0`).

### C. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate Laguerre Bands on (Default: `PERIOD_H1`).

---

## 6. Strategic Quantitative Usage

### A. The "Laguerre Squeeze" Breakout

The Laguerre centerline tracks price with significantly less lag than a standard Bollinger centerline (SMA). Consequently, when a market consolidates, the Laguerre Bands contract into a "Squeeze" faster and more tightly:

1. Wait for the Upper and Lower bands to contract to historically narrow levels, indicating low volatility and institutional positioning.
2. Observe price action relative to the centerline.
3. **Bullish Breakout (BUY):** If a candle closes completely above the Upper Band while the bands expand, execute long positions.
4. **Bearish Breakout (SELL):** If a candle closes completely below the Lower Band while the bands expand, execute short positions.

### B. Dynamic Low-Lag Trend Riding

Because Ehlers' Laguerre filter centerline tracks the trend closely, it acts as an exceptionally reliable dynamic trailing support and resistance barrier:

* **Bullish Regime:** If the price is consistently trading between the Centerline and the Upper Band, a strong uptrend is active. Seek long continuation setups whenever the price pulls back and tests the Centerline (which acts as dynamic support).
* **Bearish Regime:** If the price is trading between the Centerline and the Lower Band, a strong downtrend is active. Seek short continuation setups when the price rallies to test the Centerline (dynamic resistance).
