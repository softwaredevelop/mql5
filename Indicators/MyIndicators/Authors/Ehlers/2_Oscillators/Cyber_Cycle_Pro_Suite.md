# Cyber Cycle Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Cyber Cycle Pro Suite** is an institutional-grade cycle-isolation and trading suite comprising two advanced indicators: `Cyber_Cycle_Pro` (Standard) and `Cyber_Cycle_MTF_Pro` (Multi-Timeframe).

Developed by the legendary quantitative analyst John F. Ehlers, the Cyber Cycle is designed to isolate the short-term, high-probability cyclical waves of price action while filtering out trend drag and high-frequency noise. Unlike standard retail momentum oscillators (such as RSI or Stochastics) which suffer from saturation and scale compression during strong trends, the Cyber Cycle acts as an adaptive **two-pole Butterworth band-pass filter**.

The output is a highly responsive, zero-mean, sine-wave-like oscillator whose amplitude and crossovers reveal the underlying "heartbeat" or rhythmic cycle of financial assets.

The suite features dynamic Heikin Ashi price integration, a highly flexible Signal Line engine supporting standard moving averages and **Volume-Weighted Moving Averages (VWMA)**, and state-safe multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

With version 3.21, the visual formatting and precision pipelines are dynamically coupled with native symbol digits, allowing accurate sub-pip resolution tracking on major currency pairs, metals, and index contracts.

---

## 2. Mathematical Foundations

The Cyber Cycle operates by preparing price data, smoothing it via a low-pass Finite Impulse Response (FIR) filter, and then applying a recursive infinite impulse response (IIR) transfer function to isolate cyclical components.

The calculation sequence operates on price coordinates $P_t$ (Standard or Heikin Ashi) using a smoothing factor $\alpha$ (`InpAlpha`, Ehlers' recommended default: `0.07`):

### A. Pre-Smoothing (4-Bar FIR Filter)

To eliminate high-frequency noise before cycle extraction, the source price is passed through a symmetrical 4-bar Finite Impulse Response filter:

$$\text{Smooth}_t = \frac{P_t + 2 \times P_{t-1} + 2 \times P_{t-2} + P_{t-3}}{6}$$

### B. Two-Pole Butterworth Cycle Calculation

The core Cycle line is computed recursively. It utilizes the current and past pre-smoothed values combined with the prior two historical states of the cycle line itself to maintain fourier-aligned phase consistency:

$$\text{Cycle}_t = \left(1 - \frac{\alpha}{2}\right)^2 (\text{Smooth}_t - 2\text{Smooth}_{t-1} + \text{Smooth}_{t-2}) + 2(1-\alpha)\text{Cycle}_{t-1} - (1-\alpha)^2\text{Cycle}_{t-2}$$

*Note: For the first 6 bars of history ($t < 6$), the states are initialized directly to the raw price source, and the cycle output is forced to $0.0$ to purge random memory noise.*

### C. Signal Line Generation

To confirm turning points, the suite features a highly customizable secondary Signal Line. It can be configured in two distinct modes:

* **Classic Ehlers Delay (`SIGNAL_DELAY_1BAR`):**
  Introduces a pure 1-bar delay, acting as the fastest possible trigger line:
  $$\text{Signal}_t = \text{Cycle}_{t-1}$$

* **Smoothing Average (`SIGNAL_MA`):**
  Applies any selected moving average type over the Cycle line. If **`VWMA`** is selected, the signal line is calculated dynamically using the corresponding volume array (Tick or Real Volume) to weight cycle momentum:
  $$\text{Signal}_t = \frac{\sum_{k=0}^{P-1} \text{Cycle}_{t-k} \times \text{Volume}_{t-k}}{\sum_{k=0}^{P-1} \text{Volume}_{t-k}}$$

### D. Pip-Scale Amplitude and Precision Safety (The Acceleration Scale)

Because the Cyber Cycle operates on the second difference (acceleration) of pre-smoothed prices, its output amplitude is directly proportional to the price volatility and the pip-scale of the selected asset.

For major currency pairs (such as EURUSD, where price resides around $1.13900$), price fluctuations and momentum shifts are represented in fractions of a pip. Consequently, the second difference:
$$\Delta^2 = \text{Smooth}_t - 2\text{Smooth}_{t-1} + \text{Smooth}_{t-2}$$
is mathematically compressed to extremely small decimals, typically resulting in cycle amplitudes ranging between **$-0.00150$ and $+0.00150$** (e.g., values like `0.00076` or `-0.00088` on M15 charts).

To prevent these vital high-resolution cycles from being rounded down to a flat `0.00` in the Data Window, separate window scale, or chart legend, the visual metadata formatting dynamically overrides default rounding by coupling with the symbol's native digits:
$$\text{Indicator Digits} = \text{Symbol Digits} \quad (\text{e.g., 5 for EURUSD})$$
This is programmatically executed inside `OnInit()` using:

```mql5
IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
```

This ensures complete analytical transparency, allowing traders to observe precise statistical deviations and crossover behaviors in real-time.

---

## 3. High-Performance Architecture (Direct Close-Buffer Mapping)

Traditional indicator engines often create heavy performance bottlenecks by utilizing nested loops or allocating secondary price arrays to feed auxiliary indicators.

The Cyber Cycle Pro Suite resolves this by utilizing the **Direct Close-Buffer Mapping Pattern**:

* The computed Cyber Cycle values are maintained in a persistent internal class buffer `m_cycle[]`.
* To calculate the moving average signal line, we call the standard `Calculate` method of the embedded `CMovingAverageCalculator`, passing the `m_cycle[]` array for all price parameters (`open`, `high`, `low`, `close` parameters) and specifying `PRICE_CLOSE` as the applied price type:

  ```mql5
  m_signal_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                            m_cycle, m_cycle, m_cycle, m_cycle,
                            volume,
                            signal_out);
  ```

This directs the MA engine to treat `m_cycle` as the pricing close-source. This zero-copy approach natively supports all moving average types (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA) on the Cyber Cycle line with maximum computational efficiency.

---

## 4. Presentation-Safety and History Initialization

To prevent visual spikes, division-by-zero errors, and garbage values in the MetaTrader 5 Data Window on startup, the engine includes a dedicated presentation-safety layer. During the first calculation pass (`prev_calculated == 0`), indices `0` to `5` are explicitly initialized:
$$\text{Smooth}_k = P_k, \quad \text{Cycle}_k = 0.0, \quad \text{Signal}_k = 0.0 \quad \text{for } k \in [0, 5]$$
The visual drawing start is programmatically offset using `PLOT_DRAW_BEGIN` to ensure that only mathematically stabilized bars are visible on the chart.

---

## 5. Advanced MQL5 MTF Implementation Details

### A. Forming LTF Block Flat-Force (The Warping Solution)

`Cyber_Cycle_MTF_Pro` resolves the classic MTF live-bar warping bug by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block. This ensures the entire active HTF block (both Cycle and Signal lines) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Strictly Guarded State Safety on Live Ticks (State Mocking)

Butterworth recursive filters are highly stateful. To support real-time updating without corrupting or double-accumulating historical closed states, the MTF indicators utilize a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator).

