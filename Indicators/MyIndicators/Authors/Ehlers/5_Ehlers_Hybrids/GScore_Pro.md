# G-Score Pro (Indicator)

## 1. Summary (Introduction)

The **`GScore_Pro`** (G-Score) is an institutional-grade, low-lag statistical cycle oscillator designed to identify short-to-medium-term price anomalies, momentum accelerations, and high-probability reversal zones.

Unlike traditional bounded oscillators (RSI, Stochastic) which are highly prone to scaling compressions and "clinging" at boundaries during trends, the G-Score is statistically confined but mathematically unbounded.

It measures the normalized distance between the current price and John Ehlers' highly responsive, low-pass **2-Pole Gaussian Filter** ($G_t$). This distance is expressed in rolling standard deviation units (Sigma units):

$$\text{Sigma Distance} = \frac{\text{Current Price} - G_t}{\sigma_t}$$

By employing Ehlers' Gaussian filter instead of simple moving averages, `G-Score Pro` eliminates the severe group delay (lag) inherent in traditional moving averages. This delivers an ultra-responsive, noise-filtered, and dimensionless oscillator ideally suited for high-frequency momentum trading, cyclical analysis, and timing mean-reversion entries.

---

## 2. Mathematical Foundations and Calculation Logic

The statistical calculations operate on synchronized chronological prices $P_t$ (Standard or Heikin Ashi prices).

### A. Ehlers 2-Pole Gaussian Filter Baseline ($G_t$)

The central baseline represents John Ehlers' 2-Pole Gaussian低通 filter. It utilizes a continuous smoothing coefficient calculated dynamically from the selected lookback period $N$ (`InpPeriod`):

$$\beta = 2.415 \times \left(1.0 - \cos\left(\frac{2.0 \times \pi}{N}\right)\right)$$

$$\alpha = -\beta + \sqrt{\beta^2 + 2.0 \times \beta}$$

The recursive filter coefficients are established as:
$$c_0 = \alpha^2$$
$$a_1 = 2.0 \times (1.0 - \alpha)$$
$$a_2 = -(1.0 - \alpha)^2$$

The final Ehlers Gaussian Filter value ($G_t$) at bar $t$ is calculated recursively as:
$$G_t = c_0 P_t + a_1 G_{t-1} + a_2 G_{t-2}$$

### B. Standard Deviation of Price Dispersion ($\sigma_t$)

The rolling standard deviation measures the volatility and dispersion of the price relative to the Gaussian curve over the lookback window $N$:

$$\sigma_t = \sqrt{\frac{1}{N} \sum_{k=0}^{N-1} (P_{t-k} - G_{t-k})^2}$$

### C. Final Normalized G-Score

The normalized G-Score represents the volatility-adjusted distance between the price and the low-lag Gaussian curve:

$$\text{G-Score}_t = \frac{P_t - G_t}{\sigma_t}$$

---

## 3. Optional Signal Line (Wyckoff Reversal Trigger)

To prevent premature counter-trend execution (trying to "catch a falling knife"), `G-Score Pro` incorporates an optional, customizable **Signal Line** selectable from any of the dynamic moving average types inside the `MovingAverage_Engine.mqh` library (e.g., SMA, EMA, VWMA).

* **The Concept:** The Signal Line calculates a secondary moving average directly on the G-Score output buffer (`ExtGScoreBuffer[]`).
* **The Reversal Trigger:** Instead of entering a counter-trend position immediately when the G-Score reaches an extreme, traders wait for the G-Score histogram to cross back over its Signal Line. This crossover confirms that the extreme directional momentum has officially faded, and statistical mean reversion is underway.

---

## 4. Multi-Stage Statistical Mapping (The 5-Zone Palette)

To represent the progressive build-up of market momentum and tension, the indicator implements a **6-Level Sigma Boundary Layout** ($\pm 1.5, \pm 2.0, \pm 2.5$) and a **5-Zone Thermal Color Histogram**:

