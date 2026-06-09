# E-Score Pro (Indicator)

## 1. Summary

**E-Score Pro** is an advanced, high-performance separate window oscillator that measures the statistical deviation of the current price from John Ehlers' low-lag filters (either the `SuperSmoother` or `UltimateSmoother`). Rather than relying on simple linear distance, it normalizes price deviation into units of rolling standard deviation (Z-Score), delivering a dimensionless, scale-free momentum tool.

To mitigate the high-frequency noise inherent in ultra-responsive filters, `E-Score Pro` incorporates a smoothed **Exponential Moving Average (EMA) Signal Line**, while maintaining a highly expressive **5-Zone Thermal Color Histogram** for regime identification.

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

### B. EMA Signal Line Formula

To filter out minor oscillations, an Exponential Moving Average (EMA) is applied to the E-Score output over a smoothing period $P_{\text{sig}}$ (`InpSignalPeriod`):

$$\text{Signal}_t = (\text{E-Score}_t \times \alpha) + (\text{Signal}_{t-1} \times (1 - \alpha))$$

$$\alpha = \frac{2}{P_{\text{sig}} + 1}$$

---

## 3. MQL5 Implementation Details

* **Modularity and Composition:**
  The mathematical engine is encapsulated in `EScore_Calculator.mqh` via the class `CEScoreCalculator`. It embeds the `CEhlersSmootherCalculator` class (composition over inheritance) and manages internal Heikin Ashi buffers (`CHeikinAshi_Calculator`) internally, keeping the visual wrapper `EScore_Pro.mq5` incredibly lightweight.

* **Strict $O(1)$ Incremental Calculation:**
  The calculator uses the platform's `prev_calculated` parameter to process only the newest incoming bar on every tick. It resizes dynamic arrays on startup and performs rolling calculations efficiently without historical loops, ensuring ultra-low latency.

* **5-Zone Thermal Color Scheme:**
  Visualized as a color histogram to easily isolate structural regimes:
  * **Bull Extreme ($\ge 2.0$):** OrangeRed (Extreme overbought / exhaustion).
  * **Bull Flow ($\ge 1.5$):** Coral (Strong upward momentum).
  * **Neutral ($[-1.5, 1.5]$):** Gray (Noise / consolidation).
  * **Bear Flow ($\le -1.5$):** LightSkyBlue (Strong downward momentum).
  * **Bear Extreme ($\le -2.0$):** DeepSkyBlue (Extreme oversold / potential bounce).

---

## 4. Parameters

* `InpSmootherType`: Select between **SUPERSMOOTHER** or **ULTIMATESMOOTHER** as the baseline central curve.
* `InpPeriod`: The lookback window ($W$) for the standard deviation calculation (Default: `20` bars).
* `InpSignalPeriod`: The smoothing window for the EMA Signal Line (Default: `5` bars).
* `InpSourcePrice`: The applied price source (supports Standard and Heikin Ashi prices).

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
* **Usage:** E-Score is not suitable for tracking macro trends, but is a highly responsive **Short-Term Momentum Cycle Oscillator** (Micro-scale / Rate-of-Change proxy). The addition of the EMA Signal Line is highly recommended to filter out the high-frequency noise and capture clean momentum crosses.
