# MQL5

MQL5 Algo Forge / toh4iem9

A collection of professionally coded, robust, and reusable MQL5 indicators, scripts, and trading tools.

---

## MQL5 Indicator & Script Collection: Comprehensive Catalogue

### Introduction

This document provides a comprehensive overview of our custom-developed MQL5 indicator collection. Every tool in this library was built following three core principles:

1. **Stability Over Premature Optimization:** All indicators utilize a "full recalculation" model, ensuring robust and glitch-free performance. Recursive calculations are carefully and manually initialized.
2. **Pragmatic Modularity:** Complex logic is encapsulated into centralized, object-oriented calculator engines (`_Calculator.mqh` or `_Engine.mqh`), promoting clean, maintainable, and reusable code across indicator families.
3. **Definition-True Implementation:** Our indicators are implemented to match the original author's mathematical formula as closely as possible, aligning with the global standard used on professional platforms.

A key feature of our "Pro" series is the unification of standard and Heikin Ashi calculations into a single, flexible indicator, allowing the user to choose the desired data source via input parameters.

---

## 1. Core Indicators

### 1.1 Trend-Following & Smoothing Indicators

| Indicator | Primary Purpose | Key Feature / Why Use It? | Best For | Complexity / Repainting |
| :--- | :--- | :--- | :--- | :--- |
| **ALMA_Pro** | A low-lag, responsive moving average. | Reduces lag significantly while maintaining smoothness. Selectable candle source (Std/HA). | Responsive Trend Following | Medium `O(N^2)` / No |
| **AMA_Pro** | Adapts its speed based on market noise. | Slows down in ranges, speeds up in trends. Selectable candle source (Std/HA). | Dynamic Trend Filtering | Medium `O(N)` / No |
| **FibonacciWMA_Pro** | A WMA using Fibonacci numbers for weighting. | Asymmetrically weighted, highly responsive to recent prices. Selectable candle source (Std/HA). | Responsive Trend Following | Low `O(N)` / No |
| **GannHiLo_Pro** | MA-based trend and trailing stop levels. | Uses separate MAs for Highs and Lows for clearer levels. Selectable candle source (Std/HA). | Trend Following, Trailing Stops | Medium `O(N)` / No |
| **HMA_Pro** | An extremely fast and smooth moving average. | One of the most responsive MAs available. Selectable candle source (Std/HA). | Short-Term Trend Following | Medium `O(N)` / No |
| **Holt_Pro** | A predictive, double-smoothed line with a forecast channel. | Exceptionally smooth with a **one-bar-ahead forecast**. Selectable candle source (Std/HA) & display mode. | Early Trend Identification | Low `O(N)` / No |
| **Jurik_MA** | An ultra-smooth, low-lag adaptive filter. | Considered one of the most advanced MAs; extremely smooth yet fast. Separate Std/HA versions. | Advanced Trend Following | High `O(N)` / No |
| **MAMA_FAMA_Pro** | Adapts to the market's dominant cycle period. | Measures market "rhythm" to adjust speed. Selectable algorithms (Ehlers/LazyBear) & candle source (Std/HA). | Cycle Analysis, Crossovers | High `O(N)` / No |
| **McGinleyDynamic_Pro**| A self-adjusting, responsive moving average. | Speeds up in down markets, slows down in up markets. Selectable candle source (Std/HA). | Dynamic Trend Following | Low `O(N)` / No |
| **MACD_Pro** | Classic momentum indicator. | TradingView-style display. Selectable MA types & candle source (Std/HA). | Trend Confirmation, Divergences | Medium `O(N)` / No |
| **PascalWMA_Pro** | A zero-lag, symmetrical smoothing filter. | Symmetrical, bell-shaped weighting for superior noise reduction. Selectable candle source (Std/HA). | Mean Reversion, Noise Filter | Low `O(N)` / No |
| **SineWMA_Pro** | A zero-lag, symmetrical smoothing filter. | Sine-based weighting for a smooth "center of gravity" line. Selectable candle source (Std/HA). | Mean Reversion, Noise Filter | Low `O(N)` / No |
| **Supertrend_Pro** | Volatility-based trend and trailing stop levels. | Robust, stepped line for clear signals. Selectable candle & ATR source (Std/HA). | Trend Following, Trailing Stops | Medium `O(N)` / No |
| **SymmetricWMA_Pro** | A zero-lag, symmetrical smoothing filter. | Simple triangular weighting for effective noise reduction. Selectable candle source (Std/HA). | Mean Reversion, Noise Filter | Low `O(N)` / No |
| **VIDYA_Pro** | Adapts its speed based on momentum (CMO). | Reacts to momentum, not just noise. Selectable candle source (Std/HA). | Dynamic Trend Filtering | Medium `O(N)` / No |

