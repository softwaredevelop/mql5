# Fisher Transform

## 1. Summary (Introduction)

The Fisher Transform is a technical indicator created by J.H. Ehlers that converts price into a Gaussian normal distribution. The primary purpose of this transformation is to create sharp, clear turning points that are less prone to the lag and ambiguity of many other oscillators.

The indicator consists of two lines: the Fisher line and a signal line (which is typically the Fisher line's value from the previous bar). It is an unbound oscillator, meaning its values can theoretically extend to infinity, but in practice, it tends to fluctuate around a zero line. Extreme readings suggest that a price reversal is more likely.

## 2. Mathematical Foundations and Calculation Logic

The Fisher Transform uses a mathematical formula to normalize price data, making extreme price moves more apparent.

### Required Components

- **Period (N):** The lookback period for finding the highest and lowest prices.
- **Source Price:** The indicator typically uses the median price `(High + Low) / 2` as its input.

### Calculation Steps (Algorithm)

1. **Transform Price to a Level between -1 and +1:** First, the source price is converted into a value that fluctuates primarily between -1 and +1. This is done by determining the price's position within its highest and lowest range over the last `N` periods.

   - $\text{Price Position}_i = \frac{\text{Source Price}_i - \text{Lowest Price}_{N}}{\text{Highest Price}_{N} - \text{Lowest Price}_{N}} - 0.5$
   - This value is then smoothed, often with a weighted or exponential moving average. The classic formula uses a specific recursive smoothing:
     $\text{Value}_i = (0.33 \times 2 \times \text{Price Position}_i) + (0.67 \times \text{Value}_{i-1})$
   - The resulting `Value` is clamped to a range just inside -1 and +1 (e.g., -0.999 to 0.999) to avoid mathematical errors in the next step.

2. **Apply the Fisher Transform:** The core of the indicator is the application of the Fisher Transform formula to the smoothed `Value` from the previous step.
   $\text{Fisher}_i = 0.5 \times \ln\left(\frac{1 + \text{Value}_i}{1 - \text{Value}_i}\right)$
   Where `ln` is the natural logarithm.

3. **Final Smoothing and Signal Line:** The resulting Fisher value is often smoothed again with its own previous value to create the final, plotted line. The signal line is simply the Fisher line from the previous bar.
   $\text{Final Fisher}_i = \text{Fisher}_i + (0.5 \times \text{Final Fisher}_{i-1})$
   $\text{Signal}_i = \text{Final Fisher}_{i-1}$

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored to be highly robust, especially concerning the multiple recursive calculations involved.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This is our standard practice for indicators with recursive logic to ensure maximum stability and prevent calculation errors.

- **Robust Initialization:** This is the most critical part of the implementation. The final, recursive calculation of the `BufferFisher` line is highly susceptible to floating-point overflows if not initialized correctly. Our code explicitly handles this:

  - The **first valid value** of the `BufferFisher` line is calculated **without** the recursive component (`+ 0.5 * BufferFisher[i-1]`).
  - All subsequent values are then calculated using the full recursive formula, ensuring the calculation chain starts with a stable, valid number.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into two clear, sequential steps:

  1. **Step 1:** A `for` loop prepares the source price data (`hl2`) for the main calculation.
  2. **Step 2:** A single, efficient `for` loop handles the entire Fisher Transform calculation, including the smoothing of the intermediate `Value` buffer and the final, robustly initialized `BufferFisher` calculation.

- **Heikin Ashi Variant (`FisherTransform_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high` and `ha_low` values to calculate the source price.
  - This results in a significantly smoother oscillator, as the input data itself is already filtered, which can help in identifying more significant, underlying momentum shifts.

## 4. Parameters

- **Length (`InpLength`):** The lookback period for finding the highest and lowest prices. A shorter period results in a more sensitive, faster-reacting oscillator, while a longer period creates a smoother, slower line. Default is `9`.

## 5. Usage and Interpretation

- **Identifying Extremes:** The primary use of the Fisher Transform is to identify extreme price levels that may signal an impending reversal. High positive values (e.g., above +1.5) are considered overbought, and high negative values (e.g., below -1.5) are considered oversold.
- **Crossovers:**
  - **Fisher / Signal Line Crossover:** When the Fisher line (blue) crosses above its signal line (orange), it can be considered a buy signal. When it crosses below, it's a sell signal. These are the most common signals generated by the indicator.
  - **Zero Line Crossover:** A crossover of the Fisher line above the zero line can also be interpreted as a bullish signal, and a cross below as bearish, though these are less common.
- **Divergence:** Look for divergences between the Fisher Transform and the price action. A bearish divergence (higher price highs, lower Fisher highs) can signal a potential top, while a bullish divergence (lower price lows, higher Fisher lows) can signal a potential bottom.
- **Caution:** The Fisher Transform is a very fast-reacting oscillator and can produce many signals. It is often recommended to wait for the Fisher line to form a clear peak or trough beyond the extreme levels before acting on a signal, rather than trading every crossover.
