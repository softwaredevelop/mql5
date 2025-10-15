# Aroon Professional

## 1. Summary (Introduction)

The Aroon indicator, developed by Tushar Chande in 1995, is a technical analysis tool used to identify whether a security is trending and to measure the **freshness or age of that trend**. Unlike momentum oscillators that measure the magnitude of price changes, Aroon's core concept is based on **time relative to price**. It measures the number of periods that have passed since price recorded a new high or low within the lookback period.

The name "Aroon" is Sanskrit for "Dawn's Early Light," highlighting its purpose of detecting the beginning of new trends.

The system consists of two lines:

* **Aroon Up:** Measures the time since the last N-period high. A high value indicates a "fresh" uptrend.
* **Aroon Down:** Measures the time since the last N-period low. A high value indicates a "fresh" downtrend.

Our `Aroon_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** candles.

## 2. Mathematical Foundations and Calculation Logic

The Aroon calculation is a straightforward, non-recursive process based on finding the highest high and lowest low over a sliding window of time.

### Required Components

* **Aroon Period (N):** The lookback period for the calculation (e.g., 25).

### Calculation Steps (Algorithm)

For each bar, the indicator performs the following steps:

1. **Identify the Lookback Window:** Define the period of the last `N` bars, including the current bar.

2. **Find the Highest High:** Within this window, find the bar with the absolute highest high price.

3. **Count Bars Since High:** Calculate the number of bars that have passed between the current bar and the bar where the highest high occurred. Let's call this `BarsSinceHigh`. If the high is on the current bar, this value is 0.

4. **Calculate Aroon Up:** Apply the Aroon formula:
    $\text{Aroon Up} = \frac{N - \text{BarsSinceHigh}}{N} \times 100$

5. **Find the Lowest Low:** Within the same `N`-bar window, find the bar with the absolute lowest low price.

6. **Count Bars Since Low:** Calculate the number of bars that have passed since the lowest low occurred (`BarsSinceLow`).

7. **Calculate Aroon Down:** Apply the corresponding formula:
    $\text{Aroon Down} = \frac{N - \text{BarsSinceLow}}{N} \times 100$

### The "Sawtooth" Pattern Explained

The characteristic linearly declining, "sawtooth" appearance of the Aroon lines is a direct and intended result of its time-based formula. After a new high is made (`BarsSinceHigh = 0`, `Aroon Up = 100`), for every subsequent bar where a new high is *not* made, the `BarsSinceHigh` value increases by one, causing the `Aroon Up` value to decrease by a fixed amount (`100 / N`). This continues until a new high is formed within the period, at which point the line jumps back to 100.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design pattern to ensure stability, reusability, and maintainability.

* **Modular Calculator Engine (`Aroon_Calculator.mqh`):**
    All core calculation logic is encapsulated within a reusable include file. This separates the mathematical complexity from the indicator's user interface and buffer management. The logic cleanly implements the "sliding window" search for highs and lows.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CAroonCalculator`, handles the entire shared calculation logic.
  * A derived class, `CAroonCalculator_HA`, inherits from the base class and **overrides** only one specific function: `PrepareSourceData`. Its sole responsibility is to calculate and provide Heikin Ashi high/low data to the base class's calculation engine, which then proceeds without needing to know the source of the data. This is a clean and efficient use of polymorphism.

* **Simplified Main Indicator (`Aroon_Pro.mq5`):**
    The main indicator file is extremely clean. Its primary roles are:
    1. Handling user inputs (`input` variables).
    2. Setting fixed window boundaries (`#property indicator_minimum 0`, `#property indicator_maximum 100`) for correct visualization.
    3. Instantiating the correct calculator object (`CAroonCalculator` or `CAroonCalculator_HA`) in `OnInit()`.
    4. Delegating the entire calculation process to the calculator object with a single call in `OnCalculate()`.

* **Stability via Full Recalculation:** We use a full recalculation on every tick. For a state-dependent indicator like Aroon, this "brute-force" approach is the most robust method, ensuring perfect synchronization with the price data at all times.

## 4. Parameters (`Aroon_Pro.mq5`)

* **Aroon Period (`InpPeriodAroon`):** The lookback period (`N`) used for the calculation. The default value is `25`, as used in many platforms, but `14` is also a very common choice.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for finding highs and lows.
  * `CANDLE_STANDARD`: Uses the standard chart's OHLC data.
  * `CANDLE_HEIKIN_ASHI`: Uses smoothed Heikin Ashi data.

## 5. Usage and Interpretation

Aroon is used to answer the questions: "Is there a trend?" and "If so, how new is it?".

* **Trend Identification (Levels):**
  * **Aroon Up > 70:** Suggests a strong, fresh uptrend.
  * **Aroon Down > 70:** Suggests a strong, fresh downtrend.
  * **Both lines below 30 (or 50):** Suggests the market is consolidating or in a range, as no new highs or lows have been made recently.

* **Crossovers:**
  * When the **Aroon Up line (green) crosses above the Aroon Down line (red)**, it signals potential bullish strength.
  * When the **Aroon Down line (red) crosses above the Aroon Up line (green)**, it signals potential bearish strength.

* **Extreme Readings (100):**
  * When Aroon Up hits 100, it confirms that a new high for the period was just made. This is a sign of strong bullish momentum.
  * When Aroon Down hits 100, it confirms a new low for the period was just made, signaling strong bearish momentum.

* **Parallel Movement:** When both lines move downwards in a relatively parallel fashion, it often indicates that the market is consolidating and the previous trend is aging. Traders often watch for a breakout following this pattern.
