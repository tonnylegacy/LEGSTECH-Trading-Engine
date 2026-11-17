//+------------------------------------------------------------------+
//|                                                 SymbolHelper.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_ENGINE_SYMBOLHELPER_MQH
#define LEGSTECH_ENGINE_SYMBOLHELPER_MQH

#include <Object.mqh>
#include <Trade\SymbolInfo.mqh>
#include "..\Core\Defs.mqh"

//+------------------------------------------------------------------+
//| Class CSymbolHelper                                              |
//| Institutional-grade multi-asset symbol normalizer                |
//+------------------------------------------------------------------+
class CSymbolHelper : public CObject
{
private:
   string               m_symbol;
   CSymbolInfo          m_sym_info;
   MqlTick              m_last_tick;
   
   // Normalized specifications
   int                  m_digits;
   double               m_point;
   double               m_tick_size;
   double               m_tick_value;
   double               m_pip_size;
   double               m_pip_points;
   
   // Volume parameters
   double               m_lot_min;
   double               m_lot_max;
   double               m_lot_step;
   int                  m_lot_step_digits;
   double               m_contract_size;
   
   // Levels & Classification
   int                  m_stops_level;
   int                  m_freeze_level;
   ENUM_ASSET_CLASS     m_asset_class;
   bool                 m_is_initialized;

   void                 DetectAssetClass();
   void                 CalculatePipScale();
   int                  CalculateLotStepDigits(double step);

public:
                        CSymbolHelper();
   virtual             ~CSymbolHelper();

   bool                 Init(const string symbol);
   bool                 Refresh();

   // Math & Normalization
   double               PipToPrice(double pips) const;
   double               PriceToPip(double priceDelta) const;
   double               NormalizePrice(double price) const;
   double               NormalizeLot(double lot) const;
   double               GetPipValue(double lotSize = 1.0) const;
   double               GetSpreadPips() const;
   double               GetSpreadPoints() const;
   bool                 CheckMinStopDistance(double entryPrice, double stopPrice) const;
   bool                 IsValidStopLoss(ENUM_POSITION_TYPE posType, double proposedSL, double currentSL = 0.0) const;

   // Offline Mock / Synthetic Configuration Support
   void                 SetManualProperties(const string symbol,
                                            int digits,
                                            double point,
                                            double tickSize,
                                            double tickValue,
                                            double lotMin,
                                            double lotMax,
                                            double lotStep,
                                            ENUM_ASSET_CLASS assetClass);
   void                 SetMockTick(double bid, double ask, datetime tickTime = 0);

