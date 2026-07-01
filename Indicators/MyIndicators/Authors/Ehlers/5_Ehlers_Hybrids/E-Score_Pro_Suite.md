# E-Score Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **E-Score Pro Suite** is an institutional-grade, high-performance statistical arbitrage oscillator comprising two advanced indicators:

* `EScore_Pro` (Standard)
* `EScore_MTF_Pro` (Multi-Timeframe)

The standard Z-Score measures the volatility-adjusted price distance relative to standard moving averages (SMA, EMA). Because standard moving averages carry significant phase lag, standard Z-Scores often remain pinned at overbought or oversold extremes during strong trend expansions, producing premature counter-trend signals.

The E-Score (Ehlers Smoother Z-Score) resolves this limitation by employing **John Ehlers' SuperSmoother** (2nd-order Low-Pass) or **UltimateSmoother** (3rd-order Low-Pass) filters as its dynamic centerline.

By calculating the Root-Mean-Square (RMS) standard deviation of the difference between the price and this low-lag centerline, the E-Score normalizes volatility expansions cleanly. It produces a scale-free, zero-mean, highly defined cycle oscillator.

The suite features dynamic Heikin Ashi price integration, a customizable **5-Zone Swapped Thermal Color Histogram**, a volume-weighted Signal Line, and advanced multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The statistical calculations operate on closing prices $P_t$ (Standard or Heikin Ashi) over an active rolling lookback window of size $N$ (`InpPeriod`):

### A. Dynamic Low-Lag Centerline ($\mu_{E, t}$)

The baseline central curve is represented by the selected Ehlers Smoother type calculated recursively over the lookback window:

$$\mu_{E, t} = \text{EhlersSmoother}(P_t, \text{Type}, N)$$

### B. Smoother Standard Deviation ($\sigma_{E, t}$)

Instead of calculating price dispersion around a static mean, the E-Score calculates the Root-Mean-Square (RMS) standard deviation of the absolute distance between the price ($P$) and the responsive smoother centerline ($\mu_E$) over the rolling window:

$$\text{Difference}_i = P_i - \mu_{E, i}$$

$$\sigma_{E, t} = \sqrt{\frac{1}{N} \sum_{k=0}^{N-1} (P_{t-k} - \mu_{E, t-k})^2}$$

### C. Final Normalized E-Score

The current price distance is divided by the smoother standard deviation to yield the normalized E-Score value in Sigma units:

$$\text{E-Score}_t = \frac{P_t - \mu_{E, t}}{\sigma_{E, t}}$$

To protect the system from division-by-zero exceptions during periods of absolute price consolidation, the calculator incorporates an active protection layer:

$$\text{E-Score}_t = 0.0 \quad \text{if } \sigma_{E, t} \le 1.0 \times 10^{-9}$$

### D. Signal Line Generation

To filter out high-frequency noise and generate crossover triggers, a smoothed Signal Line is calculated directly on top of the E-Score output buffer (`BufferEScore[]`) using the integrated `CMovingAverageCalculator` (supporting standard MAs and volume-weighted **VWMA**):

$$\text{Signal}_t = \text{MA}(\text{E-Score}, \text{SignalPeriod})_t$$

---

## 3. Visual & Architectural Highlights

The suite integrates several advanced MQL5 architectural design patterns:

* **Swapped 5-Zone Thermal Color Histogram:**
  To maintain perfect consistency with Heikin Ashi candle colors and represent progressive momentum build-up, the indicator implements a Swapped Thermal Palette (Blue for Bullish expansion, Red/Coral for Bearish expansion):
  * **$E \ge \text{InpLevelClimaxHigh}$:** `clrDeepSkyBlue` (Bullish Climax / Extreme High)
  * **$E \in [\text{InpLevelFlowHigh}, \text{InpLevelClimaxHigh})$:** `clrLightSkyBlue` (Bullish Flow / Warning High)
  * **$E \in (\text{InpLevelFlowLow}, \text{InpLevelFlowHigh})$:** `clrGray` (Neutral Zone / Random Noise)
  * **$E \in (\text{InpLevelClimaxLow}, \text{InpLevelFlowLow}]$:** `clrCoral` (Bearish Flow / Warning Low)
  * **$E \le \text{InpLevelClimaxLow}$:** `clrOrangeRed` (Bearish Climax / Extreme Low)

