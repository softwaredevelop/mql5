# John Ehlers' Butterworth Bands Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Butterworth Bands Pro Suite** is an institutional-grade volatility corridor and statistical cycle-bounding trading suite comprising two advanced indicators:

* `Butterworth_Bands_Pro` (Standard)
* `Butterworth_Bands_MTF_Pro` (Multi-Timeframe)

The suite represents a modernized, low-latency adaptation of the classic **Bollinger Bands®**. Standard Bollinger Bands employ a Simple Moving Average (SMA) as their centerline. During explosive trend expansions, time-based centerlines suffer from significant phase delay, causing the bands to warp or generating premature counter-trend crossovers during strong trend expansions.

The Butterworth Bands Pro Suite resolves this bottleneck by employing **John F. Ehlers' Butterworth Filter** (supporting 2-pole and 3-pole transfer functions) as its dynamic centerline baseline ($\mu_B$).

By utilizing a fourier-aligned, maximally flat IIR filter centerline, the channel is immune to low-frequency market noise during choppy consolidations, yet reacts instantly to trend shifts and explosive breakouts. The standard deviation ($\sigma_B$) is calculated dynamically relative to this Butterworth Filter centerline ($\mu_B$), establishing an ultra-responsive, statistically robust price channel that contracts during low volatility consolidations (Squeezes) and expands during trend breakouts with significantly less lag than standard Bollinger Bands.

The suite features dynamic Heikin Ashi price integration, three-decimal Gamma formatting to support precise **Fibonacci ratios**, and advanced multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The calculation pipeline consists of three cascading mathematical steps, calculated recursively on every bar:

### A. Dynamic Centerline (John Ehlers' Butterworth Filter $\mu_B$)

At each bar $t$, the price $P_t$ (Standard or Heikin Ashi) is mapped recursively into a stateful, high-order Butterworth Filter using the selected cutoff period $P$ (`InpButterPeriod`):

* **Two-Pole Butterworth Filter (POLES_TWO):**
  $$a = exp(-\sqrt{2}\pi / P)$$
  $$b = 2 \times a \times \cos\left(\frac{\sqrt{2}\pi}{P}\right)$$
  $$c_1 = \frac{1.0 - b + a^2}{4.0}$$
  $$\mu_{B, t} = b \times \mu_{B, t-1} - a^2 \times \mu_{B, t-2} + c_1 \times (P_t + 2 \times P_{t-1} + P_{t-2})$$

* **Three-Pole Butterworth Filter (POLES_THREE):**
  $$a = exp(-\pi / P)$$
  $$b = 2 \times a \times \cos\left(\frac{1.738\pi}{P}\right)$$
  $$c = a^2$$
  $$c_1 = \frac{(1.0 - b + c) \times (1.0 - c)}{8.0}$$
  $$\mu_{B, t} = (b + c) \mu_{B, t-1} - (c + b \times c) \mu_{B, t-2} + c^2 \mu_{B, t-3} + c_1 \times (P_t + 3 \times P_{t-1} + 3 \times P_{t-2} + P_{t-3})$$

### B. Standard Deviation ($\sigma_B$)

Instead of calculating price dispersion around a static mean, the Butterworth Bands calculate the standard deviation ($\sigma_B$) of the absolute distance between the price ($P$) and the responsive Butterworth centerline ($\mu_B$) over the rolling window of size $N$ (`InpPeriod`):

$$\sigma_{B, t} = \sqrt{\frac{1}{N} \sum_{k=0}^{N-1} (P_{t-k} - \mu_{B, t})^2}$$

### C. Dynamic Volatility Band Boundaries

The upper and lower volatility boundaries are projected around the Butterworth Filter centerline $\mu_{B, t}$ by multiplying the computed $\sigma_{B, t}$ by the user-defined multiplier $d$ (`InpDeviation`):

$$\text{Upper Band}_t = \mu_{B, t} + (d \times \sigma_{B, t})$$

$$\text{Lower Band}_t = \mu_{B, t} - (d \times \sigma_{B, t})$$

---

## 3. High-Performance & Precision Enhancements

The suite is engineered to meet the highest execution and stability standards:

* **Strict Chronological Sorting Safeguards:**
  To prevent calculation corruption caused by reverse-chronological array states (often forced by custom templates or third-party indicators on the active chart), the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`. This is also applied inside the dynamic buffer resizes (`m_price[]`, `m_ha_open[]`, etc.) within the calculator engine classes.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations (such as access violation fatal crashes), a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Advanced MQL5 MTF Implementation Details

`Butterworth_Bands_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

### A. Forming LTF Block Flat-Force (The Warping Solution)

To prevent real-time step warping and slope distortion on lower timeframe charts, the indicator implements a step-blocking algorithm. On every tick, the indicator isolates the beginning of the active forming HTF block and forces the calculations to rewrite that block completely, keeping the visual lines perfectly flat and historically stable:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Dynamic anchor start of current forming block

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

### B. State Mocking for IIR State Stability

Since the Butterworth Filter equations inside the calculator are highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states ($F_{t-1}, F_{t-2}, F_{t-3}$). To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

### C. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 5. Parameters

### A. Butterworth Settings

* **Filter Period (`InpButterPeriod`):** The Butterworth centerline cutoff period ($P$). Larger periods increase smoothing; smaller periods increase responsiveness (Default: `20`, Range: $\ge 2$).
* **Number of Poles (`InpPoles`):** Selects between a 2-pole (`POLES_TWO = 2`) or 3-pole (`POLES_THREE = 3`) IIR transfer function. Default: `POLES_TWO`.
* **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Bands (StdDev) Settings

* **StdDev Period (`InpPeriod`):** The lookback period ($N$) used strictly to calculate standard deviation around the Butterworth centerline (Default: `20`).
* **Deviation Multiplier (`InpDeviation`):** The multiplier ($d$) for standard deviation, setting the band width (Default: `2.0`).

### C. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate corridors on (Default: `PERIOD_H1`).

---

## 6. Quantitative Trading Strategies

### A. The "Butterworth Bollinger Squeeze" Breakout

The Butterworth centerline tracks price with significantly less lag than a standard Bollinger centerline (SMA). Consequently, when a market consolidates, the Butterworth Bands contract into a "Squeeze" faster and more tightly:

1. Wait for the Upper and Lower bands to contract to historically narrow levels, indicating low volatility and institutional positioning.
2. Observe price action relative to the centerline.
3. **Bullish Breakout (BUY):** If a candle closes completely above the Upper Band while the bands expand, execute long positions.
4. **Bearish Breakout (SELL):** If a candle closes completely below the Lower Band while the bands expand, execute short positions.

### B. Dynamic Low-Lag Trend Riding (Rejections)

During strong trends, price fluctuates but tends to respect the centerline as a value anchor. Since the Butterworth filter is highly responsive and smooth, it acts as an excellent dynamic pivot line.

* **Bullish Regime:** If the price is consistently trading between the Centerline and the Upper Band, a strong uptrend is active. Seek long continuation setups whenever the price pulls back and tests the Centerline (which acts as dynamic support).
* **Bearish Regime:** If the price is trading between the Centerline and the Lower Band, a strong downtrend is active. Seek short continuation setups when the price rallies to test the Centerline (dynamic resistance).
