# John Ehlers' MAMA Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' MAMA Pro Suite** is an institutional-grade, trend-adaptive moving average suite comprising two advanced indicators:

* `MAMA_Pro` (Standard)
* `MAMA_MTF_Pro` (Multi-Timeframe)

Developed by the legendary quantitative developer John F. Ehlers, the MESA Adaptive Moving Average (MAMA) and the Following Adaptive Moving Average (FAMA) represent a breakthrough in adaptive filtering. Traditional moving averages operate over a rigid, linear time lookback. This introduces significant lag during high-volatility trend expansions, while generating excessive whipsaws during sideways, choppy consolidations.

The MAMA Pro Suite resolves this trade-off by dynamically adapting its smoothing coefficient ($\alpha$) bar-by-bar based on the **homodyne phase changes** of the market cycle:

* **MAMA (MESA Adaptive Moving Average):** Reacts rapidly to price changes during trend expansions, acting like a fast 3-period EMA to eliminate lag.
* **FAMA (Following Adaptive Moving Average):** Smoothes MAMA recursively in a secondary adaptive loop. Because FAMA exhibits exactly half the phase response of MAMA, the two lines never cross during trends, establishing a beautiful, low-lag trend corridor.

During choppy consolidations, the smoothing constant contracts to its slow limit, causing both lines to completely flatten out. This unique behavior locks the averages in place, completely eliminating the false crossovers that plague standard moving average systems.

The suite features dynamic Heikin Ashi price integration, high-resolution decimal precision, customizable line visibility toggles, and advanced multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The MAMA calculation pipeline constitutes a complex 10-step Digital Signal Processing (DSP) chain calculated recursively on every bar:

### A. Pre-Smoothing (4-Bar FIR)

To eliminate high-frequency noise, the price $P_t$ (Standard or Heikin Ashi) is smoothed using a weighted FIR filter:

$$\text{Smooth}_t = \frac{4 P_t + 3 P_{t-1} + 2 P_{t-2} + P_{t-3}}{10}$$

### B. Bilinear Detrender & Hilbert Transform

The pre-smoothed series is passed through Ehlers' digital detrender filter, using the previous cycle period ($T_{t-1}$) to scale the frequency response:

$$\text{Detrender}_t = (0.0962 \text{Smooth}_t + 0.5769 \text{Smooth}_{t-2} - 0.5769 \text{Smooth}_{t-4} - 0.0962 \text{Smooth}_{t-6}) \times (0.075 T_{t-1} + 0.54)$$

The Quadrature ($Q_1$) and InPhase ($I_1$) components are resolved:

$$Q_{1, t} = (0.0962 \text{Detrender}_t + 0.5769 \text{Detrender}_{t-2} - 0.5769 \text{Detrender}_{t-4} - 0.0962 \text{Detrender}_{t-6}) \times (0.075 T_{t-1} + 0.54)$$

$$I_{1, t} = \text{Detrender}_{t-3}$$

### C. Homodyne Discriminator & Cycle Period ($T_t$)

The phase change is tracked using complex conjugate multiplication:

$$\text{Re}_t = I_{1, t} I_{1, t-1} + Q_{1, t} Q_{1, t-1}$$

$$\text{Im}_t = I_{1, t} Q_{1, t-1} - Q_{1, t} I_{1, t-1}$$

The raw cycle period ($T_{\text{Raw}}$) is calculated and smoothed to establish the stable Period ($T_t$):

$$T_{\text{Raw}, t} = \frac{360.0}{\arctan(\text{Im}_t / \text{Re}_t) \times 180.0 / \pi}$$

$$T_t = 0.2 T_{\text{Raw}, t} + 0.8 T_{t-1}$$

### D. Phase angle ($\Phi$) and Delta Phase ($\Delta\Phi$)

$$\Phi_t = \arctan\left(\frac{Q_{1, t}}{I_{1, t}}\right) \times \frac{180.0}{\pi}$$

$$\Delta\Phi_t = \Phi_{t-1} - \Phi_t \quad (\Delta\Phi \ge 1.0)$$

### E. Adaptive Alpha ($\alpha_t$) and Clamping

The dynamic smoothing coefficient ($\alpha_t$) is calculated as the ratio of the Fast Limit (`InpFastLimit`, $FL$) to the Delta Phase, clamped tightly between the Fast Limit and the Slow Limit (`InpSlowLimit`, $SL$):

$$\alpha_{\text{Raw}, t} = \frac{FL}{\Delta\Phi_t}$$

$$\alpha_t = \max\left(SL, \, \min(FL, \, \alpha_{\text{Raw}, t})\right)$$