### 1.2 Oscillators

| Indicator | Primary Purpose | Key Feature / Why Use It? | Best For | Complexity / Repainting |
| :--- | :--- | :--- | :--- | :--- |
| **ADX_Pro** | Measures trend strength (not direction). | The classic Wilder's ADX. Selectable candle source (Std/HA). | Trend Strength Filtering | Medium `O(N)` / No |
| **CCI_Pro** | Measures variation from a statistical mean. | Definition-true calculation. Selectable candle source (Std/HA) & optional signal line. | Breakouts, Extreme Levels | Medium `O(N^2)` / No |
| **CCI_Oscillator_Pro**| Histogram of the CCI and its signal line. | Visualizes CCI momentum. Selectable candle source (Std/HA). | Momentum Analysis | Medium `O(N^2)` / No |
| **CutlerRSI_Pro** | An RSI variant using SMA for smoothing. | Provides a different character of momentum. Selectable candle source (Std/HA) & optional signal line. | Mean Reversion, Divergences | Low `O(N)` / No |
| **CutlerRSI_Oscillator_Pro**| Histogram of the Cutler RSI and its signal line. | Visualizes Cutler RSI momentum. Selectable candle source (Std/HA). | Momentum Analysis | Low `O(N)` / No |
| **FisherTransform_Pro**| Normalizes price to create sharp turning points. | Excellent for identifying price extremes. Selectable candle source (Std/HA). | Spotting Reversals | Medium `O(N)` / No |
| **Holt_Oscillator_Pro**| Plots the "Trend" component of the Holt model. | A pure measure of trend velocity and acceleration. Selectable candle source (Std/HA). | Trend Velocity Analysis | Low `O(N)` / No |
| **MFI_Pro** | A "volume-weighted RSI". | More robust than RSI as it incorporates volume. Selectable candle source (Std/HA) & optional signal line. | Divergences, Overbought/Oversold | Low `O(N)` / No |
| **RSI_Pro** | Classic Wilder's RSI. | All-in-one tool with optional signal line and Bollinger Bands. Selectable candle source (Std/HA). | Mean Reversion, Divergences | Low `O(N)` / No |
| **SMI_Pro** | A smoother version of the Stochastic Oscillator. | Measures close relative to the midpoint of the range. Selectable candle source (Std/HA). | Smoothed Momentum Signals | Medium `O(N)` / No |
| **StochasticFast_Pro**| The raw, un-smoothed Stochastic Oscillator. | Highly responsive. Selectable candle source (Std/HA) & MA type for %D. | Ranging Markets, Reversals | Low `O(N)` / No |
| **StochasticSlow_Pro**| The classic, smoothed Stochastic Oscillator. | The industry standard. Selectable candle source (Std/HA) & MA types for Slowing/%D. | Ranging Markets, Reversals | Medium `O(N)` / No |
| **StochRSI_Fast_Pro**| Applies the Fast Stochastic formula to RSI data. | Extremely sensitive "indicator of an indicator". Selectable candle source (Std/HA) for RSI. | Short-Term Overbought/Oversold | Medium `O(N)` / No |
| **StochRSI_Slow_Pro**| Applies the Slow Stochastic formula to RSI data. | Smoother than the Fast version. Selectable candle source (Std/HA) for RSI. | Short-Term Overbought/Oversold | Medium `O(N)` / No |
| **TDI_Pro** | An "all-in-one" system based on RSI, MAs, and Volatility Bands. | Provides a comprehensive market view in one window. Selectable candle source (Std/HA) for RSI. | Complete Trading System | High `O(N^2)` / No |
| **TSI_Pro** | A double-smoothed momentum oscillator. | Extremely smooth, with reliable zero-line crossovers. Selectable candle source (Std/HA). | Trend Following, Divergences | Medium `O(N)` / No |
| **TSI_Oscillator_Pro**| Histogram of the TSI and its signal line. | Visualizes TSI momentum. Selectable candle source (Std/HA). | Momentum Analysis | Medium `O(N)` / No |
| **UltimateOscillator_Pro**| A multi-timeframe oscillator for reliable divergences. | Combines three timeframes to reduce false signals. Selectable candle source (Std/HA) & optional signal line. | **Divergence Trading** | Low `O(N)` / No |
| **WPR_Pro** | The inverse of the Fast Stochastic %K line. | A fast and simple oscillator. Selectable candle source (Std/HA) & optional signal line. | Short-Term Reversals | Low `O(N)` / No |

