# E-Score Pro (Indicator)

## 1. Summary

**E-Score Pro** is an advanced, high-performance separate window oscillator that measures the statistical deviation of the current price from John Ehlers' low-lag filters (either the `SuperSmoother` or `UltimateSmoother`). Rather than relying on simple linear distance, it normalizes price deviation into units of rolling standard deviation (Z-Score), delivering a dimensionless, scale-free momentum tool.

To mitigate the high-frequency noise inherent in ultra-responsive filters, `E-Score Pro` incorporates an optional, highly customizable **Signal Line** selectable from any of the dynamic moving average types inside the `MovingAverage_Engine.mqh` library, while maintaining a highly expressive **5-Zone Thermal Color Histogram** for regime identification.

The indicator is fully integrated with Heikin Ashi price sources, maintaining strict definition-truth and incremental $O(1)$ calculation efficiency.

---

## 2. Mathematical Foundations and Calculation Logic

The calculation operates on aligned chronological prices $P_t$ (Standard or Heikin Ashi closes).

### A. Core Ehlers Z-Score (E-Score) Formula

The indicator calculates the distance of the price from the Ehlers Smoother curve ($S_t$) and standardizes it using the rolling standard deviation ($\sigma_t$) of that distance over lookback $W$ (`InpPeriod`):

$$\text{E-Score}_t = \frac{P_t - S_t}{\sigma_t}$$

Where the standard deviation is computed as:

$$\sigma_t = \sqrt{\frac{1}{W} \sum_{k=0}^{W-1} (P_{t-k} - S_{t-k})^2}$$

* $S_t$ is computed using either Ehlers' 2-pole `SuperSmoother` or `UltimateSmoother` coefficients, which filter out high-frequency noise while minimizing group delay in the passband.

### B. Universal Signal Line Formula

To filter out minor oscillations, any of the integrated moving average types can be applied to the E-Score output over a smoothing period $P_{\text{sig}}$ (`InpSignalPeriod`):

$$\text{Signal}_t = \text{MA}(\text{E-Score}_t, P_{\text{sig}}) \quad \text{using selected MA Type}$$

* If **`VWMA`** is selected as the Signal Line type, the calculations are automatically weighted by the market volume, utilizing a double-precision volume translation pipeline.

---

## 3. Advanced MQL5 Implementation & Volume Alignment

### A. Dynamic Volume-Weighted Signal Pipeline

Volume-weighted calculations (like VWMA) require double-precision volume data. The standard MQL5 `OnCalculate` provides volumes as integer arrays (`long volume[]`).
`E-Score Pro` implements an automatic high-performance conversion pipeline. It detects whether real or tick volumes are available, converts them incrementally ($O(1)$ complexity) to a global double array (`g_double_volume[]`), and forwards them to the Signal Line calculator:

```mql5
g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, ExtEScoreBuffer, g_double_volume, ExtSignalBuffer, InpPeriod);
```

This enables full volume-weighted statistical capabilities on custom arrays without sacrificing execution speed.

### B. MT5 Plot Persistency and Data Window Cleanup

MT5 is stateful; if an indicator disables a plot dynamically, the plot's draw style can remain corrupted upon re-initialization. `E-Score Pro` resolves this by explicitly overriding plot properties inside `OnInit()`.
Additionally, when `InpShowSignal` is toggled `false`, the indicator dynamically nullifies the plot label:

```mql5
PlotIndexSetString(1, PLOT_LABEL, NULL);
```

This completely purges the disabled Signal Line from the MT5 Data Window, keeping the user interface and data outputs perfectly clean.

### C. Strict $O(1)$ Incremental Calculation

The calculator uses the platform's `prev_calculated` parameter to process only the newest incoming bar on every tick. It resizes dynamic arrays on startup and performs rolling calculations efficiently without historical loops, ensuring ultra-low latency.

---

## 4. Parameters

### A. Core E-Score Settings

* `InpSmootherType`: Select between **SUPERSMOOTHER** or **ULTIMATESMOOTHER** as the baseline central curve.

* `InpPeriod`: The lookback window ($W$) for the standard deviation calculation (Default: `20` bars).
* `InpSourcePrice`: The applied price source (supports Standard and Heikin Ashi prices).

### B. Signal Line Settings

* `InpShowSignal`: Toggle to enable/disable the Signal Line on the chart and Data Window (Default: `true`).

* `InpSignalPeriod`: The lookback period for the Signal Line MA (Default: `5` bars).
* `InpSignalType`: Select the MA type for the Signal Line (Default: `SMA`).

---

## 5. Quantitative Analysis & Insights (V-Score vs. E-Score)

Through rigorous live market testing on major currency pairs (such as `EURUSD`) and stock indices (such as `US500`), a critical quantitative conclusion was established: **Z-Score normalization is structurally superior when applied to anchored, sluggish indicators rather than highly responsive, low-lag filters.**

### A. The VWAP (V-Score) Characteristics: Structural Regimes

* **VWAP Behavior:** VWAP is volume-weighted and anchored to a specific session start (`PERIOD_SESSION`). It possesses significant statistical inertia.
* **Z-Score Impact:** When the price trends, it drifts far from the VWAP and stays there. This creates a persistent, solid gap ($Close - VWAP$), resulting in long, smooth, and visually convincing blocks of color (sustained Coral or DeepSkyBlue regimes).
* **Usage:** V-Score is a highly reliable **Trend and Volatility Regime Indicator** (Macro-scale).

### B. The Ehlers (E-Score) Characteristics: High-Frequency Cycles

* **Ehlers Smoother Behavior:** SuperSmoother is designed with almost zero group delay. It hugs the price curve closely, adapting to almost every minor swing.
* **Z-Score Impact:** Because the purple smoother curve is extremely close to the price, the numerator ($Price - Smoother$) is tiny and fluctuates rapidly. This tiny numerator divided by an equally tiny rolling standard deviation amplifies minor price ticks, resulting in a jagged, noisy, high-frequency oscillator.
* **Usage:** E-Score is not suitable for tracking macro trends, but is a highly responsive **Short-Term Momentum Cycle Oscillator** (Micro-scale / Rate-of-Change proxy). The addition of the Signal Line is highly recommended to filter out the high-frequency noise and capture clean momentum crosses.
