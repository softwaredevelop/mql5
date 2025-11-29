# Moving Average Ribbon Pro

## 1. Summary (Introduction)

The `MovingAverage_Ribbon_Pro` is a powerful and highly customizable visual tool for analyzing trend direction, strength, and momentum. It consists of four independent moving average lines, creating a "ribbon" that expands and contracts based on the market's movement.

This indicator offers maximum flexibility, allowing the user to **independently configure the period and type** for each of the four moving average lines. This enables the creation of complex ribbon strategies, such as those based on Fibonacci sequences or a mix of different MA types (e.g., combining fast EMAs with a slow SMA).

As part of our professional indicator suite, it fully supports calculations on both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a "meta-indicator" built upon the seven fundamental and advanced moving average types supported by our engine:

* **SMA** (Simple Moving Average)
* **EMA** (Exponential Moving Average)
* **SMMA** (Smoothed Moving Average)
* **LWMA** (Linear Weighted Moving Average)
* **TMA** (Triangular Moving Average)
* **DEMA** (Double Exponential Moving Average)
* **TEMA** (Triple Exponential Moving Average)

The core concept of a moving average ribbon is to visualize the relationship between multiple moving averages of different lengths.

* **Trend Direction:** When all lines are parallel and sloping in the same direction, the trend is strong.
* **Trend Strength:** The width of the ribbon (the distance between the fastest and slowest MAs) indicates the strength of the momentum. A widening ribbon signals accelerating momentum, while a contracting ribbon signals decelerating momentum.
* **Trend Changes:** Crossovers and "twists" within the ribbon can signal potential trend changes or periods of consolidation.

## 3. MQL5 Implementation Details

* **Modular and Composite Design:** The indicator's engine (`MovingAverage_Ribbon_Calculator.mqh`) is a prime example of the composition design pattern. It **contains four independent instances** of our universal `CMovingAverageCalculator` class. Each instance is responsible for calculating one line of the ribbon.

* **Optimized Incremental Calculation:**
    Despite managing four separate calculations simultaneously, the indicator remains extremely efficient.
  * Each of the four internal calculators tracks its own state and utilizes the `prev_calculated` optimization.
  * **Persistent State:** The internal buffers for recursive calculations (EMA, SMMA, DEMA, TEMA) persist between ticks for each line independently.
  * This ensures that the indicator runs with **O(1) complexity** per tick, updating all four lines instantly without re-processing history.

* **Maximum Reusability:** This architecture leverages our existing, robust `MovingAverage_Engine.mqh` without modification. The ribbon calculator acts as a "manager" that simply delegates the calculation for each line to a specialized, single-MA calculator.

* **Full Customization:** The `Init` method of the ribbon calculator accepts eight parameters (four periods and four MA types), allowing each of the four internal MA calculators to be configured independently.

* **Object-Oriented Design (Inheritance):** A "Factory Method" (`CreateMAInstance`) is used to instantiate the correct type of the underlying `CMovingAverageCalculator` (`standard` or `_HA`), ensuring seamless Heikin Ashi integration.

## 4. Parameters

The indicator's inputs are organized into four groups, one for each moving average line.

* **MA 1-4 Settings:**
  * **`InpPeriod1` - `InpPeriod4`:** The lookback period for each of the four moving average lines.
  * **`InpMAType1` - `InpMAType4`:** A dropdown menu to select the MA type (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA) for each line independently.
* **Price Source:**
  * **`InpSourcePrice`:** The source price for all calculations (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MA Ribbon provides a rich, at-a-glance view of the market's state.

* **Identifying Strong Trends:** A strong trend is characterized by a **wide, smoothly angled ribbon** where all four lines are parallel and perfectly ordered (fastest on top in an uptrend, fastest on the bottom in a downtrend). The price should stay consistently on one side of the entire ribbon.

* **Identifying Trend Weakness / Consolidation:** When the ribbon **flattens out and contracts** (the lines get closer together and start to cross over each other), it signals that momentum is fading and the market is entering a consolidation or ranging phase.

* **Entry Signals (Pullbacks):** In a strong trend, a pullback of the price towards the "edge" of the ribbon (the faster MAs) can present a high-probability trend-following entry opportunity.

* **Reversal Signals:** A full "flip" of the ribbon, where all lines cross over and re-order themselves in the opposite direction, is a strong signal of a major trend reversal.
