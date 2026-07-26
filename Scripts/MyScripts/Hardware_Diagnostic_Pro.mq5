//+------------------------------------------------------------------+
//|                                   Hardware_Diagnostic_Pro.mq5     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.20" // Benchmark and diagnostic utility
#property description "QuantScan Hardware Diagnostic & Math Performance Script"
#property script_show_inputs

//--- Input parameters
input int InpStressIterations = 10000000; // Math Stress Test Iterations (e.g. 10M)

//+------------------------------------------------------------------+
//| OnStart                                                          |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("====================================================================");
   Print("              QUANTSCAN HARDWARE DIAGNOSTIC REPORT                  ");
   Print("====================================================================");

//--- Gather and print Terminal Information
   string terminal_company = TerminalInfoString(TERMINAL_COMPANY);
   string terminal_name    = TerminalInfoString(TERMINAL_NAME);
   string terminal_path    = TerminalInfoString(TERMINAL_PATH);
   int    terminal_build   = (int)TerminalInfoInteger(TERMINAL_BUILD);
   bool   is_connected     = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);

   PrintFormat("Terminal: %s | %s (Build %d)", terminal_company, terminal_name, terminal_build);
   PrintFormat("Data Path: %s", terminal_path);
   PrintFormat("Network Connection Status: %s", is_connected ? "CONNECTED" : "DISCONNECTED");

//--- Gather and print Environment Information
   string symbol = _Symbol;
   string timeframe = EnumToString(_Period);
   int    digits = _Digits;
   double point = _Point;

   PrintFormat("Active Chart: %s (%s) | Digits: %d | Point Size: %s",
               symbol, timeframe, digits, DoubleToString(point, digits));

   Print("--------------------------------------------------------------------");
   Print("              MATH PERFORMANCE BENCHMARK (SIMD SPEED TEST)          ");
   Print("--------------------------------------------------------------------");
   PrintFormat("Executing %d iterations of floating-point math operations...", InpStressIterations);

//--- Start high-precision microsecond timer
   ulong start_time = GetMicrosecondCount();

   double accumulator = 1.23456789;

//--- Heavy mathematical loop to stress CPU vector registers
   for(int i = 0; i < InpStressIterations; i++)
     {
      accumulator = MathSin(accumulator) + MathCos(accumulator);
      accumulator = MathLog(MathAbs(accumulator) + 1.0001);

      //--- Prevents loop optimizer from completely bypassing the calculation
      if(accumulator > 1000.0)
         accumulator = 1.23456789;
     }

   ulong elapsed_time_us = GetMicrosecondCount() - start_time;
   double elapsed_time_ms = (double)elapsed_time_us / 1000.0;

   PrintFormat("Benchmark Result: SUCCESS");
   PrintFormat("Accumulator Final Hash Value: %.8f", accumulator);
   PrintFormat("Total Execution Time: %.3f ms", elapsed_time_ms);
   Print("====================================================================");

//--- Visual Alert Summary
   string msg = StringFormat("Diagnostic Complete!\nExecution Time: %.2f ms\nHash: %.4f", elapsed_time_ms, accumulator);
   Alert(msg);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
