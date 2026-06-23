# Velocity Pro (Indicator)

## 1. Summary (Introduction)

**Velocity Pro** is an institutional-grade kinematics separate-window indicator designed to map market momentum. Unlike standard momentum indicators that simply calculate delta changes over a fixed window, this proprietary tool separates **"Directional Impulse" (Velocity Vector)** from the **"Raw Activity" (Speed Scalar)** of the market.

This critical physical distinction allows quantitative systems to identify the exact efficiency of price action, cleanly separating high-conviction Trending Regimes from highly volatile, low-conviction Choppy Regimes.

To filter out minor high-frequency noise, `Velocity Pro` incorporates an optional, highly customizable **Signal Line** fully integrated with the `MovingAverage_Engine.mqh` (supporting SMA, EMA, and volume-weighted VWMA types). It serves as an ultra-low-latency trigger for counter-trend reversals and trend-continuation setups.

---

## 2. Concepts & Methodology (Kinematics)

We apply classical kinematic principles to financial price action to extract the market's true structural velocity and speed:

### A. Velocity (The Vector)

* **Definition:** The rate of change of price position with respect to a volatility-adjusted frame of reference (ATR). It possesses both **Magnitude** and **Direction**.
* **Formula:**
  $$\text{Velocity}_t = \frac{P_t - P_{t-N}}{N \times \text{ATR}_t}$$
* **Interpretation:** Measures the net displacement. How far did the price actually get? Visualized as a colored histogram.
  * **Persistent Momentum:** Fast directional expansion.
  * **Neutral Noise:** Volatility contraction or directionless consolidation.

### B. Speed (The Scalar)

* **Definition:** The absolute rate of change of price position over the lookback window, representing the total path length traveled. It possesses **Magnitude** only.
* **Formula:**
  $$\text{Speed}_t = \frac{\frac{1}{N} \sum_{k=0}^{N-1} |P_{t-k} - P_{t-k-1}|}{\text{ATR}_t}$$
* **Interpretation:** Measures the total energy spent. How much did the market run around? Visualized as an orange envelope mirrored around the zero-line.

### C. The Signal Line (The Reversal Trigger)

* **Definition:** A customizable moving average calculated over the Velocity histogram to smooth out minor fluctuations and act as a dynamic crossover trigger:
  $$\text{Signal}_t = \text{MA}(\text{Velocity}_t, P_{\text{sig}}) \quad \text{using selected MA Type}$$

---

## 3. Kinematic Efficiency & Multi-Stage Regimes (5-Zone Swapped Palette)

To represent the progressive build-up of market momentum and exhaustion, `Velocity Pro` features a **Dual-Threshold Architecture** ($\pm 0.3$ and $\pm 1.0$) and a **5-Zone Thermal Color Histogram** with inverted bull/bear polarities (Blue for Bullish, Red/Coral for Bearish):

| Velocity Value | Color | Market Regime | Statistical Significance | Action / Concept |
| :--- | :--- | :--- | :--- | :--- |
| **$v \ge 1.0$** | `clrDeepSkyBlue` | **Bullish Climax** (Exhaustion) | $< 4.5\%$ of events | **Severe Overextended High.** High probability reversal zone. Prepare to Short. |
| **$v \in [0.3, 1.0)$** | `clrLightSkyBlue` | **Bullish Flow** (Trend Build-up) | $\approx 20.5\%$ of events | **Strong Bullish Momentum.** Trend-following buy setups and pyramiding. |
| **$v \in [-0.3, 0.3]$** | `clrGray` | **Neutral Zone** (Random Noise) | $\approx 50.0\%$ of events | **Equilibrium.** Avoid breakouts. Expect chops and false signals. |
| **$v \in (-1.0, -0.3]$** | `clrCoral` | **Bearish Flow** (Trend Build-up) | $\approx 20.5\%$ of events | **Strong Bearish Momentum.** Trend-following sell setups and pyramiding. |
| **$v \le -1.0$** | `clrOrangeRed` | **Bearish Climax** (Exhaustion) | $< 4.5\%$ of events | **Severe Overextended Low.** High probability reversal zone. Prepare to Buy. |

---