| G-Score Value | Color | Market Regime | Statistical Significance | Action / Concept |
| :--- | :--- | :--- | :--- | :--- |
| **$G \ge +2.5$** | `clrOrangeRed` | **Bull Extreme** (Climax) | $< 0.6\%$ of events | **Severe Overbought.** High probability exhaustion zone. Prepare to Short. |
| **$G \in [+2.0, +2.5)$** | `clrCoral` | **Bull Flow** (Acceleration) | $\approx 2.2\%$ of events | **Strong Bullish Momentum.** Scale-in warning zone for reversal trades. |
| **$G \in [-1.5, +1.5]$** | `clrGray` | **Neutral Zone** (Random Noise) | $\approx 86.6\%$ of events | **Equilibrium.** Market represents fair value. Noise zone. |
| **$G \in [-2.5, -2.0]$** | `clrLightSkyBlue` | **Bear Flow** (Acceleration) | $\approx 2.2\%$ of events | **Strong Bearish Momentum.** Scale-in warning zone for reversal trades. |
| **$G \le -2.5$** | `clrDeepSkyBlue` | **Bear Extreme** (Climax) | $< 0.6\%$ of events | **Severe Oversold.** High probability exhaustion zone. Prepare to Buy. |

---

## 5. MQL5 Implementation Details

* **Decoupled Architecture:**
  The mathematical computations are fully encapsulated in `GScore_Calculator.mqh` via the class `CGScoreCalculator`. It dynamically embeds `CGaussianFilterCalculator` and `CHeikinAshi_Calculator` (composition over inheritance), keeping the visual wrapper `GScore_Pro.mq5` incredibly lightweight.

* **VWMA & Asynchronous Volume Pipeline:**
  If **`VWMA`** is selected as the Signal Line type, the calculations are automatically weighted by the market volume. Since MT5 delivers volumes as `long` arrays, `GScore_Pro` implements an automatic high-performance translation pipeline. It converts volumes to a double array (`g_double_volume[]`) incrementally ($O(1)$ complexity) and forwards them to the Signal Line calculator, enabling full volume-weighted calculations.

* **Plot Persistency and Data Window Cleanup:**
  MT5 plots are stateful; if an indicator disables a plot dynamically, the plot's draw style can remain corrupted upon re-initialization. `GScore_Pro` resolves this by explicitly overriding plot properties inside `OnInit()`. Additionally, when `InpShowSignal` is toggled `false`, the indicator dynamically nullifies the plot label:

  ```mql5
  PlotIndexSetString(1, PLOT_LABEL, NULL);
  ```

  This completely purges the disabled Signal Line from the MT5 Data Window, keeping the user interface clean.

---

## 6. Input Parameters

### A. Core G-Score Settings

* **Period (`InpPeriod`):** The lookback window size ($N$) for the standard deviation and the Gaussian Filter cutoff calculations (Default: `20`).

* **Applied Price (`InpSourcePrice`):** The price series source to analyze (supports Standard and Heikin Ashi prices). Default: `PRICE_CLOSE_STD`.

### B. Signal Line Settings

* **Show Signal Line (`InpShowSignal`):** Toggle to enable/disable the Signal Line on the chart and Data Window (Default: `true`).

* **Signal Line Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `5`).
* **Signal Line MA Type (`InpSignalType`):** Select the MA type for the Signal Line (Default: `SMA`).

---

## 7. Advanced Trading Strategies

### A. The Wyckoff Reversal Trigger (G-Score + Signal crossover)

Instead of trading the moment the price touches the Extreme Levels, wait for structural momentum to fade:

1. Wait for the G-Score to enter the Extreme Zone (**OrangeRed** $\ge +2.5$ or **DeepSkyBlue** $\le -2.5$).
2. Wait for the G-Score histogram to cross back over the **Signal Line** (typically configured as a 5-period TMA or EMA).
3. **Execution:** Open a mean-reversion trade (Short if high, Long if low) on the crossover bar. Place the stop-loss strictly above/below the high/low of the extreme spike.

### B. Volume-Weighted Squeeze Fading (VWMA Signal Mode)

VWMA Signal Lines are exceptionally accurate at detecting low-volume fakeouts.

1. When a breakout of a major horizontal zone occurs, look at `GScore_Pro` set with a **`VWMA`** Signal Line.
2. If the price breaks out but the G-Score spikes violently into the Extreme Zone ($G > 2.5$) while the **VWMA Signal Line** fails to follow it rapidly, the price move is unsupported by sustainable volume and is a volume-dry fakeout.
3. Prepare to fade the breakout as a **fakeout**, entering the reverse trade when the G-Score crosses back below the VWMA Signal Line.
