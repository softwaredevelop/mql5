# John Ehlers' Butterworth Filter Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Butterworth Filter Pro Suite** is an institutional-grade, low-latency trend-following and noise-filtering suite comprising two advanced indicators:

* `Butterworth_Filter_Pro` (Standard)
* `Butterworth_Filter_MTF_Pro` (Multi-Timeframe)

Developed by the legendary quantitative analyst John F. Ehlers, the Butterworth Filter is an advanced Infinite Impulse Response (IIR) low-pass filter mapped from analog electronic filter networks to the digital domain using the bilinear transform. Unlike standard moving averages (SMA, EMA) which attenuate all frequencies linearly and introduce significant lag, Ehlers' Butterworth Filter is mathematically optimized to achieve a **maximally flat frequency response in the pass-band** with an exceptionally sharp fourier-level cut-off.

By configuring the filter to run with either **two poles (2nd-order)** or **three poles (3rd-order)**, traders can isolate the core cyclical trends of price action with near-zero phase lag, completely filtering out high-frequency market noise and price whipsaws.

The suite features dynamic Heikin Ashi price integration, high-resolution decimal precision, and state-safe multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The Butterworth Filter is calculated recursively. Its smoothing and dampening characteristics are mathematically derived from trigonometric relations based on the user-selected critical period $P$ (`InpPeriod`):

### A. Two-Pole Butterworth Filter (POLES_TWO)

The 2nd-order Butterworth Filter applies a transfer function utilizing a 3-bar pricing FIR component combined with the prior two historical feedback states of the filter itself ($F_{t-1}, F_{t-2}$):

$$a = e^{-\sqrt{2}\pi / P}$$

$$b = 2 \times a \times \cos\left(\frac{\sqrt{2}\pi}{P}\right)$$

$$c_1 = \frac{1.0 - b + a^2}{4.0}$$

$$F_t = b \times F_{t-1} - a^2 \times F_{t-2} + c_1 \times (P_t + 2 \times P_{t-1} + P_{t-2})$$

### B. Three-Pole Butterworth Filter (POLES_THREE)

The 3rd-order Butterworth Filter applies a highly complex transfer function incorporating a four-bar pricing FIR component combined with the prior three feedback filter states ($F_{t-1}, F_{t-2}, F_{t-3}$), achieving an incredibly sharp, step-like frequency cut-off:

$$a = e^{-\pi / P}$$

$$b = 2 \times a \times \cos\left(\frac{1.738\pi}{P}\right)$$

$$c = a^2$$

$$c_1 = \frac{(1.0 - b + c) \times (1.0 - c)}{8.0}$$

$$F_t = (b + c) \times F_{t-1} - (c + b \times c) \times F_{t-2} + c^2 \times F_{t-3} + c_1 \times (P_t + 3 \times P_{t-1} + 3 \times P_{t-2} + P_{t-3})$$

Where $P_t$ represents the current input price coordinate, and $F_t$ is the final filtered output.

*Note: For the first three bars of history ($t < 3$), the filter output is initialized directly to the raw price source ($F_k = P_k$) to seed the recursive registers.*

---

## 3. High-Performance & Precision Enhancements

The suite is engineered to meet the highest execution and stability standards:

* **Szigorú Chronological Sorting Safeguards:**
  To prevent calculation corruption caused by reverse-chronological array states (often forced by custom templates or third-party indicators on the active chart), the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`. This is also applied inside the dynamic buffer resizes (`m_price[]`, `m_ha_open[]`, etc.) within the calculator engine classes.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations (such as access violation fatal crashes), a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Advanced MQL5 MTF Implementation Details

`Butterworth_Filter_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

Since the Butterworth Filter equations are highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states ($F_{t-1}, F_{t-2}, F_{t-3}$). To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

### C. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 5. Parameters

### A. Butterworth Settings

* **Critical Period (`InpPeriod`):** The filter's cutoff period ($P$). Larger periods increase smoothing and decay; smaller periods increase responsiveness (Default: `20`, Range: $\ge 2$).
* **Number of Poles (`InpPoles`):** Selects between a 2-pole (`POLES_TWO = 2`) or 3-pole (`POLES_THREE = 3`) IIR transfer function. Default: `POLES_TWO`.
* **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate the smoother on (Default: `PERIOD_H1`).

---

## 6. Quantitative Trading Strategies

### A. The 2-Pole vs. 3-Pole Phase Crossover

By exploiting the different phase-response and frequency roll-off characteristics of 2-pole and 3-pole filters, traders can construct a highly sensitive crossover system that reacts instantly to trend pivots:

1. **Indicator Setup:**
   * **Fast Line (2-Pole):** Set `InpPoles = POLES_TWO`, Period set to **`20`** (represented in clrDodgerBlue).
   * **Slow Line (3-Pole):** Set `InpPoles = POLES_THREE`, Period set to **`20`** (represented in clrCrimson).
2. **Crossover Dynamics:**
   Because the 3-pole filter has a sharper frequency roll-off, it exhibits slightly more phase lag than the 2-pole filter of the identical period. The 2-pole line acts as a fast momentum trigger, while the 3-pole line acts as a smooth trend anchor.
3. **Execution Trigger:**
   * **BUY Entry:** Enter Long when the Fast Line (2-pole) crosses above the Slow Line (3-pole) from below. Place stop-loss strictly below the local swing low.
   * **SELL Entry:** Enter Short when the Fast Line crosses below the Slow Line from above.
4. **Exit:** Close the position immediately when the fast line crosses back over the slow line, locking in low-lag trend profits.

### B. Low-Lag Dynamic Price rejection (Ultimate Support)

Because Ehlers' Butterworth Filter is mathematically flat in the passband, it represents a highly accurate, clean "fair value" line during established trends.

1. **Indicator Setup:**
   * Apply `Butterworth_Filter_Pro` configured to `POLES_THREE` with a period of **`20`**.
2. **The Trend Alignment:**
   * **Bullish Trend:** Price trades consistently above the 3-pole Butterworth line.
   * **Bearish Trend:** Price trades consistently below the 3-pole Butterworth line.
3. **Execution:**
   * In a Bullish Trend, wait for the price to pull back and test the 3-pole line.
   * **BUY Trigger:** Enter Long as soon as a bullish reversal candle (e.g. hammer or bullish engulfing) closes back above the Butterworth line. Place stop-loss strictly below the test candle's low.
   * In a Bearish Trend, wait for a rally to test the line. Enter Short once a bearish rejection candle closes back below the line.
