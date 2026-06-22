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
  * **Green (Momentum High):** Fast upward expansion.
  * **Red (Momentum Low):** Fast downward expansion.
  * **Gray (Neutral Noise):** Volatility contraction or directionless noise.

### B. Speed (The Scalar)

* **Definition:** The absolute rate of change of price position over the lookback window, representing the total path length traveled. It possesses **Magnitude** only.
* **Formula:**
  $$\text{Speed}_t = \frac{\frac{1}{N} \sum_{k=0}^{N-1} |P_{t-k} - P_{t-k-1}|}{\text{ATR}_t}$$
* **Interpretation:** Measures the total energy spent. How much did the market run around? Visualized as an orange envelope mirrored around the zero-line.

### C. The Signal Line (The Reversal Trigger)

* **Definition:** A customizable moving average calculated over the Velocity histogram to smooth out minor fluctuations and act as a dynamic crossover trigger:
  $$\text{Signal}_t = \text{MA}(\text{Velocity}_t, P_{\text{sig}}) \quad \text{using selected MA Type}$$

---

## 3. Kinematic Efficiency & Strategic Triggers

The relationship between the **Histogram (Velocity)** and the **Mirrored Envelopes (Speed)** tells the true story of market efficiency:

### A. Persistent Trend Regime (Symmetric Lockstep)

If Velocity is high and hugs the outer Speed envelope ($\text{Velocity} \approx \text{Speed}$):

* Every single price tick contributed directly to the directional move.
* *Market State:* High-efficiency, high-conviction institutional trend. Breakouts are highly likely to succeed.

### B. Choppy / Volatile Regime (Kinematic Inefficiency)

If Speed is high (envelopes are wide) but Velocity remains low (gray histogram bars near 0.0):

* The market is oscillating wildly but achieving zero net displacement. High energy is spent getting nowhere.
* *Market State:* High inefficiency. Do NOT trade breakouts. Expect immediate fakeouts and stop-hunts.

### C. The Kinematic Reversal Trigger (Wyckoff Setup)

The addition of the Signal Line creates an incredibly accurate reversal trigger:

1. Wait for the Velocity histogram to reach or pierce the **Speed Envelope** (signaling a maximum exhaustion/climax event).
2. Wait for the Velocity histogram to contract and **cross back over its Signal Line** (typically configured as a 5-period TMA or EMA).
3. **The Signal:** This crossover confirms that the extreme momentum has officially faded. Execute a mean-reversion counter-trend trade, placing the stop-loss strictly beyond the extreme candle's high/low.

---

## 4. Advanced MQL5 Implementation Details

### A. High-Performance $O(1)$ Performance

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

## 5. Input Parameters

### A. Core Kinematics Settings

* **Velocity Period (`InpVelPeriod`):** The vector/scalar lookback window size (Default: `3` bars).
* **ATR Period (`InpATRPeriod`):** The lookback window for the volatility normalizer (Default: `14`).
* **Threshold (`InpThreshold`):** The momentum significance level for color transitions (Default: `1.0` Sigma).
* **Show Speed (`InpShowSpeed`):** Toggle to display the orange Speed envelopes (Default: `true`).

### B. Signal Line Settings

* **Show Signal Line (`InpShowSignal`):** Toggle to enable/disable the Signal Line (Default: `true`).
* **Signal Line Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `5`).
* **Signal Line MA Type (`InpSignalType`):** Select the MA type for the Signal Line (Default: `SMA`).
