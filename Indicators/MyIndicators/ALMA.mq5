//+------------------------------------------------------------------+
//|                                                          ALMA.mq5|
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.02" // Corrected calculation logic to match TradingView
#property description "Arnaud Legoux Moving Average (ALMA)"

//--- Indicator Window and Plot Properties ---
#property indicator_chart_window
#property indicator_buffers 2 // ALMA and a buffer for the source price
#property indicator_plots   1

//--- Plot 1: ALMA line
#property indicator_label1  "ALMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumVioletRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters ---
input int                InpAlmaPeriod   = 9;       // Window size (period)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied price
input double             InpAlmaOffset   = 0.85;    // Offset (0 to 1)
input double             InpAlmaSigma    = 6.0;     // Sigma (smoothness)

//--- Indicator Buffers ---
double    BufferALMA[];
double    BufferPrice[]; // A buffer to store the source price data

//--- Global Variables ---
int       ExtAlmaPeriod;
double    ExtAlmaOffset;
double    ExtAlmaSigma;
int       price_handle; // Handle for the source price indicator (iMA)

//--- Forward Declaration ---
double CalculateALMA(const int position, const double &price_array[]);

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- Validate and store input parameters
   ExtAlmaPeriod = (InpAlmaPeriod < 1) ? 1 : InpAlmaPeriod;
   ExtAlmaOffset = InpAlmaOffset;
   ExtAlmaSigma  = (InpAlmaSigma <= 0) ? 0.01 : InpAlmaSigma;

//--- Map the buffers and set them as non-timeseries
   SetIndexBuffer(0, BufferALMA,  INDICATOR_DATA);
   SetIndexBuffer(1, BufferPrice, INDICATOR_CALCULATIONS);
   ArraySetAsSeries(BufferALMA,  false);
   ArraySetAsSeries(BufferPrice, false);

//--- Create a handle to get the source price data
   price_handle = iMA(_Symbol, _Period, 1, 0, MODE_SMA, InpAppliedPrice);
   if(price_handle == INVALID_HANDLE)
     {
      Print("Error creating price source handle (iMA).");
     }

//--- Set indicator display properties
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtAlmaPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ALMA(%d, %.2f, %.1f)", ExtAlmaPeriod, ExtAlmaOffset, ExtAlmaSigma));
  }

//+------------------------------------------------------------------+
//| Arnaud Legoux Moving Average calculation function.               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- Check if there is enough historical data
   if(rates_total < ExtAlmaPeriod)
      return(0);

//--- Check if the source indicator is ready
   if(BarsCalculated(price_handle) < rates_total)
      return(0);

//--- Copy the source price data into our buffer
   if(CopyBuffer(price_handle, 0, 0, rates_total, BufferPrice) != rates_total)
     {
      Print("Error copying source price data.");
      return(0);
     }

//--- Main calculation loop (full recalculation for stability)
   for(int i = ExtAlmaPeriod - 1; i < rates_total; i++)
     {
      BufferALMA[i] = CalculateALMA(i, BufferPrice);
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Calculates a single ALMA value for a given position. (CORRECTED) |
//+------------------------------------------------------------------+
double CalculateALMA(const int position, const double &price_array[])
  {
   double m = ExtAlmaOffset * (ExtAlmaPeriod - 1.0);
   double s = (double)ExtAlmaPeriod / ExtAlmaSigma;

   double sum = 0.0;
   double norm = 0.0;

   for(int j = 0; j < ExtAlmaPeriod; j++)
     {
      double weight = MathExp(-1 * MathPow(j - m, 2) / (2 * s * s));

      // --- FIX: Correct indexing to match Pine Script's logic ---
      // This calculates the index of the bar within the sliding window,
      // starting from the oldest to the newest.
      int price_index = position - (ExtAlmaPeriod - 1) + j;

      sum += price_array[price_index] * weight;
      norm += weight;
     }

   if(norm > 0)
      return(sum / norm);
   else
      return(0.0);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
