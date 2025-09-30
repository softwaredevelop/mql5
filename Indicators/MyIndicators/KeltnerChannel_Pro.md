# Keltner Channel Professional

## 1. Summary (Introduction)

The Keltner Channel is a volatility-based indicator, with the modern version popularized by Linda Bradford Raschke. It consists of three lines: a central moving average line, an upper band, and a lower band, with the channel width determined by the Average True Range (ATR). It is primarily used to identify trend direction and spot potential breakouts.

Our `KeltnerChannel_Pro` implementation is a unified, professional version that combines three distinct calculation methodologies into a single, flexible indicator:

1. **Standard:** Classic Keltner Channel using standard price data for both the MA and ATR.
2. **HA-Hybrid:** A smoothed MA based on Heikin Ashi prices, with channel width based on standard, real-market ATR.
3. **HA-Pure:** A fully smoothed channel where both the MA and the ATR are calculated from Heikin Ashi data.

## 2. Mathematical Foundations and Calculation Logic

The Keltner Channel is constructed by creating a channel around a central moving average, with the width determined by market volatility.

### Required Components

* **Middle Line (Basis):** A moving average of a selected price.
* **ATR (Average True Range):** A measure of market volatility.
* **Factor (Multiplier):** A user-defined multiplier that adjusts the channel width.

### Calculation Steps (Algorithm)

1. **Calculate the Middle Line:** Compute the moving average (e.g., 20-period EMA) of the selected source price.
    $\text{Middle Line}_i = \text{MA}(\text{Source Price}, \text{MA Period})_i$

2. **Calculate the Average True Range (ATR):** Compute the ATR for a given period (e.g., 10).

3. **Calculate the Upper and Lower Bands:** Add and subtract a multiple of the ATR from the middle line.
    $\text{Upper Band}_i = \text{Middle Line}_i + (\text{Factor} \times \text{ATR}_i)$
    $\text{Lower Band}_i = \text{Middle Line}_i - (\text{Factor} \times \text{ATR}_i)$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`KeltnerChannel_Calculator.mqh`):**
    The entire calculation logic for all three modes is encapsulated within a single, powerful include file.
  * **`CKeltnerChannelCalculator`**: The base class that performs the full calculation. It handles the MA calculation and the final band construction.
  * **`CKeltnerChannelCalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use Heikin Ashi prices for the middle line MA.
  * **ATR Source Logic:** The calculator internally checks the `InpAtrSource` parameter and decides whether to calculate the True Range from standard candles or from Heikin Ashi candles, providing all three logical variations within a clean, unified structure.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

* **Fully Manual Calculations:** To guarantee 100% accuracy and consistency, all moving average and ATR calculations are performed **manually** within the calculator engine.

## 4. Parameters

The indicator's parameters are logically grouped for clarity:

* **Middle Line (MA) Settings:**
  * `InpMaPeriod`: The lookback period for the middle line. Default is `20`.
  * `InpMaMethod`: The type of moving average for the middle line. Default is `MODE_EMA`.
  * `InpSourcePrice`: The source price for the middle line. This unified dropdown allows you to select from all standard and Heikin Ashi price types.
* **Channel (ATR) Settings:**
  * `InpAtrPeriod`: The lookback period for the ATR calculation. Default is `10`.
  * `InpMultiplier`: The factor to multiply the ATR by. Default is `2.0`.
  * `InpAtrSource`: Determines the source for the ATR calculation (`Standard` or `Heikin Ashi`), allowing you to create "Hybrid" or "Pure" HA channels.

## 5. Usage and Interpretation

* **Trend Identification:** The slope of the channel helps identify the trend. An upward-sloping channel suggests an uptrend, while a downward-sloping one suggests a downtrend.
* **Breakouts:** A strong close above the upper band can signal the start or continuation of an uptrend. A strong close below the lower band can signal the start or continuation of a downtrend.
* **Overbought/Oversold (in Ranges):** In a sideways market, moves to the upper band can be seen as overbought, and moves to the lower band can be seen as oversold.
* **Caution:** Like all channel indicators, Keltner Channels can give false breakout signals. It is often used in conjunction with momentum oscillators to confirm the strength of a move.
