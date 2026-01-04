# Inverse Fisher RSI Professional

## 1. Summary (Introduction)

The Inverse Fisher Transform of RSI, developed by John Ehlers, is a unique indicator designed to transform a standard RSI oscillator into a clear, "on/off" signal for identifying market momentum states.

While a normal Fisher Transform amplifies price extremes to create sharp turning points, the **Inverse Fisher Transform compresses** the signal. It takes a smoothed and scaled RSI value and forces it into a tight range between -1 and +1. The result is an indicator that spends most of its time "pinned" to the +1 (strong bullish momentum) or -1 (strong bearish momentum) levels.

The primary purpose of this indicator is not to time entries with precision, but to provide an **unequivocal, digital-like indication of the current momentum regime**, helping traders to stay in trends and avoid choppy, uncertain market conditions.

## 2. Mathematical Foundations and Calculation Logic

The indicator follows a multi-step process to transform a standard RSI.

### Required Components

* **RSI Period (N):** The lookback period for the initial RSI calculation (Ehlers uses a short period).
* **WMA Period (M):** The lookback period for smoothing the scaled RSI.
* **Source Price (P):** The price series for the RSI calculation (typically `Close`).

### Calculation Steps (Algorithm)

1. **Calculate a Short-Period RSI:** First, a standard RSI is calculated over a short period `N` (e.g., 5).
2. **Scale and Center:** The RSI's 0-100 output is re-scaled to a range of -5 to +5. The formula is:
    $\text{Value1} = 0.1 \times (\text{RSI}_N - 50)$
3. **Smooth with WMA:** The `Value1` is then smoothed using a Weighted Moving Average (WMA) over a period `M` (e.g., 9) to create `Value2`. This step removes spurious spikes.
4. **Apply Inverse Fisher Transform:** The core Inverse Fisher Transform equation is applied to the smoothed `Value2` (`y`):
    $x = \frac{e^{2y} - 1}{e^{2y} + 1}$
    The result (`x`) is the final indicator value, which will be tightly bound between -1 and +1.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Component-Based Design (Composition):**
    The calculator (`Inverse_Fisher_RSI_Calculator.mqh`) orchestrates two powerful engines:
    1. **RSI Engine:** It reuses the `RSI_Pro_Calculator.mqh` to compute the base RSI. This ensures mathematical consistency with our standalone RSI indicator.
    2. **MA Engine:** It uses the `MovingAverage_Engine.mqh` to perform the WMA smoothing efficiently.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations.

* **Object-Oriented Logic:**
  * The Heikin Ashi version (`CInverseFisherRSICalculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the RSI module.

## 4. Parameters

* **RSI Period (`InpRSI_Period`):** The lookback period for the underlying RSI. Ehlers' recommendation and the default is a very short period of **5**. This is crucial for the indicator's responsiveness.
* **WMA Period (`InpWMA_Period`):** The period for the Weighted Moving Average used to smooth the scaled RSI. Ehlers' recommendation and the default is **9**.
* **Source (`InpSource`):** Selects between `Standard` and `Heikin Ashi` candles for the initial RSI calculation.

**Note on Parameters:** This indicator's effectiveness is closely tied to Ehlers' specific parameter choices. It is generally recommended to stick with the default values (`5, 9`).

## 5. Usage and Interpretation

The Inverse Fisher RSI is best used as a **momentum state filter** or a **regime filter**, not as a primary timing tool.

### **1. Zone-Based Trend Filtering (Primary Strategy)**

The indicator clearly defines three market states based on the `+0.5` and `-0.5` levels.

* **Bullish Zone (Above +0.5):** When the indicator is above the +0.5 level (and often "pinned" near +1.0), it signals strong, persistent bullish momentum. In this state, traders should only be looking for **long entries** or holding existing long positions.
* **Bearish Zone (Below -0.5):** When the indicator is below the -0.5 level (and often "pinned" near -1.0), it signals strong, persistent bearish momentum. In this state, traders should only be looking for **short entries** or holding existing short positions.
* **Neutral/Transition Zone (Between -0.5 and +0.5):** This is the "no man's land." The indicator's transition between the bullish and bearish zones happens here. This area signals uncertainty, consolidation, or a potential reversal. It is often wise to stay out of the market or close positions when the indicator is in this zone.

### **2. Threshold Crossover (Entry/Exit Signals)**

The crossing of the thresholds can be used as entry or exit signals.

* **Buy Signal:** The indicator crosses **above the -0.5 level**. This confirms that momentum has shifted to bullish.
* **Sell Signal:** The indicator crosses **below the +0.5 level**. This confirms that momentum has shifted to bearish.
* **Exit Signal:** An exit can be triggered when the indicator crosses back into the neutral zone (e.g., a long position is closed when the line crosses below +0.5).

**Key Difference vs. Fisher Transform:**
Do not confuse the two. The **Fisher Transform** is for *timing* reversals with sharp peaks. The **Inverse Fisher RSI** is for *confirming* the state of momentum with clear, persistent zones. It is a lagging, confirming tool by design.
