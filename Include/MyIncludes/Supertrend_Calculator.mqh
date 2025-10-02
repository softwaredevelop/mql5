//+------------------------------------------------------------------+
//|                                          Supertrend_Calculator.mqh|
//|    Calculation engine for Standard and Heikin Ashi Supertrend.   |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\ATR_Calculator.mqh> // Re-use our robust ATR calculator

//--- CORRECTED: The ENUM_ATR_SOURCE is now defined inside ATR_Calculator.mqh ---

//+==================================================================+
//|                                                                  |
//|           CLASS 1: CSupertrendCalculator (Base Class)            |
//|                                                                  |
//+==================================================================+
class CSupertrendCalculator
  {
protected:
   int               m_atr_period;
   double            m_factor;

   CATRCalculator    *m_atr_calculator;

   double            m_src_high[], m_src_low[], m_src_close[];

   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]);

public:
                     CSupertrendCalculator(void);
   virtual          ~CSupertrendCalculator(void);

   bool              Init(int atr_p, double factor, ENUM_ATR_SOURCE atr_src);
   void              Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &st_buffer[], double &color_buffer[]);
  };

//+------------------------------------------------------------------+
//| CSupertrendCalculator: Constructor                               |
//+------------------------------------------------------------------+
CSupertrendCalculator::CSupertrendCalculator(void)
  {
   m_atr_calculator = NULL; // Initialize pointer to NULL
  }

//+------------------------------------------------------------------+
//| CSupertrendCalculator: Destructor                                |
//+------------------------------------------------------------------+
CSupertrendCalculator::~CSupertrendCalculator(void)
  {
   if(CheckPointer(m_atr_calculator) != POINTER_INVALID)
      delete m_atr_calculator;
  }

//+------------------------------------------------------------------+
//| CSupertrendCalculator: Initialization                            |
//+------------------------------------------------------------------+
bool CSupertrendCalculator::Init(int atr_p, double factor, ENUM_ATR_SOURCE atr_src)
  {
   m_atr_period = (atr_p < 1) ? 1 : atr_p;
   m_factor     = (factor <= 0) ? 3.0 : factor;

   if(CheckPointer(m_atr_calculator) != POINTER_INVALID)
      delete m_atr_calculator;

   if(atr_src == ATR_SOURCE_HEIKIN_ASHI)
     {
      m_atr_calculator = new CATRCalculator_HA();
     }
   else
     {
      m_atr_calculator = new CATRCalculator();
     }

   if(CheckPointer(m_atr_calculator) == POINTER_INVALID)
      return false;
   return m_atr_calculator.Init(m_atr_period);
  }

//+------------------------------------------------------------------+
//| CSupertrendCalculator: Main Calculation Method (Shared Logic)    |
//+------------------------------------------------------------------+
void CSupertrendCalculator::Calculate(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[],
                                      double &st_buffer[], double &color_buffer[])
  {
   if(rates_total <= m_atr_period || CheckPointer(m_atr_calculator) == POINTER_INVALID)
      return;
   if(!PrepareSourceData(rates_total, open, high, low, close))
      return;

   double atr[], upper[], lower[], trend[];
   ArrayResize(atr, rates_total);
   ArrayResize(upper, rates_total);
   ArrayResize(lower, rates_total);
   ArrayResize(trend, rates_total);

   m_atr_calculator.Calculate(rates_total, open, high, low, close, atr);

   for(int i = 1; i < rates_total; i++)
     {
      double hl2 = (m_src_high[i] + m_src_low[i]) / 2.0;
      double atr_val = m_factor * atr[i];

      double upper_basic = hl2 + atr_val;
      double lower_basic = hl2 - atr_val;

      if(upper_basic < upper[i-1] || m_src_close[i-1] > upper[i-1])
         upper[i] = upper_basic;
      else
         upper[i] = upper[i-1];

      if(lower_basic > lower[i-1] || m_src_close[i-1] < lower[i-1])
         lower[i] = lower_basic;
      else
         lower[i] = lower[i-1];

      if(i == m_atr_period)
         trend[i] = (m_src_close[i] > hl2) ? 1 : -1;
      else
         if(i > m_atr_period)
           {
            if(trend[i-1] == 1 && m_src_close[i] < lower[i])
               trend[i] = -1;
            else
               if(trend[i-1] == -1 && m_src_close[i] > upper[i])
                  trend[i] = 1;
               else
                  trend[i] = trend[i-1];
           }

      if(trend[i] == 1)
        {
         st_buffer[i] = lower[i];
         color_buffer[i] = 0;
         if(trend[i-1] == -1)
            st_buffer[i-1] = lower[i];
        }
      else
        {
         st_buffer[i] = upper[i];
         color_buffer[i] = 1;
         if(trend[i-1] == 1)
            st_buffer[i-1] = upper[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| CSupertrendCalculator: Prepares the standard source data.        |
//+------------------------------------------------------------------+
bool CSupertrendCalculator::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   ArrayResize(m_src_high, rates_total);
   ArrayCopy(m_src_high, high, 0, 0, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayCopy(m_src_low, low, 0, 0, rates_total);
   ArrayResize(m_src_close, rates_total);
   ArrayCopy(m_src_close, close, 0, 0, rates_total);
   return true;
  }

//+==================================================================+
//|                                                                  |
//|         CLASS 2: CSupertrendCalculator_HA (Heikin Ashi)          |
//|                                                                  |
//+==================================================================+
class CSupertrendCalculator_HA : public CSupertrendCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
protected:
   virtual bool      PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| CSupertrendCalculator_HA: Prepares the HA source data.           |
//+------------------------------------------------------------------+
bool CSupertrendCalculator_HA::PrepareSourceData(int rates_total, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double ha_open[];
   ArrayResize(ha_open, rates_total);
   ArrayResize(m_src_high, rates_total);
   ArrayResize(m_src_low, rates_total);
   ArrayResize(m_src_close, rates_total);
   m_ha_calculator.Calculate(rates_total, open, high, low, close, ha_open, m_src_high, m_src_low, m_src_close);
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
