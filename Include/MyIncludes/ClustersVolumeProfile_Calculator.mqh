//+------------------------------------------------------------------+
//|                                ClustersVolumeProfile_Calculator.mqh |
//|        Headless Pure Math Engine for Volume-Weighted K-Means      |
//|               Clustering and Multi-Regime Volume Profiles         |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, xxxxxxxx"
#property version     "2.10" // Enterprise: Added Heikin Ashi & Extended 100-Iteration Scaling
#property description "Mathematical engine for K-Means Regime Clustering with Heikin Ashi & Multi-Price Support."

#ifndef CLUSTERS_VOLUME_PROFILE_CALCULATOR_MQH
#define CLUSTERS_VOLUME_PROFILE_CALCULATOR_MQH

#include <MyIncludes\HeikinAshi_Tools.mqh>

//--- Structure for Individual Volume Profile Bins
struct SClusterVPBin
  {
   double            bottom_price;
   double            top_price;
   double            volume;
   bool              is_poc;
  };

//--- Structure for Cluster Output Data
struct SClusterData
  {
   int               cluster_id;
   double            centroid_price;
   int               member_count;
   double            price_min;
   double            price_max;
   double            total_volume;
   double            poc_price;
   double            poc_volume;
   int               poc_bin_index;
   SClusterVPBin     bins[];
  };

//+==================================================================+
//|   CLASS: CClustersVolumeProfile_Calculator                       |
//+==================================================================+
class CClustersVolumeProfile_Calculator
  {
private:
   // Persistent Calculation Arrays (Pre-allocated to eliminate heap-thrashing)
   double                    m_price[];
   double                    m_vols[];
   double                    m_highs[];
   double                    m_lows[];
   datetime                  m_times[];
   int                       m_assignments[];
   double                    m_centroids[];
   double                    m_sum_pv[];
   double                    m_sum_v[];
   double                    m_bin_vols[];

   // Heikin Ashi Preprocessing Buffers
   double                    m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];
   CHeikinAshi_Calculator    m_ha_engine;

   // Processed Output Clusters
   SClusterData              m_clusters[];
   int                       m_active_cluster_count;
   int                       m_lookback_processed;

   bool                      PrepareSourceData(const int n,
         const int rates_total,
         const ENUM_APPLIED_PRICE_HA_ALL price_source,
         const datetime &time[],
         const double &open[],
         const double &high[],
         const double &low[],
         const double &close[],
         const long &tick_volume[],
         const long &volume[]);

