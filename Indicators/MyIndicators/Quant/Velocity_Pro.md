# Velocity Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Velocity Pro Suite** is an institutional-grade kinematics separate-window analytical suite comprising two advanced indicators: `Velocity_Pro` (Standard) and `Velocity_MTF_Pro` (Multi-Timeframe).

Unlike standard momentum indicators that simply calculate price delta changes over a fixed window, this proprietary tool separates **"Directional Impulse" (Velocity Vector)** from the **"Raw Activity" (Speed Scalar)** of the market. This critical physical distinction allows quantitative systems to identify the exact efficiency of price action, cleanly separating high-conviction Trending Regimes from highly volatile, low-conviction Choppy Regimes.

To filter out minor high-frequency noise, the suite incorporates an optional, highly customizable **Signal Line** fully integrated with the `MovingAverage_Engine.mqh` (supporting SMA, EMA, and volume-weighted VWMA types). It serves as an ultra-low-latency trigger for counter-trend reversals and trend-continuation setups on both local and macro timeframes.

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

To represent the progressive build-up of market momentum and exhaustion, the suite features a **Dual-Threshold Architecture** ($\pm 0.3$ and $\pm 1.0$) and a **5-Zone Thermal Color Histogram** with inverted bull/bear polarities (Blue for Bullish, Red/Coral for Bearish):

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

The indicators calculate ATR, Velocity, Speed, and the Signal Line incrementally. They utilize the platform's `prev_calculated` parameter to process only the newest incoming bar, avoiding redundant historic calculations and preserving CPU cycles.

### B. Dynamic Volume-Weighted Signal Pipeline

To support volume-weighted types (like **VWMA**) for the Signal Line, the suite implements an automatic volume-routing pipeline. It queries `SYMBOL_VOLUME_LIMIT` to detect if the broker provides Real Volume, converts it to a double array (`g_double_volume[]` on Standard, `h_vol_double[]` on MTF) incrementally, and passes it to the Signal Line calculator:

```mql5
g_signal_calculator.CalculateOnArray(rates_total, prev_calculated, BufVel, g_double_volume, BufSignal, InpATRPeriod + InpVelPeriod);
```

This enables the Signal Line to adapt dynamically to volume distribution during high-velocity breakouts.

### C. Forming LTF Block Flat-Force (The Warping Solution)

`Velocity_MTF_Pro` resolves the classic MTF live-bar warping bug by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

This ensures the entire active HTF block (Histogram, Envelopes, and Signal Line) is overwritten flatly on every live tick, keeping the separate window display perfectly flat and responsive in real-time.

### D. Asynchronous Timer Guard & HTF Calculations

* **Background Timer:** High-frequency MTF data requests often suffer from terminal loading gaps. A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as history is ready.
* **HTF Calculations:** On every live tick, the latest HTF price/volume elements are copied, and the ATR, Velocity, and Signal calculators are executed incrementally on only the live index (`g_htf_count - 1`), optimizing CPU cycles.

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

### C. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate Kinematics on (Default: `PERIOD_M5`).

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

### D. Top-Down Macro Kinematic Alignment (MTF Core Strategy)

1. **Macro Volatility Filter (H1/H4):** Apply `Velocity_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **The Setup:** Wait for the macro **H1 Velocity** to enter the **Bullish/Bearish Flow Zone (LightSkyBlue/Coral)**, confirming a healthy build-up of macro trend momentum.
3. **Execution:** On the lower M5 chart, only look for entries aligned with the macro direction. If H1 is LightSkyBlue, execute long-biased breakout setups when the local M5 Velocity crosses above its own Signal Line, maximizing the risk-to-reward ratio.