* **Dynamic Levels Configuration:**
  To bypass the visual limitations of hardcoded levels, the suite exposes all 6 statistical significance boundaries to the input panel under `"Indicator Levels"`. The centerline grid is programmatically constructed inside `OnInit()` using:

  ```mql5
  IndicatorSetInteger(INDICATOR_LEVELS, 6);
  IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelFlowHigh);
  ```

* **Szigorú Chronological Sorting Safeguards:**
  To prevent calculation corruption caused by reverse-chronological array states (often forced by custom templates or third-party indicators on the active chart), the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations, a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Advanced MQL5 MTF Implementation Details

`EScore_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

Since Ehlers' smoothers inside the calculator are highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states. To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 5. Parameters

### A. EScore Settings

* **Underlying Smoother (`InpSmootherType`):** Selects between Ehlers' 2nd-order `SUPERSMOOTHER` or 3rd-order `ULTIMATESMOOTHER` centerline baseline. Default: `SUPERSMOOTHER`.
* **Volatility Lookback (`InpPeriod`):** The rolling window size ($N$) for the standard deviation and Ehlers smoother calculations (Default: `20`, Range: $\ge 2$).
* **Source Price (`InpSourcePrice`):** Selects the pricing input, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Signal Line Settings

* **Show Signal Line (`InpShowSignal`):** Toggle to enable/disable the Signal Line (Default: `true`).
* **Signal Line Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `5`).
* **Signal Line MA Type (`InpSignalType`):** Select the MA type for the Signal Line (Default: `SMA`). Supports `VWMA`.

### C. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate E-Scores on (Default: `PERIOD_H1`).

### D. Indicator Levels Settings

* **High Warning Level (`InpLevelFlowHigh`):** Volatility band indicating positive structural expansion (Default: `1.5`).
* **Low Warning Level (`InpLevelFlowLow`):** Volatility band indicating negative structural expansion (Default: `-1.5`).
* **High Climax Level (`InpLevelClimaxHigh`):** Extreme bullish exhaustion threshold (Default: `2.0`).
* **Low Climax Level (`InpLevelClimaxLow`):** Extreme bearish exhaustion threshold (Default: `-2.0`).
* **High Exhaustion Level (`InpLevelExtremeHigh`):** Advanced statistical exhaustion threshold (Default: `2.5`).
* **Low Exhaustion Level (`InpLevelExtremeLow`):** Advanced statistical exhaustion threshold (Default: `-2.5`).
* **Levels Color (`InpLevelColor`):** Customize the color of the horizontal line layout (Default: `clrSilver`).
* **Levels Style (`InpLevelStyle`):** Customize the line style of the horizontal line layout (Default: `STYLE_DOT`).

---

## 6. Quantitative Trading Strategies

### A. The Wyckoff Reversal Trigger (E-Score + Signal crossover)

Instead of trading the moment the price touches the Extreme Levels, wait for structural momentum to fade:

1. Wait for the E-Score to enter the Extreme Zone (**DeepSkyBlue** $\ge \text{InpLevelClimaxHigh}$ or **OrangeRed** $\le \text{InpLevelClimaxLow}$).
2. Wait for the E-Score histogram to contract and **cross back over the Signal Line** (typically configured as a 5-period TMA or EMA).
3. **Execution:** Open a mean-reversion trade (Short if high, Long if low) on the crossover bar. Place the stop-loss strictly beyond the extreme candle's high/low.

### B. Top-Down Volatility Deviation (MTF Core Strategy)

1. **Macro Volatility Deviation (H1/H4):** Apply `EScore_MTF_Pro` set to H1 or H4 on an M5/M15 execution chart. Configure it with a `VWMA` signal line.
2. **The Setup:** Wait for the macro **H1 E-Score** to enter the **Bear Extreme Zone (OrangeRed $\le \text{InpLevelClimaxLow}$)**, indicating that the macro price is extremely cheap relative to institutional fair value.
3. **Execution:** On the lower M5 chart, only look for buy setups. Once the local M5 E-Score crosses back above its own **InpLevelFlowLow (-1.5)** level (or crosses its signal line), execute **BUY** orders, riding the wave of macro mean-reversion back to the macro fair value.
