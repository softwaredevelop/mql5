# John Ehlers' Smoother Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Smoother Pro Suite** is an institutional-grade, low-latency trend-following and noise-filtering suite comprising two advanced indicators:

* `Ehlers_Smoother_Pro` (Standard)
* `Ehlers_Smoother_MTF_Pro` (Multi-Timeframe)

In quantitative trading, classical smoothing methods (such as SMA or EMA) introduce severe phase lag, often rendering trend-following strategies unprofitable due to late trade executions. John F. Ehlers, a pioneer in applying Digital Signal Processing (DSP) to financial markets, resolved this limitation by designing the **SuperSmoother** (2nd-order) and **UltimateSmoother** (3rd-order) Infinite Impulse Response (IIR) filters.

By mapping analog Butterworth and Gaussian filter networks to the digital domain using the bilinear transform, Ehlers' smoothers achieve an exceptionally sharp, fourier-like frequency cut-off. They eliminate high-frequency market noise and price whipsaws while maintaining **near-zero phase lag** relative to the underlying trend cycles.

The suite features dynamic Heikin Ashi price integration, high-resolution decimal precision, and state-safe multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The calculators calculate Ehlers' filters recursively. The dampening characteristics are mathematically derived from trigonometric relations based on the user-selected period $P$ (`InpPeriod`):

### A. Coefficient Calculations

The dynamic decay rate ($a_1$) and trigonometric scaling factors ($b_1, c_2, c_3$) are calculated on startup:

$$a_1 = e^{-\sqrt{2}\pi / P}$$

$$b_1 = 2 \times a_1 \times \cos\left(\frac{\sqrt{2}\pi}{P}\right)$$

$$c_2 = b_1$$

$$c_3 = -a_1^2$$

### B. SuperSmoother Filter Formula (2nd-Order Low-Pass Filter)

The SuperSmoother applies a 2nd-order transfer function, utilizing a 2-bar pricing FIR component combined with the prior two historical states of the filter itself ($F_{t-1}, F_{t-2}$):

$$c_1 = 1.0 - c_2 - c_3$$

$$F_t = c_1 \times \frac{P_t + P_{t-1}}{2} + c_2 \times F_{t-1} + c_3 \times F_{t-2}$$

### C. UltimateSmoother Filter Formula (3rd-Order Low-Pass Filter)

The UltimateSmoother applies a more complex 3rd-order transfer function. It incorporates a three-bar pricing component combined with the prior two feedback filter registers ($F_{t-1}, F_{t-2}$), achieving a significantly sharper frequency cut-off:

$$c_1 = \frac{1.0 + c_2 - c_3}{4.0}$$

$$F_t = (1.0 - c_1) P_t + (2.0 \times c_1 - c_2) P_{t-1} - (c_1 + c_3) P_{t-2} + c_2 \times F_{t-1} + c_3 \times F_{t-2}$$

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

`Ehlers_Smoother_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

Since the SuperSmoother and UltimateSmoother are highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states ($F_{t-1}, F_{t-2}$). To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

### C. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 5. Parameters

### A. Smoother Settings

* **Smoother Type (`InpSmootherType`):** Selects between Ehlers' 2nd-order `SUPERSMOOTHER` or 3rd-order `ULTIMATESMOOTHER`. Default: `SUPERSMOOTHER`.
* **Smoothing Period (`InpPeriod`):** The dampening lookback period ($P$). Larger periods increase smoothing; smaller periods increase responsiveness (Default: `20`, Range: $\ge 2$).
* **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate the smoother on (Default: `PERIOD_H1`).

---

## 6. Quantitative Trading Strategies

### A. Low-Lag Dual-Smoother Golden Cross (The Cycle Crossover)

By combining a fast-reacting UltimateSmoother and a medium-term SuperSmoother, traders establish a trend crossover system with up to 50% less lag than standard EMA crossovers:

1. **Indicator Setup:**
   * **Fast Smoother:** Type set to `ULTIMATESMOOTHER`, Period set to **`10`** (represented in clrDodgerBlue).
   * **Slow Smoother:** Type set to `SUPERSMOOTHER`, Period set to **`30`** (represented in clrCrimson).
2. **Execution Trigger:**
   * **BUY Entry:** Enter Long when the Fast Smoother crosses above the Slow Smoother. Place stop-loss strictly below the local swing low.
   * **SELL Entry:** Enter Short when the Fast Smoother crosses below the Slow Smoother. Place stop-loss strictly above the local swing high.
3. **Exit:** Close positions immediately when the fast smoother crosses back over the slow smoother.

### B. Ultimate Price Pullback Reversals

The UltimateSmoother's 3rd-order transfer function creates a highly defined boundary. Price crossing this line signifies a strong fourier-level cycle shift.

1. **Indicator Setup:**
   * Apply `Ehlers_Smoother_Pro` configured to `ULTIMATESMOOTHER` with a period of **`20`** (the baseline value).
2. **The Trend Alignment:**
   * **Bullish Trend:** Price trades consistently above the UltimateSmoother line.
   * **Bearish Trend:** Price trades consistently below the UltimateSmoother line.
3. **Execution:**
   * In a Bullish Trend, wait for the price to pull back and touch or slightly pierce the UltimateSmoother line.
   * **BUY Trigger:** Enter Long as soon as a candle closes back above the UltimateSmoother line. Place stop-loss strictly below the pullback candle's low.
   * In a Bearish Trend, wait for a rally to test the line. Enter Short once a candle closes back below the line.
