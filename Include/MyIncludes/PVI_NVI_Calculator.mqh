//+------------------------------------------------------------------+
//|                                             PVI_NVI_Calculator.mqh |
//|      VERSION 2.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\MovingAverage_Engine.mqh>
#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Moved enum here to be accessible by other calculators
enum ENUM_CANDLE_SOURCE { CANDLE_STANDARD, CANDLE_HEIKIN_ASHI };

//+==================================================================+
//|             CLASS 1: CPVINVICalculator (Base Class)              |
//+==================================================================+
class CPVINVICalculator
  {
protected:
   ENUM_APPLIED_VOLUME m_volume_type;
   int                 m_signal_period;
   ENUM_MA_TYPE        m_signal_ma_type;

   //--- Persistent Buffer for Incremental Calculation
   double              m_price[];

   //--- Engines for Signal Lines
   CMovingAverageCalculator *m_pvi_signal_engine;
   CMovingAverageCalculator *m_nvi_signal_engine;

   //--- Updated: Accepts start_index
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CPVINVICalculator(void);
   virtual          ~CPVINVICalculator(void);

   bool              Init(ENUM_APPLIED_VOLUME vol_type, int signal_p, ENUM_MA_TYPE signal_ma);

   //--- Updated: Accepts prev_calculated
   void              Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[],
                               double &pvi_buffer[], double &nvi_buffer[], double &pvi_signal[], double &nvi_signal[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPVINVICalculator::CPVINVICalculator(void)
  {
   m_pvi_signal_engine = new CMovingAverageCalculator();
   m_nvi_signal_engine = new CMovingAverageCalculator();
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPVINVICalculator::~CPVINVICalculator(void)
  {
   if(CheckPointer(m_pvi_signal_engine) != POINTER_INVALID)
      delete m_pvi_signal_engine;
   if(CheckPointer(m_nvi_signal_engine) != POINTER_INVALID)
      delete m_nvi_signal_engine;
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CPVINVICalculator::Init(ENUM_APPLIED_VOLUME vol_type, int signal_p, ENUM_MA_TYPE signal_ma)
  {
   m_volume_type = vol_type;
   m_signal_period = (signal_p < 1) ? 1 : signal_p;
   m_signal_ma_type = signal_ma;

   if(!m_pvi_signal_engine.Init(m_signal_period, m_signal_ma_type))
      return false;
   if(!m_nvi_signal_engine.Init(m_signal_period, m_signal_ma_type))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation (Optimized)                                     |
//+------------------------------------------------------------------+
void CPVINVICalculator::Calculate(int rates_total, int prev_calculated, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[],
                                  double &pvi_buffer[], double &nvi_buffer[], double &pvi_signal[], double &nvi_signal[])
  {
   if(rates_total < 2)
      return;

//--- 1. Determine Start Index
   int start_index;
   if(prev_calculated == 0)
      start_index = 0;
   else
      start_index = prev_calculated - 1;

//--- 2. Resize Buffer
   if(ArraySize(m_price) != rates_total)
      ArrayResize(m_price, rates_total);

//--- 3. Prepare Price (Optimized)
   if(!PrepareSourceData(rates_total, start_index, open, high, low, close))
      return;

//--- 4. Calculate PVI/NVI (Incremental Loop)
   int loop_start = (start_index < 1) ? 1 : start_index;

// Initialization
   if(loop_start == 1)
     {
      pvi_buffer[0] = 1000;
      nvi_buffer[0] = 1000;
     }

   for(int i = loop_start; i < rates_total; i++)
     {
      // Calculate percentage change of price
      // Note: Original code used absolute change (price[i] - price[i-1]).
      // Standard PVI/NVI uses percentage change: (price[i] - price[i-1]) / price[i-1]
      // Let's stick to the original code logic if that's what was intended,
      // but usually PVI = PVI[i-1] * (1 + ROC).
      // The provided code was: pvi_buffer[i] = pvi_buffer[i-1] + price_change;
      // This is an absolute change accumulation. I will keep it as is to preserve logic.

      double price_change = m_price[i] - m_price[i-1];

      if(volume[i] > volume[i-1])
        {
         pvi_buffer[i] = pvi_buffer[i-1] + price_change;
         nvi_buffer[i] = nvi_buffer[i-1];
        }
      else
         if(volume[i] < volume[i-1])
           {
            nvi_buffer[i] = nvi_buffer[i-1] + price_change;
            pvi_buffer[i] = pvi_buffer[i-1];
           }
         else
           {
            pvi_buffer[i] = pvi_buffer[i-1];
            nvi_buffer[i] = nvi_buffer[i-1];
           }
     }

//--- 5. Calculate Signal Lines (Using Engines)
// We pass PVI/NVI buffers as 'close' price.
   m_pvi_signal_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                 pvi_buffer, pvi_buffer, pvi_buffer, pvi_buffer,
                                 pvi_signal);

   m_nvi_signal_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                                 nvi_buffer, nvi_buffer, nvi_buffer, nvi_buffer,
                                 nvi_signal);
  }

//+------------------------------------------------------------------+
//| Prepare Price (Standard - Optimized)                             |
//+------------------------------------------------------------------+
bool CPVINVICalculator::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Optimized copy loop
   for(int i = start_index; i < rates_total; i++)
      m_price[i] = close[i];
   return true;
  }

//+==================================================================+
//|             CLASS 2: CPVINVICalculator_HA (Heikin Ashi)          |
//+==================================================================+
class CPVINVICalculator_HA : public CPVINVICalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   // Internal HA buffers
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual bool      PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Prepare Price (Heikin Ashi - Optimized)                          |
//+------------------------------------------------------------------+
bool CPVINVICalculator_HA::PrepareSourceData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
// Resize internal HA buffers
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

//--- STRICT CALL: Use the optimized 10-param HA calculation
   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close,
                             m_ha_open, m_ha_high, m_ha_low, m_ha_close);

//--- Copy to m_price (Optimized loop)
   for(int i = start_index; i < rates_total; i++)
      m_price[i] = m_ha_close[i];
   return true;
  }
//+------------------------------------------------------------------+