This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting, double-accumulating, or corrupting any historical states inside the recursive registers.

### C. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

### D. Chronological Alignment Guard

To prevent data alignment issues and array index corruption under variable client-terminal environment setups, all price arrays, input arrays, and the global cached higher timeframe volume buffer (`h_vol`) are explicitly coerced into standard chronological order using `ArraySetAsSeries(..., false)` prior to calculation.

---

## 6. Parameters

### A. Cyber Cycle Settings

* **Smoothing Factor (`InpAlpha`):** The Butterworth filter coefficient. Smaller values increase smoothing but add minimal lag; larger values increase responsiveness (Default: `0.07`, Recommended: `0.05` to `0.20`).
* **Source Price (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_MEDIAN_STD`).

### B. Signal Line Settings

* **Signal Type (`InpSignalType`):** Selects the trigger line calculation method (`SIGNAL_DELAY_1BAR`, `SIGNAL_MA`). Default: `SIGNAL_DELAY_1BAR`.
* **Signal Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `3`).
* **Signal Method (`InpSignalMethod`):** Select the MA type for the Signal Line (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA). Default: `SMA`.

### C. MTF Specific Parameters (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate the Cyber Cycle on (Default: `PERIOD_H1`).

---

## 7. Advanced Trading Strategies & Algorithmic Integration

### A. Algorithmic Expert Advisor Integration (Zero-Cross Validation)

Because the Cyber Cycle operates on ultra-low-lag decimal boundaries, EAs must perform comparisons with mathematical safety guards to avoid floating-point errors.

* **The Logic:** When evaluating the Cycle crossing the zero line, do not check for absolute equality (`== 0.0`). Instead, implement an epsilon-based zero-cross or a clean directional crossover:

  ```mql5
  double current_cycle  = iCustom(NULL, 0, "Cyber_Cycle_Pro", ..., 0, 0); // Index 0
  double previous_cycle = iCustom(NULL, 0, "Cyber_Cycle_Pro", ..., 0, 1); // Index 1

  // Bullish Zero-Cross confirmation:
  if(previous_cycle < 0.0 && current_cycle > 0.0)
    {
     // Open BUY Order
    }
  ```

This is extremely stable, responsive, and completely unaffected by the small fractional scale of currency instruments.

### B. Volume-Sourced Cycle Reversals (VWMA Signal Crossover)

In cyclical markets, crossovers that occur on high trading volume have a significantly higher probability of indicating true trend reversals.

1. Configure the Signal Line settings to:
   * `InpSignalType = SIGNAL_MA`
   * `InpSignalMethod = VWMA`
   * `InpSignalPeriod = 3` or `4`
2. **Bullish Reversal (BUY):** Wait for the **Cycle line to cross above the VWMA Signal line** from below the zero center line. This confirms that the cyclical turn is backed by institutional buying volume.
3. **Bearish Reversal (SELL):** Wait for the **Cycle line to cross below the VWMA Signal line** from above the zero center line.
4. **Exit:** Close the position when the Cycle line reaches the opposite extreme and begins to contract.

### C. Top-Down Macro Cycle Filter (MTF Strategy)

Because cycle indicators isolate cycles by removing the trend, trading cycle crossovers against a strong macro trend is highly risky.

1. **Macro Cycle Alignment (H1/H4):** Apply `Cyber_Cycle_MTF_Pro` set to H1 or H4 on an M5/M15 execution chart. Configure it with a `VWMA` signal line.
2. **The Trend Filter:** Identify the direction of the macro cycle:
   * If the H1 Cycle line is above its Signal line and rising, the macro cycle is bullish. Only seek buy setups.
   * If the H1 Cycle line is below its Signal line and falling, the macro cycle is bearish. Only seek sell setups.
3. **Execution:** On the local M5 execution chart, apply a fast local cycle indicator. When the macro cycle is bullish, execute **BUY** orders strictly when the local M5 cycle line crosses above its signal line, using the macro cycle alignment to filter out high-frequency false breakouts.
