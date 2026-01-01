//+------------------------------------------------------------------+
//|                                           TDI_CMO_Calculator.mqh |
//|        Calculation engine for TDI based on CMO.                  |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\CMO_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//+==================================================================+
//|             CLASS 1: CTDICMOCalculator (Base Class)              |
//+==================================================================+
class CTDICMOCalculator
  {
protected:
   int               m_cmo_period, m_price_period, m_signal_period, m_base_period;
   double            m_std_dev;

   //--- Engines
   CCMOCalculator    *m_cmo_calculator;
   CMovingAverageCalculator m_price_line_engine;
   CMovingAverageCalculator m_signal_line_engine;
   CMovingAverageCalculator m_base_line_engine;

   //--- Persistent Buffers
   double            m_cmo_buffer[];
   double            m_cmo_rescaled[];
   double            m_price_line[];
   double            m_base_line[];

   virtual bool      PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CTDICMOCalculator(void);
   virtual          ~CTDICMOCalculator(void);

   //--- Init now takes MA types (optional, default to SMA for classic TDI)
   bool              Init(int cmo_p, int price_p, int signal_p, int base_p, double dev, ENUM_MA_TYPE ma_type = SMA);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                               double &upper_band_out[], double &lower_band_out[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTDICMOCalculator::CTDICMOCalculator(void)
  {
   m_cmo_calculator = new CCMOCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTDICMOCalculator::~CTDICMOCalculator(void)
  {
   if(CheckPointer(m_cmo_calculator) != POINTER_INVALID)
      delete m_cmo_calculator;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CTDICMOCalculator::Init(int cmo_p, int price_p, int signal_p, int base_p, double dev, ENUM_MA_TYPE ma_type)
  {
   m_cmo_period    = (cmo_p < 1) ? 1 : cmo_p;
   m_price_period  = (price_p < 1) ? 1 : price_p;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_base_period   = (base_p < 1) ? 1 : base_p;
   m_std_dev       = (dev <= 0) ? 1.618 : dev;

   if(CheckPointer(m_cmo_calculator) == POINTER_INVALID)
      return false;
   if(!m_cmo_calculator.Init(m_cmo_period))
      return false;

// Initialize MA Engines (Classic TDI uses SMA, but we allow override)
   if(!m_price_line_engine.Init(m_price_period, ma_type))
      return false;
   if(!m_signal_line_engine.Init(m_signal_period, ma_type))
      return false;
   if(!m_base_line_engine.Init(m_base_period, ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CTDICMOCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                                  double &price_line_out[], double &signal_line_out[], double &base_line_out[],
                                  double &upper_band_out[], double &lower_band_out[])
  {
// Minimum bars check
   if(rates_total <= m_cmo_period + m_base_period)
      return;
   if(CheckPointer(m_cmo_calculator) == POINTER_INVALID)
      return;

   int start_index = (prev_calculated == 0) ? 0 : prev_calculated - 1;

// Resize Buffers
   if(ArraySize(m_cmo_buffer) != rates_total)
     {
      ArrayResize(m_cmo_buffer, rates_total);
      ArrayResize(m_cmo_rescaled, rates_total);
      ArrayResize(m_price_line, rates_total);
      ArrayResize(m_base_line, rates_total);
     }

   if(!PreparePriceSeries(rates_total, start_index, price_type, open, high, low, close))
      return;

//--- 1. Calculate CMO (Incremental)
   m_cmo_calculator.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, m_cmo_buffer);

//--- 2. Rescale CMO to 0-100 range
   int loop_start_cmo = MathMax(m_cmo_period, start_index);
   for(int i = loop_start_cmo; i < rates_total; i++)
     {
      // CMO is -100 to 100. Rescale to 0 to 100.
      m_cmo_rescaled[i] = (m_cmo_buffer[i] + 100.0) / 2.0;
     }

//--- 3. Calculate Price Line (MA on Rescaled CMO)
// Offset: m_cmo_period
   m_price_line_engine.CalculateOnArray(rates_total, prev_calculated, m_cmo_rescaled, m_price_line, m_cmo_period);
   ArrayCopy(price_line_out, m_price_line, 0, 0, rates_total);

//--- 4. Calculate Signal Line (MA on Price Line)
// Offset: m_cmo_period + m_price_period - 1
   int signal_offset = m_cmo_period + m_price_period - 1;
   m_signal_line_engine.CalculateOnArray(rates_total, prev_calculated, m_price_line, signal_line_out, signal_offset);

//--- 5. Calculate Base Line (MA on Price Line)
// Offset: same as signal line start (based on Price Line)
// But Base Line usually has longer period, so it starts later validly.
// The engine handles validity based on period.
   m_base_line_engine.CalculateOnArray(rates_total, prev_calculated, m_price_line, m_base_line, signal_offset);
   ArrayCopy(base_line_out, m_base_line, 0, 0, rates_total);

//--- 6. Calculate Volatility Bands (Bollinger Bands on Base Line)
// Bands are calculated using StdDev of Price Line around Base Line?
// Or StdDev of Rescaled CMO around Base Line?
// Original code used: StdDev of Rescaled CMO around Base Line (where Base Line is MA of Price Line).
// Wait, original code:
// base_line_ma_on_cmo = sum_cmo / m_base_period; (This IS the Base Line value at i)
// sum_sq += MathPow(cmo_rescaled[i-j] - base_line_ma_on_cmo, 2);
// So it calculates StdDev of CMO around the Base Line.

   int bands_start = m_cmo_period + m_base_period - 1; // Approx start
   int loop_start_bands = MathMax(bands_start, start_index);

   if(prev_calculated == 0)
     {
      ArrayInitialize(upper_band_out, EMPTY_VALUE);
      ArrayInitialize(lower_band_out, EMPTY_VALUE);
     }

   for(int i = loop_start_bands; i < rates_total; i++)
     {
      if(m_base_line[i] == EMPTY_VALUE)
         continue;

      double std_dev = 0, sum_sq = 0;
      // Standard Deviation of Rescaled CMO around the Base Line
      for(int j = 0; j < m_base_period; j++)
         sum_sq += MathPow(m_cmo_rescaled[i-j] - m_base_line[i], 2);

      std_dev = MathSqrt(sum_sq / m_base_period);

      upper_band_out[i] = m_base_line[i] + m_std_dev * std_dev;
      lower_band_out[i] = m_base_line[i] - m_std_dev * std_dev;
     }
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CTDICMOCalculator::PreparePriceSeries(int rates_total, int start_index, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// This method is just a placeholder for the base class.
// The CMO calculator handles its own data preparation internally.
   return true;
  }

//+==================================================================+
//|             CLASS 2: CTDICMOCalculator_HA (Heikin Ashi)          |
//+==================================================================+
class CTDICMOCalculator_HA : public CTDICMOCalculator
  {
public:
                     CTDICMOCalculator_HA(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTDICMOCalculator_HA::CTDICMOCalculator_HA(void)
  {
   if(CheckPointer(m_cmo_calculator) != POINTER_INVALID)
      delete m_cmo_calculator;
// Use HA version of CMO calculator
   m_cmo_calculator = new CCMOCalculator_HA();
  }
//+------------------------------------------------------------------+