## 4. Advanced MQL5 Implementation Details

### A. High-Performance $O(1)$ Complexity

The indicator calculates ATR, Velocity, Speed, and the Signal Line incrementally. It utilizes the platform's `prev_calculated` parameter to process only the newest incoming bar, avoiding redundant historic calculations and preserving CPU cycles.

### B. Dynamic Volume-Weighted Signal Pipeline

To support volume-weighted types (like **VWMA**) for the Signal Line, `Velocity_Pro` implements an automatic volume-routing pipeline. It queries `SYMBOL_VOLUME_LIMIT` to detect if the broker provides Real Volume, converts it to a double array (`g_double_volume[]`) incrementally, and passes it to the Signal Line calculator:

```mql5
g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufVel, g_double_volume, BufSignal, InpATRPeriod + InpVelPeriod);
```

This enables the Signal Line to adapt dynamically to volume distribution during high-velocity breakouts.

### C. Plot Persistency and Data Window Cleanup

To resolve MT5 plot persistency bugs, `OnInit()` explicitly restores `DRAW_LINE` and `"Signal"` label when enabled. When `InpShowSignal` is toggled `false`, the indicator dynamically nullifies the plot label:

```mql5
PlotIndexSetString(3, PLOT_LABEL, NULL);
```

This completely purges the disabled Signal Line from the MT5 Data Window, keeping the user interface clean.

---

## 5. Parameters

### A. Core Kinematics Settings

* **Velocity Period (`InpVelPeriod`):** The vector/scalar lookback window size (Default: `3` bars).

* **ATR Period (`InpATRPeriod`):** The lookback window for the volatility normalizer (Default: `14`).

* **Low Threshold (`InpThresholdLow`):** The threshold for "Flow Zone" trend building (Default: `0.3`).
* **High Threshold (`InpThresholdHigh`):** The threshold for "Climax Zone" trend exhaustion (Default: `1.0`).
* **Show Speed (`InpShowSpeed`):** Toggle to display the orange Speed envelopes (Default: `true`).

### B. Signal Line Settings

* **Show Signal Line (`InpShowSignal`):** Toggle to enable/disable the Signal Line (Default: `true`).

* **Signal Line Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `5`).

* **Signal Line MA Type (`InpSignalType`):** Select the MA type for the Signal Line (Default: `SMA`).

---

## 6. Strategic Quantitative Usage

### A. Kinematic Efficiency (The Gap Analysis)

* **Trend Efficiency:** If Velocity is high and rides the top of the Speed envelope ($v \approx \text{Speed}$), every tick contributes to the directional move. This confirms a highly efficient, high-conviction institutional trend.

* **Intraday Chop:** If Speed is soaring (envelopes are wide) but Velocity remains low (gray bars near 0.0), the market is spending immense energy getting nowhere. Expect immediate fakeouts and stop-hunts.

### B. The Kinematic Reversal Trigger (Wyckoff Setup)

The addition of the Signal Line creates an incredibly accurate reversal trigger:

1. Wait for the Velocity histogram to reach or pierce the **Speed Envelope** (signaling a maximum exhaustion/climax event in the DeepSkyBlue/OrangeRed zone).
2. Wait for the Velocity histogram to contract and **cross back over its Signal Line** (typically configured as a 5-period TMA or EMA).
3. **The Signal:** This crossover confirms that the extreme momentum has officially faded. Execute a mean-reversion counter-trend trade, placing the stop-loss strictly beyond the extreme candle's high/low.

### C. Volume-Weighted Squeeze Fading (VWMA Signal Mode)

VWMA Signal Lines are exceptionally accurate at detecting low-volume fakeouts.

1. When a breakout of a major horizontal zone occurs, look at `Velocity_Pro` set with a **`VWMA`** Signal Line.
2. If the price breaks out but the Velocity histogram spikes violently into the Climax Zone ($v \ge 1.0$) while the **VWMA Signal Line** fails to follow it rapidly, the price move is unsupported by sustainable volume and is a volume-dry fakeout.
3. Prepare to fade the breakout as a **fakeout**, entering the reverse trade when the Velocity histogram crosses back below the VWMA Signal Line.
