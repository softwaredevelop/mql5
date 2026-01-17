# Laguerre Stochastic Fast Pro

## 1. Summary (Introduction)

The **Laguerre Stochastic Fast Pro** is a highly responsive oscillator designed to detect short-term market cycles and momentum shifts with minimal lag. Unlike traditional Stochastic oscillators that use a fixed time window (e.g., 14 bars), this indicator derives its values directly from the internal state variables of the **Laguerre Filter**.

This "native" approach results in an indicator that adapts rapidly to price changes, making it an excellent tool for scalping and identifying precise entry points in volatile markets.

## 2. Mathematical Foundations

The core innovation of this indicator lies in how it defines the "High" and "Low" for the Stochastic calculation. Instead of looking back at price history, it looks at the four internal components of the Laguerre Filter ($L0, L1, L2, L3$) at the current moment.

### Calculation Steps

1. **Calculate Laguerre Components:** The four Laguerre filter outputs are calculated based on the price and the **Gamma** factor. These components represent the price filtered with varying degrees of delay.
2. **Determine Range:**
    * $\text{Highest High (HH)} = \max(L0, L1, L2, L3)$
    * $\text{Lowest Low (LL)} = \min(L0, L1, L2, L3)$
3. **Calculate Fast %K:**
    * $\%K = \frac{L0 - LL}{HH - LL} \times 100$
    * Here, $L0$ (the most responsive component) acts as the "Current Price".
4. **Calculate Signal Line:** A simple moving average (SMA) is applied to the %K line to generate trading signals.

## 3. Parameters

* **Gamma (`InpGamma`):** Controls the "memory" of the Laguerre filter. Default is `0.7`.
  * Lower values (e.g., 0.5) make the oscillator faster and more sensitive.
  * Higher values (e.g., 0.85) make it smoother but may introduce lag.
* **Source Price (`InpSourcePrice`):** Selects the input data (Standard or Heikin Ashi).
* **Signal Period (`InpSignalPeriod`):** The smoothing period for the Signal line. Default is `3`.
* **Signal Method (`InpSignalMethod`):** The averaging method for the Signal line (SMA, EMA, etc.).

## 4. Usage and Interpretation

* **Overbought/Oversold:** Values above 80 indicate overbought conditions, while values below 20 indicate oversold conditions. Due to its speed, the indicator can reach these zones quickly.
* **Crossovers:** A buy signal is generated when the Fast %K line crosses above the Signal line (especially in the oversold zone). A sell signal is generated when it crosses below the Signal line (in the overbought zone).
* **Scalping:** This indicator is ideal for scalpers looking for quick reversals. It reacts faster than almost any other oscillator.
