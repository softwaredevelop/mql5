# Stochastic Adaptive on DMI Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Stochastic Adaptive on DMI Pro Suite** is an institutional-grade, highly sophisticated trend-adaptive momentum and cycle trading suite comprising two advanced indicators:

* `Stochastic_Adaptive_on_DMI_Pro` (Standard)
* `Stochastic_Adaptive_on_DMI_MTF_Pro` (Multi-Timeframe)

Traditional Stochastic Oscillators suffer from a rigid lookback window (typically 14 periods). During strong trend expansions, static stochastics remain pinned at overbought/oversold extremes, generating false counter-trend crossovers. During choppy consolidations, they generate excessive whipsaw signals.

This suite resolves this limitation by introducing **Pure DMI-based Adaptivity**. The indicator dynamically scales its own Stochastic lookback period ($N_{\text{SP}}$) bar-by-bar, utilizing the volatility and directional efficiency of Welles Wilder's Directional Movement Index (DMI) formulated via Perry Kaufman's Efficiency Ratio (ER) model:

* **In Trending Markets (High ER):** The lookback window automatically contracts toward the minimum parameter, increasing sensitivity to identify exhaustion points immediately.
* **In Choppy Markets (Low ER):** The lookback window expands toward the maximum parameter, filtering out high-frequency noise and false crossovers.

The suite features dynamic Heikin Ashi price integration, a fully volume-weighted smoothing engine supporting **Volume-Weighted Moving Average (VWMA)** triggers on both the main K and signal D lines, and state-safe multi-timeframe step-blocking algorithms.

---

## 2. Mathematical Foundations

The calculation pipeline consists of seven sequential steps executed on every bar to translate raw price action into dynamic, volume-weighted adaptive stochastic coordinates:

### A. Step 1: Base DMI Calculations

Welles Wilder's standard Directional Indicators (+DI and -DI) are calculated recursively over the DMI Period (`InpDMIPeriod`).

### B. Step 2: DMI Oscillator ($O_{\text{DMI}}$)

The directional indicators are subtracted to form a zero-mean directional oscillator:

$$O_{\text{DMI}, t} = \text{+DI}_t - \text{-DI}_t \quad (\text{or reversed depending on selection})$$

### C. Step 3: DMI Efficiency Ratio ($\text{ER}$)

The Efficiency Ratio measures the absolute net directional change of the DMI Oscillator over a specified period $P$ (`InpErPeriod`) divided by the total sum of bar-to-bar absolute fluctuations (volatility):

$$\text{Direction}_t = \left| O_{\text{DMI}, t} - O_{\text{DMI}, t-P} \right|$$

$$\text{Volatility}_t = \sum_{k=0}^{P-1} \left| O_{\text{DMI}, t-k} - O_{\text{DMI}, t-k-1} \right|$$

$$\text{ER}_t = \begin{cases}
  \frac{\text{Direction}_t}{\text{Volatility}_t} & \text{if } \text{Volatility}_t > 1.0 \times 10^{-9} \\
  0.0 & \text{otherwise}
\end{cases}$$

### D. Step 4: Dynamic Stochastic Period ($N_{\text{SP}}$)

The lookback period is scaled dynamically. We apply an **inverse-relationship model**: higher efficiency (strong trend) contracts the period toward the minimum limit $N_{\text{Min}}$ (`InpMinStochPeriod`), while lower efficiency (choppy noise) expands the period toward the maximum limit $N_{\text{Max}}$ (`InpMaxStochPeriod`):

$$N_{\text{SP}, t} = \text{Round}\left( N_{\text{Min}} + (1.0 - \text{ER}_t) \times (N_{\text{Max}} - N_{\text{Min}}) \right)$$

*To prevent math breaking or division-by-zero errors inside the stochastic loop, a hard floor is enforced:*
$$N_{\text{SP}, t} = 2 \quad \text{if } N_{\text{SP}, t} < 2$$

### E. Step 5: Raw Adaptive %K on DMI

The highest high ($H_{\text{DMI}}$) and lowest low ($L_{\text{DMI}}$) of the DMI Oscillator are determined dynamically over the calculated variable lookback window $N_{\text{SP}, t}$:

$$H_{\text{DMI}, t} = \max(O_{\text{DMI}, t}, O_{\text{DMI}, t-1}, \dots, O_{\text{DMI}, t - N_{\text{SP}, t} + 1})$$

$$L_{\text{DMI}, t} = \min(O_{\text{DMI}, t}, O_{\text{DMI}, t-1}, \dots, O_{\text{DMI}, t - N_{\text{SP}, t} + 1})$$

$$\text{Range}_t = H_{\text{DMI}, t} - L_{\text{DMI}, t}$$

$$\%K_{\text{Raw}, t} = \frac{O_{\text{DMI}, t} - L_{\text{DMI}, t}}{\text{Range}_t} \times 100$$

*If the range is 0, a flatline-prevention fallback is applied:*
$$\%K_{\text{Raw}, t} = \begin{cases}
  \%K_{\text{Raw}, t-1} & \text{if } \text{Range}_t \le 1.0 \times 10^{-9} \text{ and } t > 0 \\
  50.0 & \text{if } \text{Range}_t \le 1.0 \times 10^{-9} \text{ and } t = 0
\end{cases}$$

### F. Step 6 & 7: Slowing and Signal Smoothing

The raw adaptive values are smoothed over `InpSlowingPeriod` and `InpDPeriod` to produce the final indicator lines:

$$\%K_{\text{Slow}, t} = \text{MA}(\%K_{\text{Raw}}, \text{SlowingPeriod})_t$$

