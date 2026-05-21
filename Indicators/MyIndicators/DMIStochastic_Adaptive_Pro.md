# DMI Stochastic Adaptive Professional

## 1. Summary (Introduction)

The `DMIStochastic_Adaptive_Pro` is a cutting-edge hybrid oscillator that merges two highly effective quantitative concepts: Barbara Star's **DMI Stochastic** and Frank Key's **Variable-Length (Adaptive) Stochastic**.

While a standard Stochastic analyzes pure price, the DMI Stochastic analyzes the *momentum of directional pressure* by calculating a Stochastic on the DMI (+DI / -DI) values. However, like all fixed-period oscillators, it can still suffer from getting "stuck" in overbought or oversold zones during relentless, sustained momentum.

This indicator solves that problem by introducing **Kaufman's Efficiency Ratio (ER)**. The revolutionary aspect of this specific implementation is that the ER is calculated **directly on the DMI Oscillator line, rather than on the price**.

* When directional momentum is moving in a smooth, sustained trend (High ER on the DMI line), the indicator automatically **lengthens its Stochastic lookback period**. This prevents premature exhaustion signals and helps the trader ride the momentum.
* When directional momentum is choppy or shifting rapidly (Low ER on the DMI line), it **shortens its period**, becoming highly responsive to immediate momentum reversals.

## 2. Mathematical Foundations and Calculation Logic

The calculation is an advanced, multi-stage pipeline that generates directional movement, creates an oscillator, analyzes its efficiency, and applies a dynamic stochastic formula.

### Required Components

* **DMI Period:** The lookback period for the base +DI and -DI calculation.
* **ER Period:** The lookback period for calculating the Efficiency Ratio of the DMI Oscillator.
* **Min/Max Stochastic Periods:** The dynamic range boundaries for the Stochastic lookback.
* **Smoothing Periods:** Slowing Period and %D Period for the final signal lines.

### Calculation Steps (Algorithm)

1. **Calculate Directional Indicators (+DI, -DI):**
    Raw Directional Movement (+DM, -DM) and True Range (TR) are calculated and smoothed using Wilder's method over the `DMI Period`.
    $\text{+DI}_i = 100 \times \frac{\text{Smoothed +DM}_i}{\text{Smoothed TR}_i}$
    $\text{-DI}_i = 100 \times \frac{\text{Smoothed -DM}_i}{\text{Smoothed TR}_i}$

2. **Create the DMI Oscillator:**
    An oscillator is generated from the difference between the directional indicators (Default formula shown):
    $\text{DMI Oscillator}_i = \text{+DI}_i - \text{-DI}_i$

3. **Calculate the Efficiency Ratio (ER) on the DMI Oscillator:**
    The ER measures the signal-to-noise ratio of the momentum itself over the `ER Period` (N).
    $\text{ER}_t = \frac{\text{Abs}(\text{DMI Osc}_t - \text{DMI Osc}_{t-N})}{\sum_{i=0}^{N-1} \text{Abs}(\text{DMI Osc}_{t-i} - \text{DMI Osc}_{t-i-1})}$

4. **Calculate the Adaptive Stochastic Period (NSP):**
    The dynamic lookback period is calculated for the current bar based on the ER.
    $\text{NSP}_t = \text{Integer}[(\text{ER}_t \times (\text{MaxStoch} - \text{MinStoch})) + \text{MinStoch}]$

5. **Apply the Adaptive Stochastic Formula to the Momentum:**
    The Stochastic logic is applied to the `DMI Oscillator` using the dynamic `NSP` lookback.
    * **Calculate Raw %K:**
        $\text{Highest High} = \text{Highest DMI Osc value over the last NSP}_t \text{ bars}$
        $\text{Lowest Low} = \text{Lowest DMI Osc value over the last NSP}_t \text{ bars}$
        $\text{Raw \%K}_t = 100 \times \frac{\text{DMI Osc}_t - \text{Lowest Low}}{\text{Highest High} - \text{Lowest Low}}$
    * **Calculate Slow %K and %D:** The `Raw %K` is smoothed using the selected moving average types to output the final %K (Main) and %D (Signal) lines.

## 3. MQL5 Implementation Details

Our implementation employs a highly optimized, engine-based architecture designed for maximum performance in MetaTrader 5.

* **Modular "Engine" Architecture (`DMIStochastic_Adaptive_Calculator.mqh`):**
    The main calculator acts as a coordinator for three distinct mathematical engines:
    1. `DMI_Engine.mqh`: Handles the heavy lifting of the Wilder smoothing and +DI/-DI generation.
    2. `MovingAverage_Engine.mqh` (Instance 1): Handles the advanced smoothing for the Slow %K line.
    3. `MovingAverage_Engine.mqh` (Instance 2): Handles the advanced smoothing for the %D signal line.

* **Optimized Incremental Calculation (O(1) Standard):**
    The indicator processes only new data (using `prev_calculated`). The dynamic lookback loop (which scales via `NSP`) safely navigates the internally buffered `DMI Oscillator` array without forcing a full history recalculation, ensuring minimal CPU load even with complex adaptive logic.

* **Seamless Heikin Ashi Integration:**
    Through object-oriented inheritance (`CDMIStochasticAdaptiveCalculator_HA`), the indicator can transparently switch its underlying data source to Heikin Ashi candles by overriding the data preparation layer in the `DMI_Engine`.

## 4. Parameters

* **DMI Settings:**
  * `InpCandleSource`: Base price data source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).
  * `InpOscType`: Formula for the DMI Oscillator (`OSC_PDI_MINUS_NDI` or `OSC_NDI_MINUS_PDI`).
  * `InpDMIPeriod`: Lookback period for the underlying DMI components. (Default: `10`).

* **Adaptive Stochastic Settings:**
  * `InpErPeriod`: The lookback period for the Kaufman Efficiency Ratio. (Default: `10`).
  * `InpMinStochPeriod`: The shortest possible lookback period for the Stochastic. (Default: `5`).
  * `InpMaxStochPeriod`: The longest possible lookback period for the Stochastic. (Default: `30`).

* **Smoothing Settings:**
  * `InpSlowingPeriod`: Smoothing period for the main %K line. (Default: `3`).
  * `InpSlowingMAType`: Moving Average algorithm for the %K line. (Default: `SMA`).
  * `InpDPeriod`: Smoothing period for the signal %D line. (Default: `3`).
  * `InpDMAType`: Moving Average algorithm for the %D line. (Default: `SMA`).

## 5. Usage and Interpretation

The DMI Stochastic Adaptive should be interpreted as an **intelligent momentum oscillator**. It solves the false signals generated during strong trends.

* **During Sustained Momentum (High ER):**
  When bullish or bearish pressure is relentless, the internal period lengthens. The indicator will purposely *avoid* hitting the 80 or 20 extremes too early. If you are in a trend-following trade, this behavior signals that the momentum is stable and you should stay in the trade.

* **During Choppy/Reversing Momentum (Low ER):**
  When directional pressure stalls or becomes erratic, the internal period shortens drastically. The indicator becomes highly sensitive. In this state, a push into the overbought (>80) or oversold (<20) territory is a strong signal of immediate momentum exhaustion.

* **Trading Signals:**
  * **Exhaustion Reversals:** Look for standard %K and %D line crossovers *specifically* when the indicator has reached the extreme zones (<20 or >80). Because the indicator is adaptive, these extremes carry much more mathematical weight than in a standard Stochastic.
