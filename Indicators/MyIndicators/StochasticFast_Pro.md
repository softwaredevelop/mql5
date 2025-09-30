# Fast Stochastic Professional

## 1. Summary (Introduction)

The Fast Stochastic Oscillator, developed by George C. Lane, is a momentum indicator that compares a closing price to its price range over a period. It is the original, un-smoothed version of the Stochastic oscillator.

The indicator consists of two lines:

* **%K Line:** The "raw" stochastic value, which is highly sensitive to price changes.
* **%D Line:** A moving average of the %K line, which acts as a signal line.

Because it lacks the extra smoothing layer of the "Slow" version, the Fast Stochastic is much more responsive but also more prone to generating false signals ("whipsaws") in choppy markets.

Our `StochasticFast_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The Fast Stochastic's %K line is the raw calculation, and the %D line is its direct moving average.

### Required Components

* **%K Period:** The main lookback period for the Stochastic calculation.
* **%D Period & MA Method:** The period and type of moving average for the signal line.
* **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate the %K Line (Fast %K):** This is the core of the Stochastic calculation. It measures where the current close is relative to the price range over the `%K Period`.
    $\text{\%K}_t = 100 \times \frac{\text{Close}_t - \text{Lowest Low}_{\%K \text{ Period}}}{\text{Highest High}_{\%K \text{ Period}} - \text{Lowest Low}_{\%K \text{ Period}}}$

2. **Calculate the %D Line (Signal Line):** The signal line is a moving average of the %K line, using the selected `%D MA Method` and `%D Period`.
    $\text{\%D}_t = \text{MA}(\text{\%K}, \text{\%D Period}, \text{\%D MA Method})_t$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a robust, unified indicator built on a modular, object-oriented framework.

* **Modular Calculation Engine (`StochasticFast_Calculator.mqh`):**
    The entire calculation logic for both standard and Heikin Ashi versions is encapsulated within a single, powerful include file.
  * An elegant, object-oriented inheritance model (`CStochasticFastCalculator` and `CStochasticFastCalculator_HA`) allows the main indicator file to dynamically choose the correct calculation engine at runtime based on user input, eliminating code duplication.

* **Full MA Type Support:** The calculator contains a complete, robust implementation for all standard MQL5 MA types (SMA, EMA, SMMA, LWMA) for the "%D" signal line smoothing.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` to ensure that the multi-stage calculation remains stable and accurate.

## 4. Parameters

* **%K Period (`InpKPeriod`):** The lookback period for the initial Stochastic calculation. Default is `14`.
* **%D Period (`InpDPeriod`):** The smoothing period for the final signal line (%D). Default is `3`.
* **%D MA Type (`InpDMAType`):** The type of moving average used for the "%D" step. Default is `MODE_SMA`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
* **Crossovers:** The crossover of the %K line and the %D signal line is a common trade signal. Due to the indicator's sensitivity, these signals will be more frequent than with the Slow Stochastic.
* **Divergence:** Look for divergences between the Stochastic and the price action.
* **Using Heikin Ashi:** Selecting the Heikin Ashi option results in a smoother oscillator, which can help mitigate some of the inherent "choppiness" of the Fast Stochastic.
* **Caution:** The Fast Stochastic is a very sensitive, range-bound oscillator. It generates many signals and is highly susceptible to market noise. It is often used by short-term traders or as a component in a larger system rather than as a standalone signal generator. Many traders prefer the smoother signals of the Slow Stochastic.