*Under default parameters ($FL = 0.50$ and $SL = 0.05$), the active smoothing constant $\alpha_t$ dynamically fluctuates between `0.05` (equivalent to a 39-period EMA) and `0.50` (equivalent to a fast 3-period EMA) based purely on market cycle changes.*

### F. Final MAMA and FAMA Calculations

The final adaptive moving averages are calculated recursively using the dynamic $\alpha_t$:

$$\text{MAMA}_t = \alpha_t P_t + (1.0 - \alpha_t) \text{MAMA}_{t-1}$$

$$\text{FAMA}_t = 0.5 \alpha_t \text{MAMA}_t + (1.0 - 0.5 \alpha_t) \text{FAMA}_{t-1}$$

---

## 3. High-Performance & Customization Highlights

The MAMA Pro Suite is engineered to meet the highest execution and usability standards:

* **Custom Line Visibility Toggles:**
  To support advanced charting and clean template setups, both wrappers feature independent boolean toggles (`InpShowMAMA` and `InpShowFAMA`). If a line is disabled, the system dynamically purges the plot and clears the label inside `OnInit()`, completely hiding it from the chart and the MT5 Data Window:

  ```mql5
  PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
  PlotIndexSetString(0, PLOT_LABEL, NULL);
  ```

  The calculator continues to compute both states recursively to preserve state continuity, but the unused buffer is filled with `EMPTY_VALUE` in `OnCalculate()` to save graphics memory.

* **Strict Chronological Sorting Safeguards:**
  Because the homodyne discriminator and phase calculators rely on a highly state-sensitive recursive history ($t-1$ to $t-6$), any reverse-chronological array indexing will completely corrupt the calculations. To prevent this, the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`. This is also applied inside all 16 internal DSP buffers within the calculator engine classes right after resizing.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations, a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Advanced MQL5 MTF Implementation Details

`MAMA_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

Since the MAMA and FAMA equations are highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states. To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 5. Parameters

### A. MAMA Settings

* **Fast Limit (`InpFastLimit`):** The maximum value that Alpha can reach during explosive trend cycles. Represents the upper speed limit (Default: `0.50`, corresponds to a 3-period EMA).
* **Slow Limit (`InpSlowLimit`):** The minimum value that Alpha can fall to during choppy, consolidated ranges. Represents the lower speed limit (Default: `0.05`, corresponds to a 39-period EMA).
* **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Display Settings

* **Show MAMA Line (`InpShowMAMA`):** Toggle to enable/disable the MAMA (Fast) line on the chart (Default: `true`).
* **Show FAMA Line (`InpShowFAMA`):** Toggle to enable/disable the FAMA (Slow) line on the chart (Default: `true`).

### C. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate momentum on (Default: `PERIOD_H1`).

---

## 6. Quantitative Trading Strategies

### A. The Zero-Whipsaw Trend Corridor Crossover (MAMA vs. FAMA)

Because the FAMA moves with exactly half the phase response of the MAMA, the two lines only cross at major cyclical trend reversals, remaining perfectly parallel or flat during choppy consolidations.

1. **Setup:** Apply `MAMA_Pro` on an M15 chart:
   * `InpFastLimit = 0.50`, `InpSlowLimit = 0.05` (The standard institutional defaults)
   * Ensure both `InpShowMAMA` and `InpShowFAMA` are enabled.
2. **BUY Entry (Long):**
   * Wait for the faster **MAMA line (red) to cross above the slower FAMA line (blue)**.
   * **Execution:** Open Long. Place stop-loss strictly below the local swing low.
3. **SELL Entry (Short):**
   * Wait for the **MAMA line to cross below the FAMA line**.
   * **Execution:** Open Short. Place stop-loss strictly above the local swing high.
4. **Sideways Range Protection:** During choppy, sideways ranges, both lines flatten completely and run parallel or slightly touch without crossing, protecting traders from the whipsaws that plague standard moving average crossovers.

### B. Adaptive Support and Resistance Pullbacks (FAMA Boundary)

During strong trending expansions, FAMA acts as an exceptionally reliable dynamic support or resistance line.

1. **Setup:** Apply `MAMA_Pro` on an H1 chart with standard settings.
2. **Trend Definition:**
   * **Bullish Regime:** MAMA is trading strictly above FAMA, and FAMA is sloping upward.
   * **Bearish Regime:** MAMA is trading strictly below FAMA, and FAMA is sloping downward.
3. **Execution Setup:**
   * In a Bullish Regime, wait for price to pull back and **test the kék FAMA line**.
   * Enter **BUY** orders strictly when a bullish rejection candle (e.g. hammer or pin bar) closes back above FAMA.
   * Place the protective stop strictly below the FAMA line, using it as an absolute trend barrier.
