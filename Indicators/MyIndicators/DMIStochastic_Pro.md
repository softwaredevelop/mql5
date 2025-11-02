# DMI Stochastic Professional

## 1. Summary (Introduction)

The DMI Stochastic, developed by Barbara Star and featured in the Stocks and Commodities Magazine (January 2013), is an innovative oscillator that combines two powerful concepts: J. Welles Wilder's Directional Movement Index (DMI) and the Stochastic Oscillator.

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

* **Modular Calculator Engine (`DMIStochastic_Calculator.mqh`):** All mathematical logic is encapsulated in a dedicated include file. This engine manages all intermediate calculations (DM, TR, DI, DMI Oscillator, Fast %K) internally.

* **Reusable MA Helper Function:** To avoid code duplication, the calculator contains a private `CalculateMA` helper function. This function holds the logic for all supported moving average types (SMA, EMA, etc.) and is called to smooth both the %K and %D lines, promoting clean and maintainable code.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CDMIStochasticCalculator`, handles the entire calculation chain.
  * A derived class, `CDMIStochasticCalculator_HA`, overrides the `PreparePriceSeries` virtual method. Its sole responsibility is to calculate and provide Heikin Ashi High, Low, and Close values as the source data for the first step of the calculation.

* **Simplified Main Indicator (`DMIStochastic_Pro.mq5`):** The main `.mq5` file acts as a clean "wrapper" responsible for handling user inputs, creating the correct calculator object, and delegating the calculation with a single function call in `OnCalculate()`.

* **Stability via Full Recalculation:** The indicator performs a full recalculation on every tick to ensure maximum stability and prevent artifacts, which is the most robust approach for multi-stage indicators.

## 4. Parameters (`DMIStochastic_Pro.mq5`)

* **Candle Source (`InpCandleSource`):** Selects the candle type for the initial DMI calculation.
  * `CANDLE_STANDARD`: Uses standard OHLC data.
  * `CANDLE_HEIKIN_ASHI`: Uses smoothed Heikin Ashi data.
* **Oscillator Formula (`InpOscType`):** Determines the formula for the internal DMI Oscillator.
  * `OSC_PDI_MINUS_NDI`: High values represent bullish pressure (recommended, intuitive).
  * `OSC_NDI_MINUS_PDI`: High values represent bearish pressure (original definition).
* **DMI Period (`InpDMIPeriod`):** The lookback period for the underlying +DI and -DI calculation. Default is `10`.
* **Stochastic %K Period (`InpFastKPeriod`):** The lookback period for finding the highest/lowest values of the DMI Oscillator. Default is `10`.
* **Stochastic %K Slowing (`InpSlowKPeriod`):** The period for the first smoothing of the raw %K line. Default is `3`.
* **Stochastic %D Period (`InpSmoothPeriod`):** The period for smoothing the main %K line to create the signal line. Default is `3`.
* **MA Method for Stochastic (`InpStochMethod`):** The type of moving average to use for both the %K slowing and %D smoothing steps. Default is `SMA`.

## 5. Usage and Interpretation

The DMI Stochastic should be interpreted as a **momentum-of-momentum** oscillator. It shows when the bullish or bearish *pressure* is overextended. (Assuming default `PDI - NDI` formula).

* **Overbought/Oversold Momentum:**
  * **Values > 80 (Overbought):** Indicates that bullish pressure has been extremely strong and dominant. This may signal that the bullish move is exhausted and a bearish reversal or consolidation is imminent.
  * **Values < 20 (Oversold):** Indicates that bearish pressure has been extremely strong. This may signal that the bearish move is exhausted and a bullish reversal or consolidation is likely.
* **Crossovers:**
  * When the **%K line (blue) crosses above the %D line (red)**, it signals a bullish shift in directional momentum.
  * When the **%K line (blue) crosses below the %D line (red)**, it signals a bearish shift in directional momentum.
* **Trade Confirmation:** High-probability signals often occur when both conditions are met. For example, a potential short signal is generated when the oscillator is in the overbought zone (>80) and the %K line crosses below the %D line. This confirms both the overextended bullish condition and the beginning of a bearish momentum shift.
