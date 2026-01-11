# DMI Stochastic Professional

## 1. Summary (Introduction)

The DMI Stochastic, developed by Barbara Star, is an innovative oscillator that combines two powerful concepts: J. Welles Wilder's Directional Movement Index (DMI) and the Stochastic Oscillator.

Instead of analyzing the price, this indicator measures the **momentum of the underlying directional pressure** in the market. It does this by first creating an oscillator from the difference between the Positive (+DI) and Negative (-DI) Directional Indicators, and then feeding this new value series into a standard Stochastic calculation.

The result is an oscillator that identifies overbought and oversold conditions in bullish or bearish momentum itself, providing unique insights into potential trend exhaustion and reversals.

Our `DMIStochastic_Pro` implementation is a professional version that includes:

* Calculation based on either **standard** or **Heikin Ashi** candles.
* A user-selectable formula for the internal DMI Oscillator for more intuitive use.

## 2. Mathematical Foundations and Calculation Logic

The calculation is a three-stage process: first building the DMI components, then creating the DMI Oscillator, and finally applying the Stochastic formula.

### Required Components

* **DMI Period (N):** The lookback period for the DMI calculation (e.g., 10).
* **Stochastic Periods:** Fast %K Period, Slowing Period, and %D Period.

### Calculation Steps (Algorithm)

1. **Calculate Directional Indicators (+DI, -DI):** This initial step is identical to the standard ADX calculation.
    * First, the raw Directional Movement (+DM, -DM) and True Range (TR) are calculated for each bar.
    * These three series are then smoothed using Wilder's method (SMMA/RMA) over the DMI Period `N`.
    * Finally, the +DI and -DI lines are calculated:
        $\text{+DI}_i = 100 \times \frac{\text{Smoothed +DM}_i}{\text{Smoothed TR}_i}$
        $\text{-DI}_i = 100 \times \frac{\text{Smoothed -DM}_i}{\text{Smoothed TR}_i}$

2. **Create the DMI Oscillator:** This is the core of the indicator. An oscillator is created from the difference between the two directional indicators. Our implementation allows for two formulas:
    * **Intuitive (Default):** $\text{DMI Oscillator}_i = \text{+DI}_i - \text{-DI}_i$
        *(High values indicate strong bullish pressure)*
    * **Original:** $\text{DMI Oscillator}_i = \text{-DI}_i - \text{+DI}_i$
        *(High values indicate strong bearish pressure)*

3. **Apply the Slow Stochastic Formula:** The `DMI Oscillator` series is now used as the input for a standard Slow Stochastic calculation.
    * **Calculate Fast %K:**
        $\text{Highest High} = \text{Highest value of DMI Oscillator over the Fast \%K Period}$
        $\text{Lowest Low} = \text{Lowest value of DMI Oscillator over the Fast \%K Period}$
        $\text{Fast \%K} = 100 \times \frac{\text{DMI Oscillator}_i - \text{Lowest Low}}{\text{Highest High} - \text{Lowest Low}}$
    * **Calculate Slow %K (Main Line):** The `Fast %K` series is smoothed using the selected moving average type over the `Slowing Period`.
        $\text{Slow \%K} = \text{MA}(\text{Fast \%K}, \text{Slowing Period})$
    * **Calculate %D (Signal Line):** The `Slow %K` series is smoothed again using the selected moving average type over the `%D Period`.
        $\text{\%D} = \text{MA}(\text{Slow \%K}, \text{\%D Period})$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows the same modern, object-oriented design as our other professional indicators.

* **Shared Core Engine (`DMI_Engine.mqh`):**
    Just like the ADX Pro, this indicator leverages the shared `DMI_Engine` to perform the initial heavy lifting (calculating +DI and -DI). This guarantees mathematical consistency across the suite.

* **Modular Calculation Engine (`DMIStochastic_Calculator.mqh`):**
    This engine acts as a coordinator. It:
    1. Delegates the DMI calculation to the `DMI_Engine`.
    2. Calculates the DMI Oscillator from the engine's output.
    3. Delegates the Stochastic smoothing to two instances of the `MovingAverage_Engine`.

* **Engine Integration:**
    The calculator internally uses two instances of our universal `MovingAverage_Engine.mqh` to handle the smoothing of the Slow %K and the %D Signal Line. This allows for advanced smoothing types (like DEMA or TEMA) beyond the standard SMA.

* **Optimized Incremental Calculation (O(1)):**
    The entire chain of engines (DMI Engine -> DMI Stoch Calculator -> MA Engines) is fully optimized for incremental calculation using `prev_calculated`. State is preserved across all layers.

* **Object-Oriented Design:**
  * The Heikin Ashi version (`CDMIStochasticCalculator_HA`) works by injecting the Heikin Ashi version of the DMI Engine (`CDMIEngine_HA`) into the calculation pipeline.

## 4. Parameters

* **Candle Source (`InpCandleSource`):** Selects the candle type for the initial DMI calculation.
  * `CANDLE_STANDARD`: Uses standard OHLC data.
  * `CANDLE_HEIKIN_ASHI`: Uses smoothed Heikin Ashi data.
* **Oscillator Formula (`InpOscType`):** Determines the formula for the internal DMI Oscillator.
  * `OSC_PDI_MINUS_NDI`: High values represent bullish pressure (recommended, intuitive).
  * `OSC_NDI_MINUS_PDI`: High values represent bearish pressure (original definition).
* **DMI Period (`InpDMIPeriod`):** The lookback period for the underlying +DI and -DI calculation. (Default: `10`).
* **Stochastic %K Period (`InpFastKPeriod`):** The lookback period for finding the highest/lowest values of the DMI Oscillator. (Default: `10`).
* **Stochastic %K Slowing (`InpSlowKPeriod`):** The period for the first smoothing of the raw %K line. (Default: `3`).
* **Stochastic %D Period (`InpSmoothPeriod`):** The period for smoothing the main %K line to create the signal line. (Default: `3`).
* **MA Method for Stochastic (`InpStochMethod`):** The type of moving average to use for the %K slowing step. (Default: `SMA`).
* **MA Method for Signal (`InpSignalMethod`):** The type of moving average to use for the %D smoothing step. (Default: `SMA`).

## 5. Usage and Interpretation

The DMI Stochastic should be interpreted as a **momentum-of-momentum** oscillator. It shows when the bullish or bearish *pressure* is overextended. (Assuming default `PDI - NDI` formula).

* **Overbought/Oversold Momentum:**
  * **Values > 80 (Overbought):** Indicates that bullish pressure has been extremely strong and dominant. This may signal that the bullish move is exhausted and a bearish reversal or consolidation is imminent.
  * **Values < 20 (Oversold):** Indicates that bearish pressure has been extremely strong. This may signal that the bearish move is exhausted and a bullish reversal or consolidation is likely.
* **Crossovers:**
  * When the **%K line (blue) crosses above the %D line (red)**, it signals a bullish shift in directional momentum.
  * When the **%K line (blue) crosses below the %D line (red)**, it signals a bearish shift in directional momentum.