$$\%D_{\text{Signal}, t} = \text{MA}(\%K_{\text{Slow}}, \text{SignalPeriod})_t$$

Both smoothing loops natively support standard moving averages and **Volume-Weighted Moving Averages (VWMA)** using the integrated double-precision volume routing pipelines:

$$\text{VWMA}_t = \frac{\sum_{j=0}^{P-1} \text{Source}_{t-j} \times \text{Volume}_{t-j}}{\sum_{j=0}^{P-1} \text{Volume}_{t-j}}$$

---

## 3. Visual & Architectural Highlights

The suite is engineered to maintain ultimate precision and runtime safety:

* **Static Stable Levels and Scale Boundaries:**
  As requested, the extreme thresholds are locked to standard institutional boundaries: `10.0` (Extreme Oversold), `20.0` (Oversold), `50.0` (Balance Axis), `80.0` (Overbought), and `90.0` (Extreme Overbought). The vertical scale is locked strictly to `0.0` and `100.0` using property directives.

* **Szigorú Chronological Sorting Safeguards:**
  Because the base DMI calculation and the adaptive stochastic loops rely strictly on recursive history ($t-1$), any reverse-chronological array indexing will completely corrupt the calculations. To prevent this, the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`. This is also applied inside all internal resizes within the calculator classes.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations, a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Advanced MQL5 MTF Implementation Details

`Stochastic_Adaptive_on_DMI_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

### B. State Mocking for Wilder's Smoothing Stability

Since Wilder's DMI smoothing is highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states. To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 5. Parameters

### A. DMI Settings

* **DMI Period (`InpDMIPeriod`):** Welles Wilder's lookback window size ($N$) for the directional movement calculations (Default: `10`, Range: $\ge 1$).
* **Oscillator Type (`InpOscType`):** Selects between `OSC_PDI_MINUS_NDI` (+DI - -DI) or `OSC_NDI_MINUS_PDI` (-DI - +DI). Default: `OSC_PDI_MINUS_NDI`.

### B. Adaptive Settings

* **Efficiency Ratio Period (`InpErPeriod`):** The rolling window size used strictly to calculate DMI directional efficiency (Default: `10`).
* **Min Dynamic Period (`InpMinStochPeriod`):** The minimum lookback period allowed for the Stochastic during strong trends (Default: `5`).
* **Max Dynamic Period (`InpMaxStochPeriod`):** The maximum lookback period allowed for the Stochastic during choppy consolidations (Default: `30`).

### C. Stochastic Settings

* **Slowing Period (`InpSlowingPeriod`):** The smoothing lookback period for raw %K to establish Slow %K (Default: `3`).
* **Slowing MA Type (`InpSlowingMAType`):** Select the MA type used for Slowing (Default: `SMA`). Supports `VWMA`.
* **Signal Line Period (`InpDPeriod`):** The lookback period for the Signal %D line (Default: `3`).
* **Signal Line MA Type (`InpDMAType`):** Select the MA type used for the Signal line (Default: `SMA`). Supports `VWMA`.

### D. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate adaptive stochastics on (Default: `PERIOD_H1`).

---

## 6. Quantitative Trading Strategies

### A. Adaptive Extremes Reversal (VWMA Crossover)

During trend expansions, the lookback period contracts, making the Stochastic highly sensitive. By configuring the smoothing loops to `VWMA`, we ensure that turning-point crossovers are backed by institutional trading volume before entering.

1. **Setup:** Apply `Stochastic_Adaptive_on_DMI_Pro` on an M15 chart:
   * `InpDMIPeriod = 10`, `InpOscType = OSC_PDI_MINUS_NDI`
   * `InpMinStochPeriod = 5`, `InpMaxStochPeriod = 30`
   * `InpSlowingPeriod = 3` (MA Type: `VWMA`)
   * `InpDPeriod = 3` (MA Type: `VWMA`)
2. **BUY Entry (Long):**
   * Wait for the Adaptive %K line (blue) to drop below **`10.0`** or **`20.0`** (extreme oversold).
   * Enter Long once the Adaptive %K crosses **above the Signal %D line** (coral) and closes above `20.0`, confirming that the cyclical turn is backed by institutional buying volume.
3. **SELL Entry (Short):**
   * Wait for the Adaptive %K line to rise above **`90.0`** or **`80.0`** (extreme overbought).
   * Enter Short once the Adaptive %K crosses **below the Signal %D line** and closes below `80.0`.
4. **Stop-Loss:** Place the protective stop strictly beyond the high/low of the reversal trigger bar.

### B. Top-Down Macro Cycle Alignment (MTF Trend Riding)

Using the Adaptive Stochastic on a higher timeframe ensures that lower timeframe trade executions are aligned with large-scale institutional volatility cycles.

1. **Setup:** Apply `Stochastic_Adaptive_on_DMI_MTF_Pro` set to H1 on an M5 execution chart. Configure both slowing and signal methods to `VWMA` to filter out low-volume market noise.
2. **Macro Trend Definition:**
   * **Bullish Cycle Alignment:** The H1 Adaptive %K is above its Signal %D line and rising from the `20.0` or `50.0` key levels. Strictly seek buy setups on the lower M5 chart.
   * **Bearish Cycle Alignment:** The H1 Adaptive %K is below its Signal %D line and falling from the `80.0` or `50.0` key levels. Strictly seek sell setups.
3. **LTF Execution:** On the local M5 chart, apply a local entry trigger. When the H1 MTF indicator defines a Bullish Cycle Alignment, execute long entry setups strictly when the local trigger crosses up, ignoring all counter-trend short setups.
