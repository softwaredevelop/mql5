# MQL5

MQL5 Algo Forge / toh4iem9

---

## MQL5 Indicator & Script Collection: Comprehensive Catalogue

## Introduction

This document provides a comprehensive overview of our custom-developed and refactored MQL5 indicator and script collection. Every tool in this library was built following three core principles:

1. **Stability Over Premature Optimization:** All indicators utilize a "full recalculation" model, ensuring robust and glitch-free performance during timeframe changes or history loading. Recursive calculations are carefully and manually initialized.
2. **Modularity and Reusability:** Complex logic is encapsulated into centralized toolkits (e.g., `HeikinAshi_Tools.mqh`), promoting clean, maintainable, and reusable code.
3. **Adherence to Definition:** Our indicators are implemented to match the original author's mathematical formula as closely as possible, aligning with the global standard used on professional platforms rather than platform-specific variations.

Each indicator family includes both a standard (candlestick) version and a "pure" Heikin Ashi variant.

---

## 1. Trend-Following Indicators

These tools are designed to identify the direction and strength of a market trend and to define potential dynamic support and resistance levels.

| Indicator                 | Primary Purpose                                                                 | Key Feature / Why Use It?                                                                                                                   | Best For                        | Complexity / Repainting |
| :------------------------ | :------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------ | :---------------------- |
| **Supertrend**            | Identify trend direction and provide volatility-based trailing stop levels.     | Its robust, stepped line gives clear visual signals. Our version connects the lines on a trend change for continuous information.           | Trend Following, Trailing Stops | Low `O(N)` / No         |
| **Gann HiLo Activator**   | Identify trend direction and provide moving average-based trailing stop levels. | Uses separate moving averages for Highs and Lows, providing clearer levels than a single MA.                                                | Trend Following, Trailing Stops | Low `O(N)` / No         |
| **Adaptive MA (AMA)**     | An "intelligent" moving average that adapts its speed based on market noise.    | Slows down in ranging markets and speeds up in trending markets, helping to filter out false signals.                                       | Trend Following, Dynamic Filter | Medium `O(N)` / No      |
| **VIDYA**                 | An "intelligent" moving average that adapts its speed based on momentum (CMO).  | Similar to AMA but reacts to momentum, not noise. The Heikin Ashi version is extremely responsive due to the clean trend input.             | Trend Following, Dynamic Filter | Medium `O(N)` / No      |
| **Hull MA (HMA)**         | An extremely fast and smooth moving average designed to minimize lag.           | One of the most responsive moving averages available, hugging price action closely.                                                         | Short-Term Trend Following      | Low `O(N)` / No         |
| **Linear Regression Pro** | Plots a statistically precise trend channel.                                    | A fully manual, flexible implementation. Features selectable source price and channel calculation methods (Standard vs. Maximum Deviation). | Trend Analysis, Mean Reversion  | High `O(N^2)` / **Yes** |

---

## 2. Momentum Oscillators

These tools measure overbought/oversold levels, the strength of momentum, and potential reversals through divergences.

| Indicator                        | Primary Purpose                                                                    | Key Feature / Why Use It?                                                                                                                      | Best For                        | Complexity / Repainting        |
| :------------------------------- | :--------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------ | :----------------------------- |
| **MACD Pro**                     | Measure trend momentum via the difference between two moving averages.             | Features a TradingView-style 3-component display (MACD Line, Signal, Histogram). Our "Pro" version has selectable MA types for all components. | Trend Confirmation, Divergences | Medium `O(N)` / No             |
| **RSI & Cutler's RSI**           | Measure internal strength and identify overbought/oversold levels.                 | Cutler's RSI uses an SMA instead of the standard Wilder's smoothing. Both are equipped with a flexible signal line.                            | Mean Reversion, Divergences     | Low `O(N)` / No                |
| **Stochastic (Fast, Slow, Pro)** | Measure the price's position relative to its high-low range over a period.         | Our "Pro" version allows selecting the MA type for smoothing, enabling it to replicate both the classic and MT5-specific behaviors.            | Ranging Markets, Reversals      | Low `O(N)` / No                |
| **StochRSI (Pro)**               | The "stochastic of the RSI." An extremely sensitive oscillator for early signals.  | Our "Pro" version provides full flexibility in the smoothing methods, making it a highly adaptable tool.                                       | Short-Term Overbought/Oversold  | Medium `O(N)` / No             |
| **CCI (Efficient & Precise)**    | Measure a security's variation from its statistical mean.                          | We offer two versions: a fast, sliding-window "Efficient" implementation and a mathematically "Precise" definition-true version.               | Breakouts, Extreme Levels       | Medium `O(N^2)` (Precise) / No |
| **Ultimate Oscillator**          | A multi-timeframe oscillator designed to produce more reliable divergence signals. | By combining three timeframes, it is less prone to generating false divergence signals than most single-timeframe oscillators.                 | **Divergence Trading**          | Medium `O(N)` / No             |
| **WPR (%R)**                     | A simplified, inverted version of the Stochastic Oscillator.                       | A fast and simple oscillator for identifying overbought/oversold conditions.                                                                   | Short-Term Reversals            | Low `O(N)` / No                |

