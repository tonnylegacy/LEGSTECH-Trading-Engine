//+------------------------------------------------------------------+
//|                                                SessionFilter.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_INDICATORS_SESSIONFILTER_MQH
#define LEGSTECH_INDICATORS_SESSIONFILTER_MQH

#include <Object.mqh>
#include "..\Core\Defs.mqh"

//+------------------------------------------------------------------+
//| Class CSessionFilter                                             |
//| D1 Daily Bias, 8AM/8PM UTC Session Windows & M15 Pullback Reset  |
//+------------------------------------------------------------------+
class CSessionFilter : public CObject
{
private:
   string            m_symbol;
   int               m_brokerUtcOffset;      // e.g., +2 or +3 for GMT+2/GMT+3 brokers
   int               m_morningHourUtc;       // Default: 8
   int               m_eveningHourUtc;       // Default: 20
   int               m_windowDurationMins;   // Default: 90 mins
   int               m_requiredPullbackBars; // Default: 1 (M15 counter candles to reset lock)
   
   // State tracking
   bool              m_continuationLocked;
   int               m_consecutivePullbackBars;

public:
                     CSessionFilter(void);
   virtual          ~CSessionFilter(void);
                     
   bool              Init(const string symbol,
                          int brokerUtcOffset = 2,
                          int morningUtc = 8,
                          int eveningUtc = 20,
                          int windowMins = 90,
                          int requiredPullbackBars = 1);
   
   // Daily Bias Evaluation
   ENUM_DAILY_BIAS   EvaluateDailyBias(void);
   ENUM_DAILY_BIAS   EvaluateDailyBiasFromRates(const MqlRates &d1Rates[], int totalRates);
   
   // Session Window Timing
   bool              IsInsideSessionWindow(datetime serverTime, bool &outIsMorning, bool &outIsEvening);
   bool              IsRolloverIlliquidWindow(datetime serverTime) const;
   int               GetServerHourForUtc(int utcHour) const;
   static bool       IsInsideGmtTradingWindow(int startHourGmt = 7, int endHourGmt = 20);
   
   // Continuation Lock & Pullback Engine
   void              SetContinuationLock(bool locked) { m_continuationLocked = locked; }
   bool              IsContinuationLocked(void) const { return m_continuationLocked; }
   
   void              SetRequiredPullbackBars(int count) { m_requiredPullbackBars = (count > 0) ? count : 1; }
   int               GetRequiredPullbackBars(void) const { return m_requiredPullbackBars; }
   