   // Getters
   string               GetSymbol() const          { return m_symbol; }
   int                  GetDigits() const          { return m_digits; }
   double               GetPoint() const           { return m_point; }
   double               GetTickSize() const        { return m_tick_size; }
   double               GetTickValue() const       { return m_tick_value; }
   double               GetPipSize() const         { return m_pip_size; }
   double               GetPipPoints() const       { return m_pip_points; }
   double               GetLotMin() const          { return m_lot_min; }
   double               GetLotMax() const          { return m_lot_max; }
   double               GetLotStep() const         { return m_lot_step; }
   double               GetContractSize() const    { return m_contract_size; }
   int                  GetStopsLevel() const      { return m_stops_level; }
   int                  GetFreezeLevel() const     { return m_freeze_level; }
   ENUM_ASSET_CLASS     GetAssetClass() const      { return m_asset_class; }
   double               GetBid() const             { return m_last_tick.bid; }
   double               GetAsk() const             { return m_last_tick.ask; }
   datetime             GetTickTime() const        { return m_last_tick.time; }
   bool                 IsInitialized() const      { return m_is_initialized; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSymbolHelper::CSymbolHelper()
{
   m_symbol          = "";
   m_digits          = 5;
   m_point           = 0.00001;
   m_tick_size       = 0.00001;
   m_tick_value      = 1.0;
   m_pip_size        = 0.0001;
   m_pip_points      = 10.0;
   m_lot_min         = 0.01;
   m_lot_max         = 100.0;
   m_lot_step        = 0.01;
   m_lot_step_digits = 2;
   m_contract_size   = 100000.0;
   m_stops_level     = 0;
   m_freeze_level    = 0;
   m_asset_class     = ASSET_CLASS_FX_MAJORS;
   m_is_initialized  = false;
   ZeroMemory(m_last_tick);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSymbolHelper::~CSymbolHelper()
{
}

//+------------------------------------------------------------------+
//| Initialize with symbol name                                      |
//+------------------------------------------------------------------+
inline bool CSymbolHelper::Init(const string symbol)
{
   m_symbol = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   
   if(m_symbol != "")
   {
      m_sym_info.Name(m_symbol);
      m_sym_info.Refresh();
   }
   
   m_digits          = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   m_point           = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_tick_size       = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   m_tick_value      = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   m_lot_min         = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   m_lot_max         = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   m_lot_step        = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   m_contract_size   = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   m_stops_level     = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   m_freeze_level    = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   
   // Zero-division safeguards
   if(m_point <= 0.0)        m_point = (m_digits == 3) ? 0.001 : ((m_digits == 2) ? 0.01 : 0.00001);
   if(m_tick_size <= 0.0)    m_tick_size = m_point;
   if(m_tick_value <= 0.0)   m_tick_value = 1.0;
   if(m_lot_min <= 0.0)      m_lot_min = 0.01;
   if(m_lot_max <= 0.0)      m_lot_max = 100.0;
   if(m_lot_step <= 0.0)     m_lot_step = 0.01;
   if(m_contract_size <= 0.0)m_contract_size = 100000.0;

   m_lot_step_digits = CalculateLotStepDigits(m_lot_step);

   DetectAssetClass();
   CalculatePipScale();
   
   if(!SymbolInfoTick(m_symbol, m_last_tick))
   {
      m_last_tick.bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      m_last_tick.ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      m_last_tick.time = TimeCurrent();
   }
   
   m_is_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Refresh current ticks and dynamic properties                     |
//+------------------------------------------------------------------+
inline bool CSymbolHelper::Refresh()
{
   if(!m_is_initialized)
      return false;
      
   if(SymbolInfoTick(m_symbol, m_last_tick))
   {
      double tv = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tv > 0.0) m_tick_value = tv;
      return true;
   }
   
   m_last_tick.bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   m_last_tick.ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   m_last_tick.time = TimeCurrent();
   return (m_last_tick.ask > 0.0 || m_last_tick.bid > 0.0);
}

//+------------------------------------------------------------------+
//| Detect Asset Classification                                      |
//+------------------------------------------------------------------+
inline void CSymbolHelper::DetectAssetClass()
{
   string sym = m_symbol;
   StringToUpper(sym);
   
   if(StringFind(sym, "JPY") >= 0)
   {
      m_asset_class = ASSET_CLASS_FX_JPY;
   }
   else if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0 || StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
   {
      m_asset_class = ASSET_CLASS_METALS;
   }
   else if(StringFind(sym, "US30") >= 0 || StringFind(sym, "DJ") >= 0 || StringFind(sym, "WS30") >= 0 ||
           StringFind(sym, "SPX") >= 0  || StringFind(sym, "NAS") >= 0 || StringFind(sym, "NDX") >= 0 ||
           StringFind(sym, "GER") >= 0  || StringFind(sym, "DAX") >= 0 || StringFind(sym, "UK100") >= 0)
   {
      m_asset_class = ASSET_CLASS_INDICES;
   }
   else if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || StringFind(sym, "CRYPTO") >= 0)
   {
      m_asset_class = ASSET_CLASS_CRYPTO;
   }
   else
   {
      m_asset_class = ASSET_CLASS_FX_MAJORS;
   }
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Pip Scale                                      |
//+------------------------------------------------------------------+
inline void CSymbolHelper::CalculatePipScale()
{
   switch(m_asset_class)
   {
      case ASSET_CLASS_FX_JPY:
         if(m_digits == 3)      { m_pip_points = 10.0;  m_pip_size = 0.01; }
         else if(m_digits == 2) { m_pip_points = 1.0;   m_pip_size = 0.01; }
         else                   { m_pip_points = 10.0;  m_pip_size = 10.0 * m_point; }
         break;

      case ASSET_CLASS_METALS:
         if(m_digits == 2)      { m_pip_points = 10.0;  m_pip_size = 0.10; }
         else if(m_digits == 3) { m_pip_points = 100.0; m_pip_size = 0.10; }
         else                   { m_pip_points = 10.0;  m_pip_size = 10.0 * m_point; }
         break;

      case ASSET_CLASS_INDICES:
         if(m_digits == 0)      { m_pip_points = 1.0;   m_pip_size = 1.0; }
         else if(m_digits == 1) { m_pip_points = 10.0;  m_pip_size = 1.0; }
         else if(m_digits == 2) { m_pip_points = 100.0; m_pip_size = 1.0; }
         else                   { m_pip_points = 1.0;   m_pip_size = 1.0; }
         break;

      case ASSET_CLASS_FX_MAJORS:
      default:
         if(m_digits == 5)      { m_pip_points = 10.0;  m_pip_size = 0.00010; }
         else if(m_digits == 4) { m_pip_points = 1.0;   m_pip_size = 0.00010; }
         else                   { m_pip_points = 10.0;  m_pip_size = 10.0 * m_point; }
         break;
   }
   
   if(m_pip_size <= 0.0)   m_pip_size = 10.0 * m_point;
   if(m_pip_points <= 0.0) m_pip_points = 10.0;
}

//+------------------------------------------------------------------+
//| Calculate decimal places of lot step                             |
//+------------------------------------------------------------------+
inline int CSymbolHelper::CalculateLotStepDigits(double step)
{
   if(step <= 0.0) return 2;
   string s = DoubleToString(step, 8);
   int dotPos = StringFind(s, ".");
   if(dotPos < 0) return 0;
   
   int len = StringLen(s);
   int lastNonZero = len - 1;
   while(lastNonZero > dotPos && StringGetCharacter(s, lastNonZero) == '0')
      lastNonZero--;
      
   return (lastNonZero - dotPos);
}

//+------------------------------------------------------------------+
//| Convert Pips to Price distance                                   |
//+------------------------------------------------------------------+
inline double CSymbolHelper::PipToPrice(double pips) const
{
   return (pips * m_pip_size);
}

//+------------------------------------------------------------------+
//| Convert Price delta to Pips (preserves direction sign)           |
//+------------------------------------------------------------------+
inline double CSymbolHelper::PriceToPip(double priceDelta) const
{
   if(m_pip_size <= 0.0) return 0.0;
   return (priceDelta / m_pip_size);
}

//+------------------------------------------------------------------+
//| Normalize Price to valid broker tick grid                        |
//+------------------------------------------------------------------+
inline double CSymbolHelper::NormalizePrice(double price) const
{
   if(m_tick_size <= 0.0) return NormalizeDouble(price, m_digits);
   double ticks = MathRound(price / m_tick_size);
   return NormalizeDouble(ticks * m_tick_size, m_digits);
}

//+------------------------------------------------------------------+
//| Normalize Lot Size to valid step and min/max limits              |
//+------------------------------------------------------------------+
inline double CSymbolHelper::NormalizeLot(double lot) const
{
   if(m_lot_step <= 0.0) return m_lot_min;
   
   double steps = MathFloor((lot - m_lot_min) / m_lot_step + 1e-9);
   double normalized = m_lot_min + steps * m_lot_step;
   
   if(normalized < m_lot_min) normalized = m_lot_min;
   if(normalized > m_lot_max) normalized = m_lot_max;
   
   return NormalizeDouble(normalized, m_lot_step_digits);
}

//+------------------------------------------------------------------+
//| Monetary value of 1 pip for given volume                         |
//+------------------------------------------------------------------+
inline double CSymbolHelper::GetPipValue(double lotSize) const
{
   if(m_tick_size <= 0.0) return 10.0 * lotSize;
   return ((m_pip_size / m_tick_size) * m_tick_value * lotSize);
}

//+------------------------------------------------------------------+
//| Current Spread in Pips                                           |
//+------------------------------------------------------------------+
inline double CSymbolHelper::GetSpreadPips() const
{
   if(m_pip_size <= 0.0) return 0.0;
   double spreadPrice = m_last_tick.ask - m_last_tick.bid;
   return (spreadPrice / m_pip_size);
}

//+------------------------------------------------------------------+
//| Current Spread in Points                                         |
//+------------------------------------------------------------------+
inline double CSymbolHelper::GetSpreadPoints() const
{
   if(m_point <= 0.0) return 0.0;
   return ((m_last_tick.ask - m_last_tick.bid) / m_point);
}

//+------------------------------------------------------------------+
//| Check if Stop Distance respects SYMBOL_TRADE_STOPS_LEVEL         |
//+------------------------------------------------------------------+
inline bool CSymbolHelper::CheckMinStopDistance(double entryPrice, double stopPrice) const
{
   if(m_point <= 0.0) return true;
   double distancePoints = MathAbs(entryPrice - stopPrice) / m_point;
   return (distancePoints >= m_stops_level);
}

//+------------------------------------------------------------------+
//| Validate proposed Stop Loss against live market price and broker |
//| StopsLevel / FreezeLevel constraints                             |
//+------------------------------------------------------------------+
inline bool CSymbolHelper::IsValidStopLoss(ENUM_POSITION_TYPE posType, double proposedSL, double currentSL = 0.0) const
{
   if(proposedSL <= 0.0) return false;
   
   double minDistance = MathMax((double)m_stops_level, (double)m_freeze_level) * m_point;
   if(minDistance <= 0.0) minDistance = m_point;

   if(posType == POSITION_TYPE_BUY)
   {
      // Stop Loss must be strictly below current Bid by at least minDistance
      if(proposedSL > (m_last_tick.bid - minDistance))
         return false;
      // If current SL is already set, proposed SL must ratchet forward (higher)
      if(currentSL > 0.0 && proposedSL <= currentSL)
         return false;
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      // Stop Loss must be strictly above current Ask by at least minDistance
      if(proposedSL < (m_last_tick.ask + minDistance))
         return false;
      // If current SL is already set, proposed SL must ratchet forward (lower)
      if(currentSL > 0.0 && proposedSL >= currentSL)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Manual Properties Setter for Offline / Synthetic Mocking         |
//+------------------------------------------------------------------+
inline void CSymbolHelper::SetManualProperties(const string symbol,
                                              int digits,
                                              double point,
                                              double tickSize,
                                              double tickValue,
                                              double lotMin,
                                              double lotMax,
                                              double lotStep,
                                              ENUM_ASSET_CLASS assetClass)
{
   m_symbol          = symbol;
   m_digits          = digits;
   m_point           = (point > 0.0) ? point : 0.00001;
   m_tick_size       = (tickSize > 0.0) ? tickSize : m_point;
   m_tick_value      = (tickValue > 0.0) ? tickValue : 1.0;
   m_lot_min         = (lotMin > 0.0) ? lotMin : 0.01;
   m_lot_max         = (lotMax > 0.0) ? lotMax : 100.0;
   m_lot_step        = (lotStep > 0.0) ? lotStep : 0.01;
   m_asset_class     = assetClass;
   m_lot_step_digits = CalculateLotStepDigits(m_lot_step);
   
   CalculatePipScale();
   m_is_initialized = true;
}

//+------------------------------------------------------------------+
//| Set Mock Tick for Offline Testing                                |
//+------------------------------------------------------------------+
inline void CSymbolHelper::SetMockTick(double bid, double ask, datetime tickTime)
{
   m_last_tick.bid  = bid;
   m_last_tick.ask  = ask;
   m_last_tick.time = (tickTime > 0) ? tickTime : TimeCurrent();
}

#endif // LEGSTECH_ENGINE_SYMBOLHELPER_MQH
