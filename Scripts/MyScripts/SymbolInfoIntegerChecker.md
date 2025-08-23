# Symbol Info Integer Checker Script

## 1. Summary (Introduction)

The Symbol Info Integer Checker is an MQL5 script designed as a **diagnostic and development tool**. When executed on a chart, it systematically queries and displays the status and value of every relevant `ENUM_SYMBOL_INFO_INTEGER` property for the chart's current symbol.

Its primary purpose is to provide developers and advanced traders with a quick and comprehensive way to check which integer-based data points are provided by their broker for a specific financial instrument. This is crucial for developing robust Expert Advisors and indicators, as many of a symbol's core trading rules and characteristics (e.g., execution modes, order types allowed) are defined by these integer properties.

## 2. Features and Displayed Data

The script iterates through a comprehensive, hard-coded list of all modern `ENUM_SYMBOL_INFO_INTEGER` properties. For each property, it prints a formatted line to the "Experts" tab of the terminal, indicating:

- **Property Name:** The official `enum` name of the property (e.g., `SYMBOL_TRADE_EXEMODE`).
- **Status:** Whether the request for the property was `SUPPORTED` or `FAILED`.
- **Value / Error:**
  - If **supported**, it displays the retrieved `long` value, intelligently formatted into a human-readable string (e.g., converting `SYMBOL_TRADE_EXEMODE`'s integer value to "Instant Execution", `datetime` values to a readable date, and booleans to "true"/"false").
  - If **failed**, it displays the error code returned by `GetLastError()`.

The output is neatly aligned in columns for easy readability.

## 3. MQL5 Implementation Details

The script was refactored to follow a clean, object-oriented, and modular design, making its logic reusable and easy to understand.

- **Object-Oriented Design:** The core logic is encapsulated within a `CSymbolIntegerPropertyChecker` class. This isolates the functionality from the script's entry point (`OnStart`).

  - The constructor takes the symbol name as an argument.
  - A single public method, `Run()`, executes the entire checking process.
  - Private helper methods (`PrintHeader`, `PrintFooter`, `PrintProperty`, `FormatValue`) break down the logic into smaller, manageable pieces.

- **Self-Contained Logic:** The script is completely self-contained. It uses the standard `<Trade\SymbolInfo.mqh>` library but does not require any custom include files. The formatting logic, which was previously in a separate file, has been integrated into the class as a private `FormatValue` method for better encapsulation.

- **Intelligent Formatting:** The `FormatValue` method contains a large `switch` block that correctly interprets the meaning of different integer properties. It uses helper methods from the `CSymbolInfo` class (e.g., `TradeModeDescription()`) or standard MQL5 functions (`TimeToString()`) to convert raw integer values into descriptive text, making the output far more useful than a simple list of numbers.

- **Static Property List:** The array of `ENUM_SYMBOL_INFO_INTEGER` properties is defined as a `static const` member of the `CSymbolIntegerPropertyChecker` class. This logically associates the data with the class that uses it, which is a cleaner approach than using a global variable.

- **Simplified `OnStart`:** The script's entry point, `OnStart()`, is now extremely simple. It is only responsible for creating an instance of the `CSymbolIntegerPropertyChecker` class and calling its `Run()` method.

## 4. Usage

1. **Installation:**
   - Place `SymbolInfoIntegerChecker.mq5` into your `MQL5\Scripts` folder.
2. **Execution:**
   - Open the chart of the symbol you wish to inspect.
   - Drag and drop the `SymbolInfoIntegerChecker` script from the Navigator window onto the chart.
3. **Review Output:**
   - Open the "Terminal" window (Ctrl+T).
   - Navigate to the "Experts" tab.
   - The script will print the full list of integer properties and their status for the selected symbol. The script terminates automatically after printing the list.

## 5. Parameters

This script has no adjustable input parameters. It always runs on the symbol of the chart it is attached to.
