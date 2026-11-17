//+------------------------------------------------------------------+
//|                                                   RiskEngine.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_ENGINE_RISKENGINE_MQH
#define LEGSTECH_ENGINE_RISKENGINE_MQH

#include <Object.mqh>
#include <Trade\AccountInfo.mqh>
#include "..\Core\Defs.mqh"
#include "SymbolHelper.mqh"

//+------------------------------------------------------------------+
//| Class CRiskEngine                                                |
//| Institutional-grade risk sizing and safety circuit breaker       |
//+------------------------------------------------------------------+
class CRiskEngine : public CObject
{
private:
   string               m_symbol;
   CSymbolHelper       *m_sym_helper;
   bool                 m_owns_sym_helper;
   CAccountInfo         m_account_info;
   
   // Risk Settings
   ENUM_RISK_MODE       m_risk_mode;
   double               m_risk_value;          // Fixed lots or % equity (e.g. 1.0 = 1%)
   double               m_max_daily_dd;        // Max daily DD percent (e.g. 5.0 = 5%)
   double               m_max_spread_pips;     // Max allowable spread in pips
   int                  m_max_positions;       // Max concurrent open positions
   ulong                m_magic;               // Magic number for tracking PnL
   
   // Daily Drawdown Tracking
   datetime             m_last_day_start;
   double               m_day_start_equity;
   double               m_day_start_balance;
   bool                 m_is_dd_halted;
   bool                 m_is_hard_loss_halted;
   double               m_current_daily_dd_pct;
   
   // Circuit Breaker & Safety
   bool                 m_kill_switch_active;
   bool                 m_is_initialized;

   // Offline Mocking overrides
   bool                 m_use_mock_account;
   double               m_mock_equity;
   double               m_mock_balance;
   double               m_mock_free_margin;
   bool                 m_mock_trade_allowed;

   // Twin-Position Configuration
   bool                 m_enable_twin_positions;
   ENUM_TWIN_LOT_MODE   m_twin_lot_mode;
   double               m_twin_pos1_ratio;

   void                 CheckAndResetNewDay();
   double               CalculateRealizedDailyPnL();

public:
                        CRiskEngine();
   virtual             ~CRiskEngine();

   bool                 Init(const string symbol,
                             double riskValue,
                             ENUM_RISK_MODE mode,
                             double maxDD,
                             double maxSpread,
                             int maxPositions,
                             CSymbolHelper *symHelper = NULL,
                             ulong magic = 0);

   void                 SetTwinPositionConfig(bool enableTwin, ENUM_TWIN_LOT_MODE lotMode, double pos1Ratio = 0.5)
   {
      m_enable_twin_positions = enableTwin;
      m_twin_lot_mode         = lotMode;
      m_twin_pos1_ratio       = (pos1Ratio > 0.0 && pos1Ratio < 1.0) ? pos1Ratio : 0.5;
   }
   bool                 IsTwinPositionsEnabled() const { return m_enable_twin_positions; }
   ENUM_TWIN_LOT_MODE   GetTwinLotMode() const         { return m_twin_lot_mode; }

   bool                 IsTradingAllowed(string &outReason);
   bool                 CalculateLotSize(double entryPrice,
                                         double stopLossPrice,
                                         double &outLot1,
                                         double &outLot2,
                                         bool isTwoPositions,
                                         double customRiskPercent = -1.0);
                                         
   bool                 CheckSpread(double &currentSpread);
   bool                 UpdateDailyDrawdown(double currentEquity, double realizedTodayPnL);
   bool                 CheckMaxPositions(int currentOpenCount);
   int                  CountSymbolPositions();
   bool                 AcquireExecutionLock(int lockDurationSeconds = 3);
   void                 ReleaseExecutionLock();
   bool                 CheckMargin(ENUM_ORDER_TYPE orderType, double totalLot, string &outReason);
   
   // Kill switch control
   void                 SetKillSwitch(bool active) { m_kill_switch_active = active; }
   bool                 GetKillSwitch() const      { return m_kill_switch_active; }
   
