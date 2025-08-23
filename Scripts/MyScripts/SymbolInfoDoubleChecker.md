# Symbol Info Double Checker Script

## 1. Summary (Introduction)

The Symbol Info Double Checker is an MQL5 script designed as a **diagnostic and development tool**. When executed on a chart, it systematically queries and displays the status and value of every `ENUM_SYMBOL_INFO_DOUBLE` property for the chart's current symbol.

Its primary purpose is to provide developers and advanced traders with a quick and comprehensive way to check which data points are provided by their broker for a specific financial instrument. This is crucial for developing robust Expert Advisors and indicators, as it helps to identify which properties are supported and which are not, preventing potential runtime errors from requests for unavailable data.

## 2. Features and Displayed Data

The script iterates through a comprehensive, hard-coded list of all `ENUM_SYMBOL_INFO_DOUBLE` properties available in the MQL5 language. For each property, it prints a formatted line to the "Experts" tab of the terminal, indicating:

- **Property Name:** The official `enum` name of the property (e.g., `SYMBOL_TRADE_TICK_VALUE`).
- **Status:** Whether the request for the property was `SUPPORTED` or `FAILED`.
- **Value / Error:**
  - If **supported**, it displays the retrieved `double` value.
  - If **failed**, it displays the error code returned by `GetLastError()`, which can help in diagnosing the reason for the failure.

The output is neatly aligned in columns for easy readability.

## 3. MQL5 Implementation Details

The script was refactored to follow a clean, object-oriented, and modular design, making its logic reusable and easy to understand.

- **Object-Oriented Design:** The core logic is encapsulated within a `CSymbolPropertyChecker` class. This isolates the functionality from the script's entry point (`OnStart`).

  - The constructor takes the symbol name as an argument.
  - A single public method, `Run()`, executes the entire checking process.
  - Private helper methods (`PrintHeader`, `PrintFooter`, `PrintProperty`) break down the logic into smaller, manageable pieces.

- **Self-Contained Logic:** The script is completely self-contained. It uses the standard `<Trade\SymbolInfo.mqh>` library to interact with the terminal's symbol properties but does not rely on any external indicators or custom include files beyond that.

- **Static Property List:** The array of `ENUM_SYMBOL_INFO_DOUBLE` properties is defined as a `static const` member of the `CSymbolPropertyChecker` class. This logically associates the data with the class that uses it, which is a cleaner approach than using a global variable.

- **Simplified `OnStart`:** The script's entry point, `OnStart()`, is now extremely simple. It is only responsible for creating an instance of the `CSymbolPropertyChecker` class and calling its `Run()` method. This clear separation of concerns makes the code's execution flow easy to trace.

- **Formatted Output:** The script uses `StringFormat` with padding (`%-35s`) to ensure that the output in the "Experts" tab is well-aligned, making it easy to scan and compare the results for different properties.

## 4. Usage

1. **Installation:**
   - Place `SymbolInfoDoubleChecker.mq5` into your `MQL5\Scripts` folder.
2. **Execution:**
   - Open the chart of the symbol you wish to inspect.
   - Drag and drop the `SymbolInfoDoubleChecker` script from the Navigator window onto the chart.
3. **Review Output:**
   - Open the "Terminal" window (Ctrl+T).
   - Navigate to the "Experts" tab.
   - The script will print the full list of properties and their status for the selected symbol. The script terminates automatically after printing the list.

## 5. Parameters

This script has no adjustable input parameters. It always runs on the symbol of the chart it is attached to.
