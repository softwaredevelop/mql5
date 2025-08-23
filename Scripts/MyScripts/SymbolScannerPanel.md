# Symbol Scanner Panel Script

## 1. Summary (Introduction)

The Symbol Scanner Panel is an MQL5 script designed as a powerful **data mining and analysis tool**. When executed, it scans through a list of symbols (either user-defined or all symbols available on the server) and filters them based on a wide range of criteria.

Its primary purpose is to help traders and developers quickly find instruments that meet specific trading conditions, such as having low spreads, specific contract sizes, or belonging to a particular market sector. The results are printed in a clean, tabular format in the "Experts" tab of the terminal, allowing for easy analysis and export.

## 2. Features and Scanned Data

The script is highly configurable through its input parameters and can filter symbols based on multiple criteria simultaneously. For each symbol that passes the filters, it displays the following key trading parameters:

- **Symbol:** The symbol's ticker name.
- **Spread:** The current spread in points.
- **Point:** The size of a single point.
- **Tick Value & Size:** The value and size of a single tick movement.
- **Volume Min/Step:** The minimum allowed trade volume and the step for increasing it.
- **Swaps:** The long and short swap rates.
- **Path:** The symbol's category path in the Market Watch (e.g., `CFD\Indices`).

## 3. MQL5 Implementation Details

The script was refactored into a clean, fully object-oriented structure to ensure its logic is modular, reusable, and easy to maintain.

- **Object-Oriented Design:** The entire scanning and filtering logic is encapsulated within a `CSymbolScanner` class. The script's entry point (`OnStart`) is minimal and is only responsible for creating an instance of this class with the user's input parameters and executing its `Run()` method.

- **Self-Contained Logic:** The script is completely self-contained and uses the standard `<Trade\SymbolInfo.mqh>` library for data retrieval. All helper functions for getting the symbol list, filtering, and printing are private methods of the `CSymbolScanner` class, avoiding the use of global functions.

- **Clear, Staged Execution:** The `Run()` method orchestrates the process in clear, sequential steps:

  1. Print the active filter criteria.
  2. Get the list of symbols to be scanned.
  3. Print the results table header.
  4. Loop through each symbol, gather its data, and check it against the filters.
  5. Print the data for any symbol that passes.
  6. Print a final summary.

- **Data Encapsulation:** A private `struct` named `SymbolData` is used within the class to neatly store all the relevant information for a single symbol. This makes the code cleaner by allowing a single data object to be passed between methods.

## 4. Usage and Practical Examples

To use the script, set your desired filter criteria in the input window and then drag it onto any chart. The results will be printed in the **Terminal -> Experts** tab.

### Example 1: Finding all Forex pairs with low spreads

You want to find all Forex pairs available on the server that are currently in your Market Watch and have a spread of 10 points or less.

- **`InpSymbolsToScan`**: `""` (leave empty to scan all server symbols)
- **`InpFilterPathContains`**: `"Forex"` (or your broker's specific path for forex, e.g., "Majors")
- **`InpFilterMarketWatch`**: `true`
- **`InpFilterMaxSpread`**: `10` _(Note: This parameter would need to be added to the script, but demonstrates the concept)_

### Example 2: Finding specific US stocks with a minimum trade size of 1 share

You want to check the swap rates and tick values for a specific list of stocks, but only if their minimum trade size is exactly 1 share (volume step of 1).

- **`InpSymbolsToScan`**: `"AAPL,GOOG,MSFT,AMZN"`
- **`InpSymbolSeparator`**: `","`
- **`InpFilterMinVolMin`**: `1.0`
- **`InpFilterMaxVolMin`**: `1.0`
- **`InpFilterMinVolStep`**: `1.0`
- **`InpFilterMaxVolStep`**: `1.0`
- **`InpFilterMarketWatch`**: `false` (to ensure it finds them even if not in Market Watch)

### Example 3: Finding all ETFs

You want a list of all available Exchange Traded Funds (ETFs).

- **`InpSymbolsToScan`**: `""`
- **`InpFilterOnlyETFs`**: `true`

## 5. Input Parameters

- **`InpSymbolsToScan`**: A comma-separated list of symbols to scan. If left empty, the script will scan all symbols available on the broker's server.
- **`InpSymbolSeparator`**: The character used to separate symbols in the list above.
- **`InpFilterPathContains`**: Filters for symbols whose path (in Market Watch) contains this text. E.g., "Forex", "Indices", "Crypto".
- **`InpFilterMarketWatch`**: If `true`, only scans symbols currently visible in your Market Watch window.
- **`InpFilterMin/MaxVolMin`**: Filters symbols based on their minimum allowed trade volume.
- **`InpFilterMin/MaxVolStep`**: Filters symbols based on their volume step (e.g., 0.01, 1).
- **`InpFilterOnlyETFs`**: If `true`, only shows symbols whose industry is "Exchange Traded Fund".
- **`InpFilterExtendedHours`**: If `true`, only shows symbols whose description contains the specified keyword.
- **`InpKeywordExtHours`**: The keyword to look for when `InpFilterExtendedHours` is active.