### 1.3 Volatility & Volume Indicators

| Indicator | Primary Purpose | Key Feature / Why Use It? | Best For | Complexity / Repainting |
| :--- | :--- | :--- | :--- | :--- |
| **AD_Pro** | A cumulative measure of money flow. | Confirms trends and spots divergences. Selectable candle source (Std/HA). | Trend Confirmation, Divergences | Low `O(N)` / No |
| **AMA_TrendActivity_Pro**| Measures the slope/activity of the AMA line. | Quantifies "trendiness". Selectable candle source (Std/HA) for AMA & ATR. | Trend Filtering | Medium `O(N)` / No |
| **ATR_Pro** | Measures market volatility (Wilder's definition). | The global standard for ATR. Selectable candle source (Std/HA). | Risk Management, Stop-loss | Low `O(N)` / No |
| **Bollinger_Bands_Pro**| Standard deviation-based volatility channels. | The most statistically precise measure of volatility. Selectable candle source (Std/HA). | Mean Reversion, Breakouts | Medium `O(N^2)` / No |
| **Bollinger_Band_Width_Pro**| Oscillator that measures the width of the Bollinger Bands. | Identifies volatility "squeezes". Selectable candle source (Std/HA). | Breakout Anticipation | Medium `O(N^2)` / No |
| **Bollinger_Bands_PercentB**| Oscillator that shows price position within the bands. | Normalizes price relative to the bands. Selectable candle source (Std/HA). | Overbought/Oversold | Medium `O(N^2)` / No |
| **CHO_Pro** | Measures the momentum of the ADL. | Spots shifts in buying/selling pressure. Selectable candle source (Std/HA) for ADL. | Divergences, Money Flow | Medium `O(N)` / No |
| **Jurik_Bands** | Volatility bands based on the Jurik Volatility (JMA Volty). | Extremely responsive, low-lag channels. Separate Std/HA versions. | Advanced Breakout Trading | High `O(N)` / No |
| **Jurik_Volatility** | A low-lag, adaptive measure of market volatility. | A superior alternative to ATR for fast-reacting systems. Separate Std/HA versions. | Advanced Risk Management | High `O(N)` / No |
| **KeltnerChannel_Pro**| ATR-based volatility channels. | Highly flexible with selectable MA source and ATR source (Std/HA). | Trend Following, Breakouts | Medium `O(N)` / No |
| **VIDYA_TrendActivity_Pro**| Measures the slope/activity of the VIDYA line. | Quantifies momentum-based "trendiness". Selectable candle source (Std/HA) for VIDYA & ATR. | Trend Filtering | Medium `O(N)` / No |

### 1.4 Other Indicators

| Indicator | Primary Purpose | Key Feature / Why Use It? | Complexity / Repainting |
| :--- | :--- | :--- | :--- |
| **Chart_HeikinAshi** | Displays Heikin Ashi candles on the main chart. | A clean, simple implementation for trend visualization. | Low `O(N)` / No |
| **LinearRegression_Pro**| Plots a statistically precise, non-repainting trend channel. | Updates only on new bars for efficiency. Selectable candle source (Std/HA). | Low `O(N)` / **Yes (by design)** |
| **Murrey_Math_Line_X**| Plots a grid of S/R levels based on Gann's octave theory. | A complete, rule-based trading framework. | High `O(N)` / **Yes (by design)** |

---

## 2. Scripts & Utilities

| Tool | Primary Purpose | Key Feature / Why Use It? |
| :--- | :--- | :--- |
| **AccountInfoDisplay** | Displays real-time account statistics on the chart. | Clean, object-oriented code with a clear separation of data and presentation. |
| **CalculateMarginSwap** | Calculates required margin and swap costs for a potential trade. | A crucial tool for risk management and position sizing. |
| **SymbolInfo Checkers** | Lists all `DOUBLE`, `INTEGER`, and `STRING` properties for a symbol. | Professional, class-based diagnostic tools for developers. |
| **SymbolScannerPanel** | Scans and filters all available symbols based on user-defined criteria. | A powerful, class-based data mining tool for finding instruments that meet specific conditions. |
| **util_ExportCandlesToCSV** | Exports historical candle data to a CSV file. | Clean, object-oriented design with robust file handling. |

---

## 3. Include Libraries (`MyIncludes/`)

This collection of `.mqh` files forms the backbone of our indicator suite, encapsulating all complex calculation logic for maximum reusability and easy maintenance.

* **Core Engines:** `AD_Calculator.mqh`, `ADX_Calculator.mqh`, `ALMA_Calculator.mqh`, `AMA_Calculator.mqh`, `ATR_Calculator.mqh`, `Bollinger_Bands_Calculator.mqh`, `CCI_Engine.mqh`, `CHO_Calculator.mqh`, `CutlerRSI_Engine.mqh`, `FibonacciWMA_Calculator.mqh`, `FisherTransform_Calculator.mqh`, `GannHiLo_Calculator.mqh`, `HMA_Calculator.mqh`, `Holt_Engine.mqh`, `Jurik_Calculators.mqh`, `KeltnerChannel_Calculator.mqh`, `LinearRegression_Calculator.mqh`, `MACD_Calculator.mqh`, `MAMA_Engines.mqh`, `McGinleyDynamic_Calculator.mqh`, `MFI_Calculator.mqh`, `PascalWMA_Calculator.mqh`, `RSI_Pro_Calculator.mqh`, `SineWMA_Calculator.mqh`, `SMI_Calculator.mqh`, `Stochastic_Calculator.mqh`, `Supertrend_Calculator.mqh`, `SymmetricWMA_Calculator.mqh`, `TDI_Calculator.mqh`, `TSI_Engine.mqh`, `UltimateOscillator_Calculator.mqh`, `VIDYA_Calculator.mqh`, `WPR_Calculator.mqh`.
* **Wrapper/Adapter Calculators:** `CCI_Calculator.mqh`, `CCI_Oscillator_Calculator.mqh`, `CutlerRSI_Calculator.mqh`, `CutlerRSI_Oscillator_Calculator.mqh`, `Holt_Calculator.mqh`, `Holt_Oscillator_Calculator.mqh`, `TSI_Calculator.mqh`, `TSI_Oscillator_Calculator.mqh`, etc.
* **Toolkits:** `HeikinAshi_Tools.mqh`.
