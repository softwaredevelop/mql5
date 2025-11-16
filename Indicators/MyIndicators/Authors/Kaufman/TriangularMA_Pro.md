# Triangular Moving Average (TMA) Professional

## 1. Summary (Introduction)

The Triangular Moving Average (TMA) is a specialized, double-smoothed moving average. Its primary purpose is to provide a very smooth, noise-resistant trendline by giving the most weight to the data in the middle of its lookback period, and linearly decreasing the weight towards the beginning and end of the period.

Unlike an EMA or LWMA, which prioritize the most recent prices, the TMA is not designed for fast trend-following or quick signal generation. Instead, it excels at:

* **Filtering out market noise** to an extreme degree.
* Identifying the underlying, **long-term cyclical centerline** of the market.

Due to its heavy smoothing, it has a more significant lag than other moving average types of the same period.

## 2. Mathematical Foundations and Calculation Logic

The TMA is most commonly and efficiently calculated as a **double-smoothed Simple Moving Average (SMA)**. This two-step process automatically creates the desired triangular weighting scheme.

### Required Components

* **TMA Period (N):** The total lookback period for the calculation.
* **Source Price (P):** The price series for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the First SMA:** First, a Simple Moving Average (`SMA₁`) is calculated with a period of `N₁`.
    * $N_1 = \text{Ceiling}(\frac{N + 1}{2})$
    * $\text{SMA}_{1_t} = \text{SMA}(P, N_1)_t$

2. **Calculate the Second SMA (the TMA):** The final TMA is a second Simple Moving Average (`SMA₂`) calculated on the results of the first SMA, with a period of `N₂`.
    * $N_2 = \text{Floor}(\frac{N + 1}{2})$ (Note: In our code, for an N-period TMA, the second SMA period is `N - N₁ + 1` which yields the same result)
    * $\text{TMA}_t = \text{SMA}(\text{SMA}_1, N_2)_t$

This double-smoothing process naturally gives the highest weight to the price data in the center of the total lookback window `N`.

## 3. MQL5 Implementation Details

* **Universal Calculation Engine (`MovingAverage_Engine.mqh`):** The TMA functionality is seamlessly integrated into our universal moving average engine. This ensures that it benefits from the same robust data preparation (including Heikin Ashi support) and stable calculation framework as our other core moving averages.

* **Dedicated Wrapper (`TriangularMA_Pro.mq5`):** This indicator is a clean, dedicated "wrapper" that specifically calls the universal engine with the `TMA` type. This provides a simple, user-friendly interface for traders who want to use the TMA without navigating the options of the full `MovingAverage_Pro` indicator.

* **Efficient Calculation:** The implementation in our engine uses the efficient double-SMA method to calculate the TMA values.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the Triangular Moving Average.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The TMA should be used as a long-term filter and centerline, not as a fast signal generator.

* **Comparison to Other MAs:**
  * **TMA vs. SMA/EMA:** The TMA is significantly **smoother** and has **more lag** than an SMA or EMA of the same period. It will turn much later after a trend change.

* **Primary Use - Long-Term Trend Filter:** The slope of the TMA provides a very clear, noise-free indication of the market's primary direction. It is excellent for establishing a long-term bias (e.g., only take long trades when the price is above a rising TMA).

* **Mean Reversion and Cyclical Analysis:** Because the TMA represents a smoothed-out "center of gravity" for the price, significant deviations from it can be interpreted as overextended moves.
  * When the price moves far above the TMA, it can be considered "overbought" relative to its mean, suggesting a potential pullback towards the TMA.
  * When the price moves far below the TMA, it can be considered "oversold," suggesting a potential bounce back towards the TMA.

* **Not for Crossovers:** Due to its significant lag, using price crossovers of the TMA for entry signals is generally not recommended as it will often be too late. It is better used as a contextual tool in combination with faster oscillators.