public:
                     CClustersVolumeProfile_Calculator(void);
                    ~CClustersVolumeProfile_Calculator(void);

   // Core Mathematical Execution Method
   bool                      Execute(const int rates_total,
                                     const int lookback,
                                     const int clusters_k,
                                     const int max_iterations,
                                     const int vp_rows,
                                     const ENUM_APPLIED_PRICE_HA_ALL price_source,
                                     const datetime &time[],
                                     const double &open[],
                                     const double &high[],
                                     const double &low[],
                                     const double &close[],
                                     const long &tick_volume[],
                                     const long &volume[]);

   // Accessor Methods
   int                       GetClusterCount(void) const { return m_active_cluster_count; }
   int                       GetLookbackProcessed(void) const { return m_lookback_processed; }
   int                       GetBarAssignment(const int bar_idx) const; // 0 = newest bar in window
   double                    GetBarPrice(const int bar_idx) const;
   datetime                  GetBarTime(const int bar_idx) const;

   bool                      GetClusterData(const int cluster_index, SClusterData &out_cluster) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CClustersVolumeProfile_Calculator::CClustersVolumeProfile_Calculator(void) :
   m_active_cluster_count(0),
   m_lookback_processed(0)
  {
   ArraySetAsSeries(m_price,       false);
   ArraySetAsSeries(m_vols,        false);
   ArraySetAsSeries(m_highs,       false);
   ArraySetAsSeries(m_lows,        false);
   ArraySetAsSeries(m_times,       false);
   ArraySetAsSeries(m_assignments, false);
   ArraySetAsSeries(m_centroids,   false);
   ArraySetAsSeries(m_sum_pv,      false);
   ArraySetAsSeries(m_sum_v,       false);
   ArraySetAsSeries(m_bin_vols,    false);
   ArraySetAsSeries(m_ha_open,     false);
   ArraySetAsSeries(m_ha_high,     false);
   ArraySetAsSeries(m_ha_low,      false);
   ArraySetAsSeries(m_ha_close,    false);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CClustersVolumeProfile_Calculator::~CClustersVolumeProfile_Calculator(void)
  {
   ArrayFree(m_price);
   ArrayFree(m_vols);
   ArrayFree(m_highs);
   ArrayFree(m_lows);
   ArrayFree(m_times);
   ArrayFree(m_assignments);
   ArrayFree(m_centroids);
   ArrayFree(m_sum_pv);
   ArrayFree(m_sum_v);
   ArrayFree(m_bin_vols);
   ArrayFree(m_ha_open);
   ArrayFree(m_ha_high);
   ArrayFree(m_ha_low);
   ArrayFree(m_ha_close);
   ArrayFree(m_clusters);
  }

//+------------------------------------------------------------------+
//| Prepare Source Data (Supports Standard & Heikin Ashi Pipelines)  |
//+------------------------------------------------------------------+
bool CClustersVolumeProfile_Calculator::PrepareSourceData(const int n,
      const int rates_total,
      const ENUM_APPLIED_PRICE_HA_ALL price_source,
      const datetime &time[],
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[],
      const long &tick_volume[],
      const long &volume[])
  {
   bool is_ha = (price_source <= PRICE_HA_CLOSE);

   if(is_ha)
     {
      if(ArraySize(m_ha_open) != rates_total)
        {
         ArrayResize(m_ha_open,  rates_total);
         ArrayResize(m_ha_high,  rates_total);
         ArrayResize(m_ha_low,   rates_total);
         ArrayResize(m_ha_close, rates_total);
         ArraySetAsSeries(m_ha_open,  false);
         ArraySetAsSeries(m_ha_high,  false);
         ArraySetAsSeries(m_ha_low,   false);
         ArraySetAsSeries(m_ha_close, false);
        }

      // Compute full Heikin Ashi series
      m_ha_engine.Calculate(rates_total, 0, open, high, low, close,
                            m_ha_open, m_ha_high, m_ha_low, m_ha_close);
     }

   for(int i = 0; i < n; i++)
     {
      int src_idx = rates_total - 1 - i;
      m_times[i]  = time[src_idx];

      // Volume selection (Real volume priority, fallback to tick volume)
      double v = (volume[src_idx] > 0) ? (double)volume[src_idx] : (double)tick_volume[src_idx];
      m_vols[i] = (v <= 0.0) ? 1.0 : v;

      if(is_ha)
        {
         m_highs[i] = m_ha_high[src_idx];
         m_lows[i]  = m_ha_low[src_idx];

         switch(price_source)
           {
            case PRICE_HA_OPEN:
               m_price[i] = m_ha_open[src_idx];
               break;
            case PRICE_HA_HIGH:
               m_price[i] = m_ha_high[src_idx];
               break;
            case PRICE_HA_LOW:
               m_price[i] = m_ha_low[src_idx];
               break;
            case PRICE_HA_MEDIAN:
               m_price[i] = (m_ha_high[src_idx] + m_ha_low[src_idx]) * 0.5;
               break;
            case PRICE_HA_TYPICAL:
               m_price[i] = (m_ha_high[src_idx] + m_ha_low[src_idx] + m_ha_close[src_idx]) * 0.333333333333;
               break;
            case PRICE_HA_WEIGHTED:
               m_price[i] = (m_ha_high[src_idx] + m_ha_low[src_idx] + 2.0 * m_ha_close[src_idx]) * 0.25;
               break;
            case PRICE_HA_CLOSE:
            default:
               m_price[i] = m_ha_close[src_idx];
               break;
           }
        }
      else
        {
         m_highs[i] = high[src_idx];
         m_lows[i]  = low[src_idx];

         switch(price_source)
           {
            case PRICE_OPEN_STD:
               m_price[i] = open[src_idx];
               break;
            case PRICE_HIGH_STD:
               m_price[i] = high[src_idx];
               break;
            case PRICE_LOW_STD:
               m_price[i] = low[src_idx];
               break;
            case PRICE_MEDIAN_STD:
               m_price[i] = (high[src_idx] + low[src_idx]) * 0.5;
               break;
            case PRICE_TYPICAL_STD:
               m_price[i] = (high[src_idx] + low[src_idx] + close[src_idx]) * 0.333333333333;
               break;
            case PRICE_WEIGHTED_STD:
               m_price[i] = (high[src_idx] + low[src_idx] + 2.0 * close[src_idx]) * 0.25;
               break;
            case PRICE_CLOSE_STD:
            default:
               m_price[i] = close[src_idx];
               break;
           }
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Core Execution Method (Allows up to 100 Iterations safely)       |
//+------------------------------------------------------------------+
bool CClustersVolumeProfile_Calculator::Execute(const int rates_total,
      const int lookback,
      const int clusters_k,
      const int max_iterations,
      const int vp_rows,
      const ENUM_APPLIED_PRICE_HA_ALL price_source,
      const datetime &time[],
      const double &open[],
      const double &high[],
      const double &low[],
      const double &close[],
      const long &tick_volume[],
      const long &volume[])
  {
   int n = MathMin(lookback, rates_total);
   if(n < 10)
      return false;

   int k = MathMin(MathMax(clusters_k, 2), 10);
   int iterations = MathMin(MathMax(max_iterations, 5), 100); // Expanded up to 100
   int rows = MathMax(vp_rows, 2);

   m_lookback_processed   = n;
   m_active_cluster_count = k;

// 1. Allocate Internal Work Buffers
   if(ArraySize(m_price) != n)
     {
      ArrayResize(m_price,       n);
      ArrayResize(m_vols,        n);
      ArrayResize(m_highs,       n);
      ArrayResize(m_lows,        n);
      ArrayResize(m_times,       n);
      ArrayResize(m_assignments, n);
     }

   if(ArraySize(m_centroids) != k)
     {
      ArrayResize(m_centroids, k);
      ArrayResize(m_sum_pv,    k);
      ArrayResize(m_sum_v,     k);
     }

   if(ArraySize(m_bin_vols) != rows)
      ArrayResize(m_bin_vols, rows);

   if(ArraySize(m_clusters) != k)
      ArrayResize(m_clusters, k);

// 2. Prepare Source Data
   if(!PrepareSourceData(n, rates_total, price_source, time, open, high, low, close, tick_volume, volume))
      return false;

   double min_price =  1.0e10;
   double max_price = -1.0e10;
   for(int i = 0; i < n; i++)
     {
      if(m_price[i] < min_price)
         min_price = m_price[i];
      if(m_price[i] > max_price)
         max_price = m_price[i];
     }

   if(max_price - min_price < 1.0e-9)
      return false;

// 3. Seed Centroids Linearly
   double step = (max_price - min_price) / (double)(k + 1);
   for(int j = 0; j < k; j++)
      m_centroids[j] = min_price + (double)(j + 1) * step;

// 4. Volume-Weighted K-Means Clustering with Early Exit
   for(int iter = 0; iter < iterations; iter++)
     {
      int assignment_changes = 0;

      for(int i = 0; i < n; i++)
        {
         double p = m_price[i];
         int best_k = 0;
         double min_dist = 1.0e10;

         for(int j = 0; j < k; j++)
           {
            double dist = MathAbs(p - m_centroids[j]);
            if(dist < min_dist)
              {
               min_dist = dist;
               best_k   = j;
              }
           }

         if(m_assignments[i] != best_k)
           {
            m_assignments[i] = best_k;
            assignment_changes++;
           }
        }

      // Early convergence: If no bars flipped clusters, terminate instantly!
      if(iter > 0 && assignment_changes == 0)
         break;

      ArrayInitialize(m_sum_pv, 0.0);
      ArrayInitialize(m_sum_v,  0.0);

      for(int i = 0; i < n; i++)
        {
         int cl = m_assignments[i];
         m_sum_pv[cl] += m_price[i] * m_vols[i];
         m_sum_v[cl]  += m_vols[i];
        }

      for(int j = 0; j < k; j++)
        {
         if(m_sum_v[j] > 0.0)
            m_centroids[j] = m_sum_pv[j] / m_sum_v[j];
        }
     }

// 5. Build High-Resolution Cluster Volume Profiles
   for(int c_id = 0; c_id < k; c_id++)
     {
      m_clusters[c_id].cluster_id     = c_id;
      m_clusters[c_id].centroid_price = m_centroids[c_id];
      m_clusters[c_id].member_count   = 0;
      m_clusters[c_id].price_min      =  1.0e10;
      m_clusters[c_id].price_max      = -1.0e10;
      m_clusters[c_id].total_volume   = 0.0;
      m_clusters[c_id].poc_price      = 0.0;
      m_clusters[c_id].poc_volume     = 0.0;
      m_clusters[c_id].poc_bin_index  = 0;

      for(int i = 0; i < n; i++)
        {
         if(m_assignments[i] == c_id)
           {
            m_clusters[c_id].member_count++;
            if(m_lows[i]  < m_clusters[c_id].price_min)
               m_clusters[c_id].price_min = m_lows[i];
            if(m_highs[i] > m_clusters[c_id].price_max)
               m_clusters[c_id].price_max = m_highs[i];
            m_clusters[c_id].total_volume += m_vols[i];
           }
        }

      if(m_clusters[c_id].member_count == 0)
        {
         ArrayResize(m_clusters[c_id].bins, 0);
         continue;
        }

      ArrayResize(m_clusters[c_id].bins, rows);
      ArrayInitialize(m_bin_vols, 0.0);

      double c_min = m_clusters[c_id].price_min;
      double c_max = m_clusters[c_id].price_max;
      double bin_size = (c_max - c_min) / (double)rows;
      if(bin_size <= 1.0e-9)
         bin_size = _Point;

      for(int i = 0; i < n; i++)
        {
         if(m_assignments[i] == c_id)
           {
            double b_h = m_highs[i];
            double b_l = m_lows[i];
            double b_v = m_vols[i];
            double wick_range = MathMax(b_h - b_l, _Point);
            double inv_wick_range = 1.0 / wick_range;

            for(int b_idx = 0; b_idx < rows; b_idx++)
              {
               double bin_b = c_min + (double)b_idx * bin_size;
               double bin_t = bin_b + bin_size;
               double intersect_l = MathMax(b_l, bin_b);
               double intersect_h = MathMin(b_h, bin_t);

               if(intersect_h > intersect_l)
                  m_bin_vols[b_idx] += b_v * (intersect_h - intersect_l) * inv_wick_range;
              }
           }
        }

      double max_bin_vol = 0.0;
      int poc_idx = 0;

      for(int b_idx = 0; b_idx < rows; b_idx++)
        {
         if(m_bin_vols[b_idx] > max_bin_vol)
           {
            max_bin_vol = m_bin_vols[b_idx];
            poc_idx     = b_idx;
           }
        }

      m_clusters[c_id].poc_volume    = max_bin_vol;
      m_clusters[c_id].poc_bin_index = poc_idx;
      m_clusters[c_id].poc_price     = c_min + ((double)poc_idx + 0.5) * bin_size;

      for(int b_idx = 0; b_idx < rows; b_idx++)
        {
         m_clusters[c_id].bins[b_idx].bottom_price = c_min + (double)b_idx * bin_size;
         m_clusters[c_id].bins[b_idx].top_price    = m_clusters[c_id].bins[b_idx].bottom_price + bin_size;
         m_clusters[c_id].bins[b_idx].volume       = m_bin_vols[b_idx];
         m_clusters[c_id].bins[b_idx].is_poc       = (b_idx == poc_idx);
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Accessor Methods                                                 |
//+------------------------------------------------------------------+
int CClustersVolumeProfile_Calculator::GetBarAssignment(const int bar_idx) const
  {
   if(bar_idx >= 0 && bar_idx < m_lookback_processed)
      return m_assignments[bar_idx];
   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CClustersVolumeProfile_Calculator::GetBarPrice(const int bar_idx) const
  {
   if(bar_idx >= 0 && bar_idx < m_lookback_processed)
      return m_price[bar_idx];
   return 0.0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime CClustersVolumeProfile_Calculator::GetBarTime(const int bar_idx) const
  {
   if(bar_idx >= 0 && bar_idx < m_lookback_processed)
      return m_times[bar_idx];
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CClustersVolumeProfile_Calculator::GetClusterData(const int cluster_index, SClusterData &out_cluster) const
  {
   if(cluster_index >= 0 && cluster_index < m_active_cluster_count)
     {
      out_cluster = m_clusters[cluster_index];
      return true;
     }
   return false;
  }

#endif // CLUSTERS_VOLUME_PROFILE_CALCULATOR_MQH
//+------------------------------------------------------------------+