---

## 3. Blau "Ergodic" Section

William Blau's unique, double-smoothed oscillators designed for maximum noise reduction.

| Indicator        | Primary Purpose                                                                         | Key Feature / Why Use It?                                                                                                   | Best For                         | Complexity / Repainting |
| :--------------- | :-------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------- | :------------------------------- | :---------------------- |
| **Ergodic TSI**  | A double-smoothed measure of **trend momentum** (price change).                         | The classic, globally accepted TSI. Extremely smooth, with reliable zero-line crossovers and divergences.                   | Trend Following, Divergences     | Medium `O(N)` / No      |
| **Ergodic CMI**  | A double-smoothed measure of **intra-bar momentum** (`Close-Open`).                     | Measures the "conviction" within each candle. Offers a unique insight into buying/selling pressure.                         | Momentum Confirmation            | Medium `O(N)` / No      |
| **Ergodic DTI**  | A double-smoothed measure of **directional momentum** (`High/Low` change).              | A much smoother, cleaner alternative to the classic ADX for measuring trend direction and strength.                         | Trend Following, ADX Replacement | Medium `O(N)` / No      |
| **Ergodic SMI**  | A double-smoothed measure of **Stochastic momentum** (`Close` vs. `High/Low` midpoint). | A hybrid of the Stochastic and TSI concepts. Smoother than a standard Stochastic, potentially more responsive than the TSI. | Overbought/Oversold, Reversals   | Medium `O(N)` / No      |
| **Ergodic MACD** | Applies an additional layer of double-smoothing to the classic MACD lines.              | An "ultra-smooth" MACD designed to filter out all but the most significant, long-term momentum shifts.                      | Long-Term Trend Analysis         | High `O(N)` / No        |

---

## 4. Volatility Indicators

| Indicator             | Primary Purpose                                              | Key Feature / Why Use It?                                                                             | Best For                        | Complexity / Repainting |
| :-------------------- | :----------------------------------------------------------- | :---------------------------------------------------------------------------------------------------- | :------------------------------ | :---------------------- |
| **ATR**               | Measure market volatility (the average size of a price bar). | Our version uses the classic Wilder's (RMA) smoothing, which is the global standard.                  | Risk Management, Stop-loss      | Low `O(N)` / No         |
| **ATR Trailing Stop** | Provide dynamic, volatility-based trailing stop levels.      | Implements the classic "Chandelier Exit" algorithm. The stop distance adapts to market volatility.    | Trailing Stops, Trend Following | Low `O(N)` / No         |
| **Keltner Channel**   | A volatility-based channel around a moving average.          | We have three versions: Standard (MA + Std ATR), Hybrid (HA MA + Std ATR), and Pure (HA MA + HA ATR). | Trend Following, Breakouts      | Medium `O(N)` / No      |
| **Bollinger Bands**   | A standard deviation-based channel around a moving average.  | The most statistically precise measure of volatility. The "Squeeze" is its most famous signal.        | Mean Reversion, Breakouts       | Low `O(N)` / No         |

---

## 5. Custom & Utility Tools

| Tool                     | Primary Purpose                                                           | Key Feature / Why Use It?                                                                                  | Type       |
| :----------------------- | :------------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------- | :--------- |
| **VIDYA Trend Activity** | Measures how strongly the VIDYA moving average is trending or ranging.    | A unique "meta-indicator." Uses `MathArctan` normalization to function consistently across all timeframes. | Oscillator |
| **Account Info Display** | Display real-time account statistics on the chart.                        | Clean, object-oriented code with a clear separation of data and presentation.                              | Script     |
| **Symbol Info Checkers** | List all `DOUBLE`, `INTEGER`, and `STRING` properties for a given symbol. | Professional, class-based diagnostic tools for developers.                                                 | Scripts    |
| **Candle Exporter**      | Export historical candle data to a CSV file.                              | Clean, object-oriented design with robust file handling (RAII).                                            | Script     |
