# MQL5

MQL5 Algo Forge / toh4iem9

---

## MQL5 Indicator & Script Collection: Comprehensive Catalogue

## Introduction

This document provides a comprehensive overview of our custom-developed and refactored MQL5 indicator and script collection. Every tool in this library was built following three core principles:

1. **Stability Over Premature Optimization:** All indicators utilize a "full recalculation" model, ensuring robust and glitch-free performance during timeframe changes or history loading. Recursive calculations are carefully and manually initialized.
2. **Modularity and Reusability:** Complex logic is encapsulated into centralized toolkits (e.g., `HeikinAshi_Tools.mqh`), promoting clean, maintainable, and reusable code.
3. **Adherence to Definition:** Our indicators are implemented to match the original author's mathematical formula as closely as possible, aligning with the global standard used on professional platforms rather than platform-specific variations.

Each indicator family includes a standard (candlestick) version and a "pure" Heikin Ashi variant. Many oscillators also have a separate "Oscillator" (histogram) version.

---

## 1. Core Indicators (`MyIndicators/`)

### 1.1 Trend-Following Indicators

| Indicator Family           | Primary Purpose                                                                | Key Feature / Why Use It?                                                                                                            | Best For                        | Complexity / Repainting      |
| :------------------------- | :----------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------- | :------------------------------ | :--------------------------- |
| **Supertrend**             | Identify trend direction and provide volatility-based trailing stop levels.    | Robust, stepped line for clear signals. We offer a "Pure" HA version and a standard ATR version.                                     | Trend Following, Trailing Stops | Low `O(N)` / No              |
| **Gann HiLo Activator**    | Identify trend direction and MA-based trailing stop levels.                    | Uses separate MAs for Highs and Lows, providing clearer levels than a single MA.                                                     | Trend Following, Trailing Stops | Low `O(N)` / No              |
| **Adaptive MA (AMA)**      | An "intelligent" moving average that adapts its speed based on market noise.   | Slows down in ranges and speeds up in trends, helping to filter false signals.                                                       | Trend Following, Dynamic Filter | Medium `O(N)` / No           |
| **VIDYA**                  | An "intelligent" moving average that adapts its speed based on momentum (CMO). | Reacts to momentum, not noise. The Heikin Ashi version is extremely responsive due to the clean trend input.                         | Trend Following, Dynamic Filter | Medium `O(N)` / No           |
| **Hull MA (HMA)**          | An extremely fast and smooth moving average designed to minimize lag.          | One of the most responsive moving averages available, hugging price action closely.                                                  | Short-Term Trend Following      | Low `O(N)` / No              |
| **McGinley Dynamic**       | A self-adjusting moving average that is more responsive than traditional MAs.  | Its unique formula speeds up in down markets and slows down in up markets.                                                           | Dynamic Trend Following         | Low `O(N)` / No              |
| **Linear Regression Pro**  | Plots a statistically precise trend channel.                                   | Fully manual, flexible implementation with selectable source price and channel calculation methods (Standard vs. Maximum Deviation). | Trend Analysis, Mean Reversion  | High `O(N^2)` / **Yes**      |
| **Std. Deviation Channel** | Plots a regression channel with adjustable deviation.                          | Uses the robust `OBJ_STDDEVCHANNEL` for a precise, MT5-native linear regression channel with adjustable width.                       | Trend Analysis                  | Low (Object-based) / **Yes** |

### 1.2 Momentum Oscillators

| Indicator Family                 | Primary Purpose                                                                    | Key Feature / Why Use It?                                                                                                        | Best For                        | Complexity / Repainting          |
| :------------------------------- | :--------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------- | :------------------------------ | :------------------------------- |
| **MACD Pro**                     | Measure trend momentum via the difference between two moving averages.             | TradingView-style 3-component display. Our "Pro" version has selectable MA types for all components.                             | Trend Confirmation, Divergences | Medium `O(N)` / No               |
| **RSI**                          | Measure internal strength and identify overbought/oversold levels.                 | A robust implementation of the classic Wilder's RSI, complete with a flexible signal line and oscillator version.                | Mean Reversion, Divergences     | Low `O(N)` / No                  |
| **Cutler's RSI**                 | An RSI variant using SMA for smoothing instead of Wilder's method.                 | Provides a different character of momentum reading. Includes a flexible signal line and oscillator version.                      | Mean Reversion, Divergences     | Low `O(N)` / No                  |
| **Stochastic (Fast, Slow, Pro)** | Measure the price's position relative to its high-low range.                       | Our "Pro" version allows selecting the MA type for smoothing, enabling replication of classic and MT5-specific behaviors.        | Ranging Markets, Reversals      | Low `O(N)` / No                  |
| **StochRSI (Fast, Slow, Pro)**   | The "stochastic of the RSI." An extremely sensitive oscillator.                    | Our "Pro" version provides full flexibility in the smoothing methods, making it a highly adaptable tool.                         | Short-Term Overbought/Oversold  | Medium `O(N)` / No               |
| **CCI (Efficient & Precise)**    | Measure a security's variation from its statistical mean.                          | We offer two versions: a fast, sliding-window "Efficient" implementation and a mathematically "Precise" definition-true version. | Breakouts, Extreme Levels       | Med-High `O(N^2)` (Precise) / No |
| **Fisher Transform**             | A statistical transformation that normalizes price, creating sharp turning points. | Excellent for identifying price extremes. Our version includes a robust initialization to prevent overflows.                     | Spotting Reversals              | Medium `O(N)` / No               |
| **Ultimate Oscillator**          | A multi-timeframe oscillator designed to produce more reliable divergence signals. | By combining three timeframes, it is less prone to generating false divergence signals.                                          | **Divergence Trading**          | Medium `O(N)` / No               |
| **WPR (%R)**                     | A simplified, inverted version of the Stochastic Oscillator.                       | A fast and simple oscillator for identifying overbought/oversold conditions. Includes a version with a signal line.              | Short-Term Reversals            | Low `O(N)` / No                  |

