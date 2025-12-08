# Symbol Sets Reference

This document outlines the naming convention and organization for Symbol Set files (`.set`) located in the `SymbolSets` directory. These files are used to quickly load predefined lists of instruments into the MetaTrader 5 Market Watch window.

## Naming Convention

To ensure compatibility across different brokers (who often use different symbol names like `XAUUSD` vs `Gold` or `US500` vs `SPX500`), we include the broker name in the file structure:

`sym.[Broker].[Category].[Detail].set`

* **`sym`**: Prefix identifying the file as a Symbol Set.
* **`[Broker]`**: The broker for which the symbols are valid (e.g., `tickmill`, `gomarkets`, `icmarkets`).
* **`[Category]`**: The primary asset class.
  * `forex`
  * `indices`
  * `crypto`
  * `commodities`
  * `global` (Mixed asset classes)
* **`[Detail]`**: Specific subset or description.
  * `majors`, `minors`, `crosses_eur`
  * `us`, `eu`, `asia`
  * `main`, `macro`

## Examples

### Forex Sets

| Filename | Description |
| :--- | :--- |
| **`sym.tickmill.forex.majors.set`** | The 7 major currency pairs (EURUSD, GBPUSD, etc.). |
| **`sym.tickmill.forex.crosses_eur.set`** | All EUR crosses (EURGBP, EURJPY, EuraUD, etc.). |
| **`sym.tickmill.forex.crosses_jpy.set`** | All JPY crosses. |

### Index & Commodity Sets

| Filename | Description |
| :--- | :--- |
| **`sym.tickmill.indices.all.set`** | All available stock indices. |
| **`sym.tickmill.commodities.energy.set`** | Oil (WTI, Brent) and Natural Gas. |
| **`sym.tickmill.crypto.top10.set`** | The top 10 cryptocurrencies by market cap. |

### Global / Mixed Sets

| Filename | Description |
| :--- | :--- |
| **`sym.gomarkets.global.macro.set`** | A balanced mix of major Indices, Commodities, and Forex pairs for Global Macro analysis. |
| **`sym.tickmill.global.main.set`** | The most liquid instruments across all markets (e.g., US500, Gold, EURUSD, Bitcoin). |

## Usage

1. Right-click in the **Market Watch** window.
2. Select **Sets -> Load...**
3. Navigate to the `SymbolSets` folder and select the desired `.set` file.
