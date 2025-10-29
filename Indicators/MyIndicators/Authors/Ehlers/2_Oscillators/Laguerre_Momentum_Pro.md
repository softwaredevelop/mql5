# Laguerre Momentum Professional

## 1. Summary (Introduction)

> **Part of the Laguerre Indicator Family**
>
> This indicator is a member of a family of tools based on John Ehlers' Laguerre filter.
>
> * [Laguerre Filter Pro](./Laguerre_Filter_Pro.md): A fast, responsive moving average.
> * [Laguerre RSI Pro](./Laguerre_RSI_Pro.md): A smooth, noise-filtered momentum oscillator.
> * **Laguerre Momentum Pro:** A Laguerre-smoothed oscillator of the bar-by-bar momentum.

The Laguerre Momentum Pro is an oscillator that applies the powerful, low-lag **Laguerre Filter** to a **momentum source (Close - Open)** instead of the price.

While the standard `Laguerre_Filter_Pro` provides a smoothed representation of the trend, this indicator isolates and smooths the raw bar-by-bar momentum. The `gamma` parameter allows the user to precisely control the trade-off between responsiveness and smoothness of the final oscillator.

The result is a flexible, zero-mean oscillator that can be tuned to identify the underlying strength and direction of price velocity.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a Laguerre-filtered average of the `Close - Open` value of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Momentum Source:** For each bar, the source data is calculated as `Momentum = Close - Open`.
2. **Apply Laguerre Filter:** A full, weighted Laguerre Filter is calculated on this `Momentum` data series, using the user-defined `gamma` to control the smoothing.

## 3. MQL5 Implementation Details

* **Unified Engine (`Laguerre_Engine.mqh`):** This indicator uses the exact same, powerful calculation engine as the `Laguerre_Filter_Pro` and `Laguerre_RSI_Pro`. The only difference is that it is initialized in `SOURCE_MOMENTUM` mode.
* **Heikin Ashi Integration:** The indicator fully supports calculation on smoothed Heikin Ashi data (`HA Close - HA Open`).
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure the stateful, recursive calculation is always stable.

## 4. Parameters

* **Gamma (`InpGamma`):** The Laguerre filter coefficient (0.0 to 1.0). This parameter controls the indicator's speed and smoothness.
  * **High Gamma (e.g., 0.7 - 0.9):** Results in a **slower, smoother** oscillator.
  * **Low Gamma (e.g., 0.1 - 0.3):** Results in a **faster, more volatile** oscillator.
* **Candle Source (`InpCandleSource`):** Selects between `Standard` and `Heikin Ashi` candles for the `Close - Open` calculation.

## 5. Usage and Interpretation

The Laguerre Momentum is a classic zero-mean oscillator used for identifying momentum shifts and potential reversals.

### Standalone Usage

* **Zero-Line Crossover:**
  * A cross **above the zero line** indicates that bullish momentum is taking control.
  * A cross **below the zero line** indicates that bearish momentum is dominant.
* **Divergence:**
  * **Bullish Divergence:** Price makes a **new lower low**, but the Laguerre Momentum makes a **higher low**.
  * **Bearish Divergence:** Price makes a **new higher high**, but the Laguerre Momentum makes a **lower high**.

### Combined Strategy with Laguerre Filter (Primary Use)

This oscillator is designed to be used in conjunction with its companion indicator, the `Laguerre_Filter_Pro`.

* **The Zero-Cross Predicts the Filter's Turning Point:**
  * **Buy Signal:** When the **Laguerre Momentum** line crosses **above the zero line**, it provides a leading signal that the `Laguerre_Filter` on the main chart is forming a **trough (a bottom)**.
  * **Sell Signal:** When the **Laguerre Momentum** line crosses **below the zero line**, it provides a leading signal that the `Laguerre_Filter` is forming a **peak (a top)**.