   bool              EvaluateM15PullbackResetFromRates(const MqlRates &m15Rates[], int totalRates, ENUM_DAILY_BIAS bias);
   void              ResetPullbackCounter(void) { m_consecutivePullbackBars = 0; }
   int               GetPullbackCount(void) const { return m_consecutivePullbackBars; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSessionFilter::CSessionFilter(void)
{
   m_symbol                  = "";
   m_brokerUtcOffset         = 2;
   m_morningHourUtc          = 8;
   m_eveningHourUtc          = 20;
   m_windowDurationMins      = 90;
   m_requiredPullbackBars    = 1;
   m_continuationLocked      = false;
   m_consecutivePullbackBars = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSessionFilter::~CSessionFilter(void)
{
}

//+------------------------------------------------------------------+
//| Initialize Session Filter                                        |
//+------------------------------------------------------------------+
inline bool CSessionFilter::Init(const string symbol,
                                int brokerUtcOffset,
                                int morningUtc,
                                int eveningUtc,
                                int windowMins,
                                int requiredPullbackBars)
{
   m_symbol                  = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_brokerUtcOffset         = brokerUtcOffset;
   m_morningHourUtc          = morningUtc;
   m_eveningHourUtc          = eveningUtc;
   m_windowDurationMins      = (windowMins > 0) ? windowMins : 90;
   m_requiredPullbackBars    = (requiredPullbackBars > 0) ? requiredPullbackBars : 1;
   m_continuationLocked      = false;
   m_consecutivePullbackBars = 0;
   return true;
}

//+------------------------------------------------------------------+
//| Live: Evaluate Daily Bias from D1 timeframe                      |
//+------------------------------------------------------------------+
inline ENUM_DAILY_BIAS CSessionFilter::EvaluateDailyBias(void)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(m_symbol, PERIOD_D1, 0, 5, rates);
   if(copied < 2)
      return DAILY_BIAS_NONE;
      
   return EvaluateDailyBiasFromRates(rates, copied);
}

//+------------------------------------------------------------------+
//| Array: Evaluate Daily Bias from D1 Rates array                   |
//+------------------------------------------------------------------+
inline ENUM_DAILY_BIAS CSessionFilter::EvaluateDailyBiasFromRates(const MqlRates &d1Rates[], int totalRates)
{
   if(totalRates < 2)
      return DAILY_BIAS_NONE;
      
   // Bar 1 is newest completed D1 bar
   const MqlRates d1Bar = d1Rates[1];
   
   if(d1Bar.close > d1Bar.open)
      return DAILY_BIAS_BULLISH;
   else if(d1Bar.close < d1Bar.open)
      return DAILY_BIAS_BEARISH;
      
   return DAILY_BIAS_NONE;
}

//+------------------------------------------------------------------+
//| Convert UTC Hour to Broker Server Hour                           |
//+------------------------------------------------------------------+
inline int CSessionFilter::GetServerHourForUtc(int utcHour) const
{
   return ((utcHour + m_brokerUtcOffset + 24) % 24);
}

//+------------------------------------------------------------------+
//| Check if serverTime falls inside 8:00 AM or 8:00 PM window       |
//+------------------------------------------------------------------+
inline bool CSessionFilter::IsInsideSessionWindow(datetime serverTime, bool &outIsMorning, bool &outIsEvening)
{
   outIsMorning = false;
   outIsEvening = false;
   
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   
   int currentMinutesFromMidnight = dt.hour * 60 + dt.min;
   
   int morningServerHour = GetServerHourForUtc(m_morningHourUtc);
   int morningStartMins  = morningServerHour * 60;
   int morningEndMins    = morningStartMins + m_windowDurationMins;
   
   int eveningServerHour = GetServerHourForUtc(m_eveningHourUtc);
   int eveningStartMins  = eveningServerHour * 60;
   int eveningEndMins    = eveningStartMins + m_windowDurationMins;
   
   // Handle midnight wrapping if applicable
   if(currentMinutesFromMidnight >= morningStartMins && currentMinutesFromMidnight < morningEndMins)
   {
      outIsMorning = true;
      return true;
   }
   
   if(currentMinutesFromMidnight >= eveningStartMins && currentMinutesFromMidnight < eveningEndMins)
   {
      outIsEvening = true;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if serverTime falls inside 17:00-21:00 UTC rollover freeze |
//+------------------------------------------------------------------+
inline bool CSessionFilter::IsRolloverIlliquidWindow(datetime serverTime) const
{
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   int utcHour = (dt.hour - m_brokerUtcOffset + 24) % 24;
   // 17:00 UTC to 20:59:59 UTC is the rollover / low-liquidity freeze
   return (utcHour >= 17 && utcHour < 21);
}

//+------------------------------------------------------------------+
//| Check if current GMT time falls inside active trading window     |
//| Default: 07:00 GMT - 20:00 GMT (Blocks Asian & Rollover)         |
//+------------------------------------------------------------------+
inline bool CSessionFilter::IsInsideGmtTradingWindow(int startHourGmt, int endHourGmt)
{
   datetime gmtTime = TimeGMT();
   if(gmtTime <= 0)
      gmtTime = TimeCurrent(); // Fallback if TimeGMT is unavailable

   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);

   if(startHourGmt < endHourGmt)
   {
      // Standard intraday window (e.g. 07:00 to 20:00)
      return (dt.hour >= startHourGmt && dt.hour < endHourGmt);
   }
   else if(startHourGmt > endHourGmt)
   {
      // Overnight window spanning midnight (e.g. 20:00 to 07:00)
      return (dt.hour >= startHourGmt || dt.hour < endHourGmt);
   }
   
   return true; // If start == end, 24h
}

//+------------------------------------------------------------------+
//| Evaluate M15 Counter-Trend Pullback Reset                        |
//| Requires >= 2 consecutive counter-trend M15 candles              |
//+------------------------------------------------------------------+
inline bool CSessionFilter::EvaluateM15PullbackResetFromRates(const MqlRates &m15Rates[], int totalRates, ENUM_DAILY_BIAS bias)
{
   if(totalRates < 3 || bias == DAILY_BIAS_NONE)
      return false;
      
   m_consecutivePullbackBars = 0;
   
   for(int i = 1; i < totalRates && i < 15; i++)
   {
      if(bias == DAILY_BIAS_BULLISH)
      {
         // Counter-trend pullback for Bullish bias = Bearish candles (Close < Open)
         if(m15Rates[i].close < m15Rates[i].open)
         {
            m_consecutivePullbackBars++;
         }
         else
         {
            break; // Sequence broken
         }
      }
      else if(bias == DAILY_BIAS_BEARISH)
      {
         // Counter-trend pullback for Bearish bias = Bullish candles (Close > Open)
         if(m15Rates[i].close > m15Rates[i].open)
         {
            m_consecutivePullbackBars++;
         }
         else
         {
            break; // Sequence broken
         }
      }
   }
   
   if(m_consecutivePullbackBars >= m_requiredPullbackBars)
   {
      // Reset lock
      m_continuationLocked = false;
      return true;
   }
   
   return false;
}

#endif // LEGSTECH_INDICATORS_SESSIONFILTER_MQH