### 1.3 Volatility & Volume Indicators

| Indicator Family              | Primary Purpose                                                                | Key Feature / Why Use It?                                                                             | Best For                         | Complexity / Repainting |
| :---------------------------- | :----------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------- | :------------------------------- | :---------------------- |
| **ATR**                       | Measure market volatility (the average size of a price bar).                   | Our version uses the classic Wilder's (RMA) smoothing, which is the global standard.                  | Risk Management, Stop-loss       | Low `O(N)` / No         |
| **ATR Trailing Stop**         | Provide dynamic, volatility-based trailing stop levels.                        | Implements the classic "Chandelier Exit" algorithm. The stop distance adapts to market volatility.    | Trailing Stops, Trend Following  | Low `O(N)` / No         |
| **Keltner Channel**           | A volatility-based channel around a moving average.                            | We have three versions: Standard (MA + Std ATR), Hybrid (HA MA + Std ATR), and Pure (HA MA + HA ATR). | Trend Following, Breakouts       | Medium `O(N)` / No      |
| **Bollinger Bands**           | A standard deviation-based channel around a moving average.                    | The most statistically precise measure of volatility. The "Squeeze" is its most famous signal.        | Mean Reversion, Breakouts        | Low `O(N)` / No         |
| **Accum./Distribution (ADL)** | A cumulative measure of money flow based on close position and volume.         | A foundational volume indicator used for confirming trends and spotting divergences.                  | Trend Confirmation, Divergences  | Low `O(N)` / No         |
| **Chaikin Oscillator (CHO)**  | Measures the momentum of the Accumulation/Distribution Line.                   | Excellent for spotting shifts in buying/selling pressure before they are obvious in price.            | Divergences, Money Flow          | Medium `O(N)` / No      |
| **Money Flow Index (MFI)**    | A "volume-weighted RSI" that measures money flowing into or out of a security. | More robust than RSI as it incorporates volume. Excellent for divergence signals.                     | Divergences, Overbought/Oversold | Low `O(N)` / No         |

### 1.4 Blau Authors Series (`MyIndicators/Authors/Blau/`)

William Blau's unique, double-smoothed oscillators designed for maximum noise reduction.

| Indicator Family | Primary Purpose                                                            | Key Feature / Why Use It?                                                                                 | Best For                         | Complexity    |
| :--------------- | :------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------- | :------------------------------- | :------------ |
| **Ergodic TSI**  | A double-smoothed measure of **trend momentum** (price change).            | The classic, globally accepted TSI. Extremely smooth, with reliable zero-line crossovers and divergences. | Trend Following, Divergences     | Medium `O(N)` |
| **Ergodic CMI**  | A double-smoothed measure of **intra-bar momentum** (`Close-Open`).        | Measures the "conviction" within each candle. Offers a unique insight into buying/selling pressure.       | Momentum Confirmation            | Medium `O(N)` |
| **Ergodic DTI**  | A double-smoothed measure of **directional momentum** (`High/Low` change). | A much smoother, cleaner alternative to the classic ADX for measuring trend direction and strength.       | Trend Following, ADX Replacement | Medium `O(N)` |
| **Ergodic SMI**  | A double-smoothed measure of **Stochastic momentum**.                      | A hybrid of the Stochastic and TSI concepts. Smoother than a standard Stochastic.                         | Overbought/Oversold, Reversals   | Medium `O(N)` |
| **Ergodic MACD** | Applies an additional layer of double-smoothing to the classic MACD lines. | An "ultra-smooth" MACD designed to filter out all but the most significant, long-term momentum shifts.    | Long-Term Trend Analysis         | High `O(N)`   |

---

## 2. Scripts & Utilities (`MyScripts/` & `MyIncludes/`)

| Tool                     | Primary Purpose                                                             | Key Feature / Why Use It?                                                                       | Type            |
| :----------------------- | :-------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------- | :-------------- |
| **HeikinAshi_Tools.mqh** | Provides `CHeikinAshi_Calculator` and `CHeikinAshi_RSI_Calculator` classes. | The core engine for all our Heikin Ashi indicators. Encapsulates complex logic for easy reuse.  | Include Library |
| **AccountInfoDisplay**   | Display real-time account statistics on the chart.                          | Clean, object-oriented code with a clear separation of data and presentation.                   | Script          |
| **Symbol Info Checkers** | List all `DOUBLE`, `INTEGER`, and `STRING` properties for a given symbol.   | Professional, class-based diagnostic tools for developers.                                      | Scripts         |
| **SymbolScannerPanel**   | Scans and filters all available symbols based on user-defined criteria.     | A powerful, class-based data mining tool for finding instruments that meet specific conditions. | Script          |
| **Candle Exporter**      | Export historical candle data to a CSV file.                                | Clean, object-oriented design with robust file handling (RAII).                                 | Script          |