   // Mocking Interface for Offline Testing
   void                 SetMockAccount(double equity, double balance, double freeMargin, bool tradeAllowed = true);
   void                 ClearMockAccount()         { m_use_mock_account = false; }
   void                 SetDayStartEquity(double equity) { m_day_start_equity = equity; }

   // Status Getters & Dynamic Configuration
   void                 SetRiskParameters(ENUM_RISK_MODE mode, double riskValue) { m_risk_mode = mode; m_risk_value = (riskValue > 0.0) ? riskValue : 1.0; }
   bool                 IsDDHalted() const         { return m_is_dd_halted; }
   bool                 IsHardLossHalted() const   { return m_is_hard_loss_halted; }
   void                 ResetDailyDrawdownHalt()   { m_is_dd_halted = false; m_is_hard_loss_halted = false; m_current_daily_dd_pct = 0.0; }
   double               GetCurrentDailyDD() const  { return m_current_daily_dd_pct; }
   double               GetDayStartEquity() const  { return m_day_start_equity; }
   ENUM_RISK_MODE       GetRiskMode() const        { return m_risk_mode; }
   double               GetRiskValue() const       { return m_risk_value; }
   double               GetMaxDailyDD() const      { return m_max_daily_dd; }
   double               GetMaxSpreadPips() const   { return m_max_spread_pips; }
   int                  GetMaxPositions() const    { return m_max_positions; }
   bool                 IsInitialized() const      { return m_is_initialized; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskEngine::CRiskEngine()
{
   m_symbol               = "";
   m_sym_helper           = NULL;
   m_owns_sym_helper      = false;
   m_risk_mode            = RISK_MODE_PERCENT_EQUITY;
   m_risk_value           = 1.0;
   m_max_daily_dd         = 5.0;
   m_max_spread_pips      = 3.0;
   m_max_positions        = 2;
   m_last_day_start       = 0;
   m_day_start_equity     = 0.0;
   m_day_start_balance    = 0.0;
   m_is_dd_halted         = false;
   m_is_hard_loss_halted  = false;
   m_current_daily_dd_pct = 0.0;
   m_kill_switch_active   = false;
   m_is_initialized       = false;
   m_use_mock_account     = false;
   m_mock_equity          = 10000.0;
   m_mock_balance         = 10000.0;
   m_mock_free_margin     = 10000.0;
   m_mock_trade_allowed   = true;
   m_enable_twin_positions = false;
   m_twin_lot_mode         = TWIN_LOT_FULL_EACH;
   m_twin_pos1_ratio       = 0.50;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskEngine::~CRiskEngine()
{
   if(m_owns_sym_helper && CheckPointer(m_sym_helper) == POINTER_DYNAMIC)
   {
      delete m_sym_helper;
      m_sym_helper = NULL;
   }
}

//+------------------------------------------------------------------+
//| Initialize Risk Engine                                           |
//+------------------------------------------------------------------+
inline bool CRiskEngine::Init(const string symbol,
                             double riskValue,
                             ENUM_RISK_MODE mode,
                             double maxDD,
                             double maxSpread,
                             int maxPositions,
                             CSymbolHelper *symHelper,
                             ulong magic)
{
   m_symbol          = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   
   if(symHelper != NULL)
   {
      m_sym_helper      = symHelper;
      m_owns_sym_helper = false;
   }
   else if(m_sym_helper == NULL)
   {
      m_sym_helper      = new CSymbolHelper();
      m_sym_helper.Init(m_symbol);
      m_owns_sym_helper = true;
   }
   
   m_risk_value      = (riskValue > 0.0) ? riskValue : 1.0;
   m_risk_mode       = mode;
   m_max_daily_dd    = (maxDD > 0.0) ? maxDD : 5.0;
   m_max_spread_pips = (maxSpread > 0.0) ? maxSpread : 3.0;
   m_max_positions   = (maxPositions > 0) ? maxPositions : 2;
   m_magic           = magic;
   
   m_day_start_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   m_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(m_day_start_equity <= 0.0) m_day_start_equity = 10000.0;
   if(m_day_start_balance <= 0.0) m_day_start_balance = 10000.0;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   m_last_day_start = StructToTime(dt);
   
   m_is_dd_halted         = false;
   m_is_hard_loss_halted  = false;
   m_current_daily_dd_pct = 0.0;
   m_kill_switch_active   = false;
   m_is_initialized       = true;
   
   return true;
}

//+------------------------------------------------------------------+
//| Mock account state for offline deterministic testing             |
//+------------------------------------------------------------------+
inline void CRiskEngine::SetMockAccount(double equity, double balance, double freeMargin, bool tradeAllowed)
{
   m_use_mock_account   = true;
   m_mock_equity        = equity;
   m_mock_balance       = balance;
   m_mock_free_margin   = freeMargin;
   m_mock_trade_allowed = tradeAllowed;
   if(m_day_start_equity <= 0.0) m_day_start_equity = equity;
   if(m_day_start_balance <= 0.0) m_day_start_balance = balance;
}

//+------------------------------------------------------------------+
//| Daily Reset Check                                                |
//+------------------------------------------------------------------+
inline void CRiskEngine::CheckAndResetNewDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStart = StructToTime(dt);
   
   if(todayStart > m_last_day_start)
   {
      m_last_day_start    = todayStart;
      m_day_start_equity  = m_use_mock_account ? m_mock_equity : AccountInfoDouble(ACCOUNT_EQUITY);
      m_day_start_balance = m_use_mock_account ? m_mock_balance : AccountInfoDouble(ACCOUNT_BALANCE);
      m_is_dd_halted      = false;
      m_is_hard_loss_halted = false;
      m_current_daily_dd_pct = 0.0;
   }
}

//+------------------------------------------------------------------+
//| Verify all master safety rules                                   |
//+------------------------------------------------------------------+
inline bool CRiskEngine::IsTradingAllowed(string &outReason)
{
   if(!m_is_initialized)
   {
      outReason = "CRiskEngine is not initialized";
      return false;
   }
   
   if(m_kill_switch_active)
   {
      outReason = "Emergency Kill Switch is ACTIVE";
      return false;
   }
   
   if(!m_use_mock_account)
   {
      if(!MQLInfoInteger(MQL_TESTER))
      {
         if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
         {
            outReason = "Automated trading is disabled in MetaTrader 5 Terminal";
            return false;
         }
         
         if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
         {
            outReason = "Automated trading is disabled for this Expert Advisor";
            return false;
         }
         
         if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
         {
            outReason = "Trading is not allowed for this Account";
            return false;
         }
      }
      
      ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
      if(tradeMode != SYMBOL_TRADE_MODE_FULL && tradeMode != 0) // tradeMode 0 in some testers
      {
         // Allow in testing mode if tester
         if(!MQLInfoInteger(MQL_TESTER))
         {
            outReason = "Symbol trade mode is not SYMBOL_TRADE_MODE_FULL";
            return false;
         }
      }
   }
   else
   {
      if(!m_mock_trade_allowed)
      {
         outReason = "Trading is disabled in mock environment";
         return false;
      }
   }
   
   CheckAndResetNewDay();
   
   double currentEquity = m_use_mock_account ? m_mock_equity : AccountInfoDouble(ACCOUNT_EQUITY);
   UpdateDailyDrawdown(currentEquity, CalculateRealizedDailyPnL());
   
   if(m_is_dd_halted)
   {
      outReason = StringFormat("Daily Drawdown Limit Hit (%.2f%% >= %.2f%%)", m_current_daily_dd_pct, m_max_daily_dd);
      return false;
   }
   
   double spreadPips = 0.0;
   if(!CheckSpread(spreadPips))
   {
      outReason = StringFormat("Spread exceeded limit: %.1f pips > %.1f pips", spreadPips, m_max_spread_pips);
      return false;
   }

   // Master Position Cap Guard: Verify live open positions across the symbol
   int openCount = CountSymbolPositions();
   if(!CheckMaxPositions(openCount))
   {
      outReason = StringFormat("Max concurrent positions reached (%d open >= limit of %d)", openCount, m_max_positions);
      return false;
   }
   
   outReason = "Trading Allowed";
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size for Single or Dual Positions                  |
//+------------------------------------------------------------------+
inline bool CRiskEngine::CalculateLotSize(double entryPrice,
                                         double stopLossPrice,
                                         double &outLot1,
                                         double &outLot2,
                                         bool isTwoPositions,
                                         double customRiskPercent)
{
   outLot1 = 0.0;
   outLot2 = 0.0;
   
   if(m_sym_helper == NULL || !m_sym_helper.IsInitialized())
      return false;
      
   double totalLot = 0.0;
   
   if(m_risk_mode == RISK_MODE_FIXED_LOT)
   {
      // In Fixed Lot Mode, strictly enforce the configured fixed lot size (e.g. 0.01).
      // Under no circumstances should a strategy's percentage calculation override fixed lots.
      totalLot = m_risk_value;
   }
   else // RISK_MODE_PERCENT_EQUITY or RISK_MODE_PERCENT_BALANCE
   {
      double baseCapital = m_use_mock_account ?
                           ((m_risk_mode == RISK_MODE_PERCENT_EQUITY) ? m_mock_equity : m_mock_balance) :
                           ((m_risk_mode == RISK_MODE_PERCENT_EQUITY) ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE));
                           
      if(baseCapital <= 0.0) baseCapital = 10000.0;
      
      double effectiveRisk = (customRiskPercent > 0.0) ? customRiskPercent : m_risk_value;
      double cashRisk = baseCapital * (effectiveRisk / 100.0);
      double slPriceDistance = MathAbs(entryPrice - stopLossPrice);
      double slPips = m_sym_helper.PriceToPip(slPriceDistance);
      
      if(slPips <= 0.001)
         slPips = 10.0; // Fallback minimum 10 pips to avoid zero division
         
      double pipValuePerLot = m_sym_helper.GetPipValue(1.0);
      if(pipValuePerLot <= 0.00001)
         pipValuePerLot = 10.0;
         
      totalLot = cashRisk / (slPips * pipValuePerLot);
   }
   
   // Volume bounds check
   double lotMin  = m_sym_helper.GetLotMin();
   double lotMax  = m_sym_helper.GetLotMax();
   
   if(totalLot < lotMin)
      totalLot = lotMin;
   if(totalLot > lotMax)
      totalLot = lotMax;
      
   if(isTwoPositions || m_enable_twin_positions)
   {
      if(m_twin_lot_mode == TWIN_LOT_FULL_EACH)
      {
         // Full lot size on BOTH positions (e.g. 0.01 lot on Pos 1 AND 0.01 lot on Pos 2)
         if(m_risk_mode == RISK_MODE_FIXED_LOT)
         {
            outLot1 = m_sym_helper.NormalizeLot(totalLot);
            outLot2 = m_sym_helper.NormalizeLot(totalLot);
         }
         else
         {
            // In percentage risk mode, assigning totalLot to both doubles total portfolio risk!
            // Divide by 2 so total risk equals the user's configured risk percentage.
            double halfLot = totalLot / 2.0;
            if(halfLot < lotMin) halfLot = lotMin;
            outLot1 = m_sym_helper.NormalizeLot(halfLot);
            outLot2 = m_sym_helper.NormalizeLot(halfLot);
         }
      }
      else if(m_twin_lot_mode == TWIN_LOT_CUSTOM)
      {
         double p1Lot = totalLot * m_twin_pos1_ratio;
         double p2Lot = totalLot - p1Lot;
         if(p1Lot < lotMin || p2Lot < lotMin)
         {
            outLot1 = m_sym_helper.NormalizeLot(MathMax(p1Lot, lotMin));
            outLot2 = m_sym_helper.NormalizeLot(MathMax(p2Lot, lotMin));
         }
         else
         {
            outLot1 = m_sym_helper.NormalizeLot(p1Lot);
            outLot2 = m_sym_helper.NormalizeLot(p2Lot);
         }
      }
      else // TWIN_LOT_SPLIT_50_50
      {
         double halfLot = totalLot / 2.0;
         if(halfLot < lotMin || totalLot < 2.0 * lotMin)
         {
            // If total lot cannot be divided (e.g. 0.01 lot on micro account), assign lotMin to BOTH positions
            outLot1 = m_sym_helper.NormalizeLot(lotMin);
            outLot2 = m_sym_helper.NormalizeLot(lotMin);
         }
         else
         {
            outLot1 = m_sym_helper.NormalizeLot(halfLot);
            outLot2 = m_sym_helper.NormalizeLot(totalLot - outLot1);
         }
      }
   }
   else
   {
      outLot1 = m_sym_helper.NormalizeLot(totalLot);
      outLot2 = 0.0;
   }
   
   return (outLot1 >= lotMin);
}

//+------------------------------------------------------------------+
//| Verify Spread against Max Threshold                              |
//+------------------------------------------------------------------+
inline bool CRiskEngine::CheckSpread(double &currentSpread)
{
   if(m_sym_helper == NULL) return false;
   m_sym_helper.Refresh();
   currentSpread = m_sym_helper.GetSpreadPips();
   return (currentSpread <= m_max_spread_pips);
}

//+------------------------------------------------------------------+
//| Update and Check Daily Drawdown Halt                             |
//+------------------------------------------------------------------+
inline bool CRiskEngine::UpdateDailyDrawdown(double currentEquity, double realizedTodayPnL)
{
   CheckAndResetNewDay();
   
   if(m_day_start_equity <= 0.0)
      m_day_start_equity = currentEquity;
   if(m_day_start_balance <= 0.0)
      m_day_start_balance = m_use_mock_account ? m_mock_balance : AccountInfoDouble(ACCOUNT_BALANCE);
      
   if(m_day_start_equity <= 0.0)
      return true; // No basis to calculate
      
   // 1. Check Hard Realized Loss Circuit Breaker
   // If cumulative closed losses today breach m_max_daily_dd, lock trading until midnight
   if(m_day_start_balance > 0.0 && realizedTodayPnL < 0.0)
   {
      double realizedLossPct = (-realizedTodayPnL / m_day_start_balance) * 100.0;
      if(realizedLossPct >= m_max_daily_dd)
      {
         m_is_hard_loss_halted  = true;
         m_is_dd_halted         = true;
         m_current_daily_dd_pct = realizedLossPct;
         return false; // Hard daily loss limit tripped
      }
   }
   
   // If hard loss limit was previously engaged today, do not auto-recover until midnight
   if(m_is_hard_loss_halted)
   {
      m_is_dd_halted = true;
      return false;
   }
      
   // 2. Check Floating Intraday Drawdown
   double ddAmount = m_day_start_equity - currentEquity;
   if(ddAmount > 0.0)
   {
      m_current_daily_dd_pct = (ddAmount / m_day_start_equity) * 100.0;
   }
   else
   {
      m_current_daily_dd_pct = 0.0;
   }
   
   // If floating drawdown breaches threshold, halt new entries while open positions are managed
   if(m_current_daily_dd_pct >= m_max_daily_dd)
   {
      m_is_dd_halted = true;
      return false; // Circuit breaker tripped by floating drawdown dip
   }
   
   // 3. Smart Auto-Recovery
   // If halted by a temporary floating dip, but positions have closed or equity has recovered:
   if(m_is_dd_halted && !m_is_hard_loss_halted)
   {
      int openPos = CountSymbolPositions();
      if((openPos == 0 && m_current_daily_dd_pct < (m_max_daily_dd * 0.80)) ||
         (m_current_daily_dd_pct < (m_max_daily_dd * 0.50)) ||
         (currentEquity >= m_day_start_equity))
      {
         m_is_dd_halted = false; // Auto-recovery engaged!
      }
   }
   
   return !m_is_dd_halted;
}

//+------------------------------------------------------------------+
//| Count active positions open across this symbol on account        |
//+------------------------------------------------------------------+
inline int CRiskEngine::CountSymbolPositions()
{
   if(m_use_mock_account) return 0;

   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == m_symbol)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Acquire cross-chart execution mutex lock (prevents multi-chart race)
//+------------------------------------------------------------------+
inline bool CRiskEngine::AcquireExecutionLock(int lockDurationSeconds)
{
   if(m_use_mock_account || MQLInfoInteger(MQL_TESTER)) return true;

   string varName = "LEGsTech_Lock_" + m_symbol;
   datetime now = TimeCurrent();
   if(GlobalVariableCheck(varName))
   {
      datetime lockTime = (datetime)GlobalVariableGet(varName);
      if(now >= lockTime && (now - lockTime) < lockDurationSeconds)
      {
         return false; // Another chart or EA instance is currently executing orders
      }
   }
   GlobalVariableSet(varName, (double)now);
   return true;
}

//+------------------------------------------------------------------+
//| Release cross-chart execution mutex lock                         |
//+------------------------------------------------------------------+
inline void CRiskEngine::ReleaseExecutionLock()
{
   if(m_use_mock_account || MQLInfoInteger(MQL_TESTER)) return;

   string varName = "LEGsTech_Lock_" + m_symbol;
   if(GlobalVariableCheck(varName))
   {
      GlobalVariableDel(varName);
   }
}

//+------------------------------------------------------------------+
//| Check Maximum Open Positions Count                               |
//+------------------------------------------------------------------+
inline bool CRiskEngine::CheckMaxPositions(int currentOpenCount)
{
   int effectiveLimit = m_enable_twin_positions ? (m_max_positions * 2) : m_max_positions;
   return (currentOpenCount < effectiveLimit);
}

//+------------------------------------------------------------------+
//| Margin Pre-Check before trade execution                          |
//+------------------------------------------------------------------+
inline bool CRiskEngine::CheckMargin(ENUM_ORDER_TYPE orderType, double totalLot, string &outReason)
{
   if(totalLot <= 0.0)
   {
      outReason = "Invalid lot size for margin check";
      return false;
   }
   
   if(m_use_mock_account)
   {
      if(m_mock_free_margin <= 0.0)
      {
         outReason = "Insufficient mock free margin";
         return false;
      }
      outReason = "Mock margin check passed";
      return true;
   }
   
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double requiredMargin = 0.0;
   double price = (orderType == ORDER_TYPE_BUY) ? m_sym_helper.GetAsk() : m_sym_helper.GetBid();
   if(price <= 0.0) price = 1.0;
   
   if(!OrderCalcMargin(orderType, m_symbol, totalLot, price, requiredMargin))
   {
      // In Strategy Tester or offline mock, OrderCalcMargin may return false if no ticks
      if(MQLInfoInteger(MQL_TESTER))
      {
         outReason = "Margin check passed (Tester mode)";
         return true;
      }
      outReason = "Failed to calculate required margin";
      return false;
   }
   
   // Require 10% safety cushion
   if(freeMargin < (requiredMargin * 1.10) && freeMargin > 0.0)
   {
      outReason = StringFormat("Insufficient free margin: Free=%.2f, Required=%.2f", freeMargin, requiredMargin);
      return false;
   }
   
   outReason = "Margin check passed";
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Realized Daily PnL                                     |
//+------------------------------------------------------------------+
inline double CRiskEngine::CalculateRealizedDailyPnL()
{
   double pnl = 0.0;
   MqlDateTime dtNow;
   TimeCurrent(dtNow);
   dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
   datetime todayStart = StructToTime(dtNow);
   
   if(!HistorySelect(todayStart, TimeCurrent()))
      return 0.0;
   
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(m_magic == 0 || dealMagic == (long)m_magic)
         {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
            {
               pnl += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            pnl += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            pnl += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            }
         }
      }
   }
   return pnl;
}

#endif // LEGSTECH_ENGINE_RISKENGINE_MQH
