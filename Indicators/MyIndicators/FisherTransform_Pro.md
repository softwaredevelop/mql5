# Fisher Transform Pro

## 1. Summary (Introduction)

The Fisher Transform is a technical indicator created by J.H. Ehlers that converts price into a Gaussian normal distribution. The primary purpose of this transformation is to create sharp, clear turning points that are less prone to the lag and ambiguity of many other oscillators.

The indicator consists of two lines: the Fisher line and a signal line (its value from the previous bar). It is an unbound oscillator, but in practice, it tends to fluctuate around a zero line, with extreme readings suggesting a price reversal is more likely.

Our `FisherTransform_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The Fisher Transform uses a mathematical formula to normalize price data, making extreme price moves more apparent.

### Required Components

* **Period (N):** The lookback period for finding the highest and lowest prices.
* **Source Price:** The indicator uses the median price `(High + Low) / 2` as its input.

### Calculation Steps (Algorithm)

1. **Transform Price to a Level between -1 and +1:** First, the source price is converted into a value that fluctuates primarily between -1 and +1. This is done by determining the price's position within its highest and lowest range over the last `N` periods.
    * $\text{Price Position}_i = \frac{\text{Source Price}_i - \text{Lowest Price}_{N}}{\text{Highest Price}_{N} - \text{Lowest Price}_{N}} - 0.5$
    * This value is then smoothed with a specific recursive formula:
        $\text{Value}_i = (0.33 \times 2 \times \text{Price Position}_i) + (0.67 \times \text{Value}_{i-1})$
    * The resulting `Value` is clamped to a range just inside -1 and +1 (e.g., -0.999 to 0.999) to avoid mathematical errors.

2. **Apply the Fisher Transform:** The core of the indicator is the application of the Fisher Transform formula to the smoothed `Value`.
    $\text{Fisher}_i = 0.5 \times \ln\left(\frac{1 + \text{Value}_i}{1 - \text{Value}_i}\right)$
    Where `ln` is the natural logarithm.

3. **Final Smoothing and Signal Line:** The resulting Fisher value is smoothed again with its own previous value. The signal line is simply the Fisher line from the previous bar.
    $\text{Final Fisher}_i = \text{Fisher}_i + (0.5 \times \text{Final Fisher}_{i-1})$
    $\text{Signal}_i = \text{Final Fisher}_{i-1}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`FisherTransform_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CFisherTransformCalculator`**: The base class that performs the full, multi-stage calculation on a given source price `(High+Low)/2`.
  * **`CFisherTransformCalculator_HA`**: A child class that inherits from the base class and overrides only the data preparation step. Its sole responsibility is to calculate Heikin Ashi candles and provide the `(HA_High + HA_Low) / 2` price to the base class's shared calculation algorithm. This object-oriented approach eliminates code duplication.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers (like `m_hl2_price` and `m_value_buffer`) persist their state between ticks. This allows the recursive Fisher Transform algorithm to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Robust Initialization:** The final, recursive calculation of the Fisher line is highly susceptible to floating-point overflows. Our code explicitly handles this by calculating the **first valid value** of the Fisher line **without** the recursive component, providing a stable starting point for the calculation chain.

## 4. Parameters

* **Length (`InpLength`):** The lookback period for finding the highest and lowest prices. A shorter period results in a more sensitive oscillator. Default is `9`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the `(High+Low)/2` calculation.
  * `CANDLE_STANDARD`: Uses the standard chart's High and Low.
  * `CANDLE_HEIKIN_ASHI`: Uses the smoothed Heikin Ashi High and Low.

## 5. Usage and Interpretation

* **Identifying Extremes:** The primary use of the Fisher Transform is to identify extreme price levels. High positive values (e.g., above +1.5) are considered overbought, and high negative values (e.g., below -1.5) are considered oversold.
* **Crossovers:**
  * **Fisher / Signal Line Crossover:** When the Fisher line (blue) crosses above its signal line (orange), it can be considered a buy signal. When it crosses below, it's a sell signal.
  * **Zero Line Crossover:** A crossover of the Fisher line above the zero line can also be interpreted as a bullish signal, and a cross below as bearish.
* **Divergence:** Look for divergences between the Fisher Transform and the price action. A bearish divergence (higher price highs, lower Fisher highs) can signal a potential top, while a bullish divergence (lower price lows, higher Fisher lows) can signal a potential bottom.
* **Caution:** The Fisher Transform is a very fast-reacting oscillator and can produce many signals. It is often recommended to wait for the Fisher line to form a clear peak or trough beyond the extreme levels before acting on a signal.
