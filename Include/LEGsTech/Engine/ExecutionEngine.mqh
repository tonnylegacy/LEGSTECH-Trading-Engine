//+------------------------------------------------------------------+
//|                                              ExecutionEngine.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_ENGINE_EXECUTIONENGINE_MQH
#define LEGSTECH_ENGINE_EXECUTIONENGINE_MQH

#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "..\Core\Defs.mqh"
#include "SymbolHelper.mqh"

//+------------------------------------------------------------------+
//| Class CExecutionEngine                                           |
//| Institutional-grade trade execution, dual-slicing & retries      |
//+------------------------------------------------------------------+
class CExecutionEngine : public CObject
{
private:
   string               m_symbol;
   ulong                m_magic_number;
   int                  m_slippage_points;
   int                  m_max_retries;
   
   CTrade               m_trade;
   CPositionInfo        m_pos_info;
   CSymbolHelper       *m_sym_helper;
   bool                 m_owns_sym_helper;
   bool                 m_is_initialized;

   // Offline Mocking mode for Test Runner
   bool                 m_mock_execution;
   ulong                m_next_mock_ticket;

   ENUM_ORDER_TYPE_FILLING AutoDetectFillingType();
   bool                 IsRetriableError(uint retcode);
   void                 ApplyBackoff(int attempt);

public:
                        CExecutionEngine();
   virtual             ~CExecutionEngine();

   bool                 Init(const string symbol,
                             ulong magicNumber,
                             int slippagePoints,
                             CSymbolHelper *symHelper = NULL,
                             int maxRetries = 3);

   bool                 ExecuteMarketOrder(ENUM_ORDER_TYPE orderType,
                                           double volume,
                                           double sl,
                                           double tp,
                                           string comment,
                                           ulong &outTicket);

   bool                 ExecuteDualPositionOrder(ENUM_ORDER_TYPE orderType,
                                                 double vol1,
                                                 double vol2,
                                                 double sl,
                                                 double tp1,
                                                 double tp2,
                                                 string comment,
                                                 ulong &ticket1,
                                                 ulong &ticket2);

   bool                 ModifyPositionSL(ulong ticket, double newSL);
   bool                 ModifyPositionSLTP(ulong ticket, double newSL, double newTP);
   bool                 ClosePosition(ulong ticket, double volume = 0.0);
   bool                 CloseAllStrategyPositions(ulong magicNumber);
   
   // Mock Execution Controls for Testing
   void                 SetMockExecutionMode(bool mockEnabled, ulong startMockTicket = 1000001)
   {
      m_mock_execution   = mockEnabled;
      m_next_mock_ticket = startMockTicket;
   }
   bool                 IsMockExecution() const { return m_mock_execution; }

   CTrade*              GetTradeObject() { return &m_trade; }
   ulong                GetMagicNumber() const { return m_magic_number; }
   void                 SetMagicNumber(ulong magic)
   {
      m_magic_number = magic;
      m_trade.SetExpertMagicNumber(magic);
   }
   bool                 IsInitialized() const { return m_is_initialized; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExecutionEngine::CExecutionEngine()
{
   m_symbol           = "";
   m_magic_number     = 0;
   m_slippage_points  = 30;
   m_max_retries      = 3;
   m_sym_helper       = NULL;
   m_owns_sym_helper  = false;
   m_is_initialized   = false;
   m_mock_execution   = false;
   m_next_mock_ticket = 1000001;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CExecutionEngine::~CExecutionEngine()
{
   if(m_owns_sym_helper && CheckPointer(m_sym_helper) == POINTER_DYNAMIC)
   {
      delete m_sym_helper;
      m_sym_helper = NULL;
   }
}

//+------------------------------------------------------------------+
//| Auto-detect supported filling type                               |
//+------------------------------------------------------------------+
inline ENUM_ORDER_TYPE_FILLING CExecutionEngine::AutoDetectFillingType()
{
   uint filling = (uint)SymbolInfoInteger(m_symbol, SYMBOL_FILLING_MODE);
   
   if((filling & SYMBOL_FILLING_FOK) != 0)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) != 0)
      return ORDER_FILLING_IOC;
      
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Determine if an MT5 trade error is retriable                     |
//+------------------------------------------------------------------+
inline bool CExecutionEngine::IsRetriableError(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:        // 10004
      case TRADE_RETCODE_PRICE_CHANGED:  // 10020
      case TRADE_RETCODE_PRICE_OFF:      // 10021
      case TRADE_RETCODE_TIMEOUT:        // 10022
      case TRADE_RETCODE_CONNECTION:     // 10031
      case 10027:                        // TRADE_RETCODE_BUSY
         return true;
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Exponential backoff delay                                        |
//+------------------------------------------------------------------+
inline void CExecutionEngine::ApplyBackoff(int attempt)
{
   int delayMs = 100 * (int)MathPow(2.0, (double)attempt);
   if(delayMs > 1000) delayMs = 1000;
   Sleep(delayMs);
}

//+------------------------------------------------------------------+
//| Initialize Execution Engine                                      |
//+------------------------------------------------------------------+
inline bool CExecutionEngine::Init(const string symbol,
                                  ulong magicNumber,
                                  int slippagePoints,
                                  CSymbolHelper *symHelper,
                                  int maxRetries)
{
   m_symbol          = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_magic_number    = magicNumber;
   m_slippage_points = (slippagePoints > 0) ? slippagePoints : 30;
   m_max_retries     = (maxRetries > 0) ? maxRetries : 3;

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

   m_trade.SetExpertMagicNumber(m_magic_number);
   m_trade.SetDeviationInPoints(m_slippage_points);
   m_trade.SetTypeFilling(AutoDetectFillingType());
   m_trade.SetAsyncMode(false);

   m_is_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Execute Single Market Order with Retry Loop                      |
//+------------------------------------------------------------------+
inline bool CExecutionEngine::ExecuteMarketOrder(ENUM_ORDER_TYPE orderType,
                                                double volume,
                                                double sl,
                                                double tp,
                                                string comment,
                                                ulong &outTicket)
{
   outTicket = 0;
   if(!m_is_initialized || m_sym_helper == NULL) return false;
   
   double normVolume = m_sym_helper.NormalizeLot(volume);
   double normSL     = (sl > 0.0) ? m_sym_helper.NormalizePrice(sl) : 0.0;
   double normTP     = (tp > 0.0) ? m_sym_helper.NormalizePrice(tp) : 0.0;
   
   if(m_mock_execution)
   {
      outTicket = m_next_mock_ticket++;
      return true;
   }
   
   for(int attempt = 0; attempt < m_max_retries; attempt++)
   {
      m_sym_helper.Refresh();
      bool success = false;
      
      if(orderType == ORDER_TYPE_BUY)
      {
         double price = m_sym_helper.GetAsk();
         success = m_trade.Buy(normVolume, m_symbol, price, normSL, normTP, comment);
      }
      else if(orderType == ORDER_TYPE_SELL)
      {
         double price = m_sym_helper.GetBid();
         success = m_trade.Sell(normVolume, m_symbol, price, normSL, normTP, comment);
      }
      else
      {
         return false; // Unsupported order type
      }
      
      uint retcode = m_trade.ResultRetcode();
      
      if(success && (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED))
      {
         ulong deal = m_trade.ResultDeal();
         ulong ord  = m_trade.ResultOrder();
         outTicket = 0;
         if(deal > 0 && HistoryDealSelect(deal))
         {
            outTicket = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
         }
         if(outTicket == 0) outTicket = ord;
         if(outTicket == 0) outTicket = deal;
         return true;
      }
      
      if(!IsRetriableError(retcode))
      {
         PrintFormat("[CExecutionEngine ERROR] Non-retriable error %u: %s", retcode, m_trade.ResultRetcodeDescription());
         return false;
      }
      
      ApplyBackoff(attempt);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Execute Dual Position Sliced Order                               |
//+------------------------------------------------------------------+
inline bool CExecutionEngine::ExecuteDualPositionOrder(ENUM_ORDER_TYPE orderType,
                                                      double vol1,
                                                      double vol2,
                                                      double sl,
                                                      double tp1,
                                                      double tp2,
                                                      string comment,
                                                      ulong &ticket1,
                                                      ulong &ticket2)
{
   ticket1 = 0;
   ticket2 = 0;
   
   string comment1 = comment + "_P1";
   string comment2 = comment + "_P2";
   
   // 1. Execute Position 1 (TP1 target)
   bool res1 = ExecuteMarketOrder(orderType, vol1, sl, tp1, comment1, ticket1);
   if(!res1 || ticket1 == 0)
   {
      PrintFormat("[CExecutionEngine ERROR] Dual Position 1 failed to execute.");
      return false;
   }
   
   // 2. If vol2 is 0 or negligible, single position is completed
   if(vol2 <= 0.0 || (m_sym_helper != NULL && m_sym_helper.NormalizeLot(vol2) < m_sym_helper.GetLotMin()))
   {
      return true;
   }
   
   // 3. Execute Position 2 (Runner)
   bool res2 = ExecuteMarketOrder(orderType, vol2, sl, tp2, comment2, ticket2);
   if(!res2 || ticket2 == 0)
   {
      PrintFormat("[CExecutionEngine WARN] Dual Position 2 failed. Pos 1 #%I64u remains active.", ticket1);
      // Return true because Pos 1 succeeded and is safely live in market
      return true;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Modify Position Stop Loss with Retries                           |
//+------------------------------------------------------------------+
inline bool CExecutionEngine::ModifyPositionSL(ulong ticket, double newSL)
{
   if(!m_is_initialized || m_sym_helper == NULL || ticket == 0) return false;
   
   if(m_mock_execution)
      return true;
      
   if(!m_pos_info.SelectByTicket(ticket))
      return false;
      
   double currentTP = m_pos_info.TakeProfit();
   return ModifyPositionSLTP(ticket, newSL, currentTP);
}

//+------------------------------------------------------------------+
//| Modify Position SL and TP with Retries                           |
//+------------------------------------------------------------------+
inline bool CExecutionEngine::ModifyPositionSLTP(ulong ticket, double newSL, double newTP)
{
   if(!m_is_initialized || m_sym_helper == NULL || ticket == 0) return false;
   
   if(m_mock_execution)
      return true;
      
   double normSL = (newSL > 0.0) ? m_sym_helper.NormalizePrice(newSL) : 0.0;
   double normTP = (newTP > 0.0) ? m_sym_helper.NormalizePrice(newTP) : 0.0;
   
   for(int attempt = 0; attempt < m_max_retries; attempt++)
   {
      if(m_trade.PositionModify(ticket, normSL, normTP))
      {
         uint retcode = m_trade.ResultRetcode();
         if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_NO_CHANGES)
            return true;
      }
      
      uint retcode = m_trade.ResultRetcode();
      if(!IsRetriableError(retcode))
         return false;
         
      ApplyBackoff(attempt);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close Position by Ticket                                         |
//+------------------------------------------------------------------+
inline bool CExecutionEngine::ClosePosition(ulong ticket, double volume)
{
   if(!m_is_initialized || ticket == 0) return false;
   
   if(m_mock_execution)
      return true;
   
   for(int attempt = 0; attempt < m_max_retries; attempt++)
   {
      bool success = false;
      if(volume > 0.0 && m_sym_helper != NULL)
      {
         double normVol = m_sym_helper.NormalizeLot(volume);
         success = m_trade.PositionClosePartial(ticket, normVol, m_slippage_points);
      }
      else
      {
         success = m_trade.PositionClose(ticket, m_slippage_points);
      }
      
      if(success)
      {
         uint retcode = m_trade.ResultRetcode();
         if(retcode == TRADE_RETCODE_DONE)
            return true;
      }
      
      uint retcode = m_trade.ResultRetcode();
      if(!IsRetriableError(retcode))
         return false;
         
      ApplyBackoff(attempt);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Emergency Close All Positions matching Magic Number              |
//+------------------------------------------------------------------+
inline bool CExecutionEngine::CloseAllStrategyPositions(ulong magicNumber)
{
   if(m_mock_execution)
      return true;

   int total = PositionsTotal();
   bool allClosed = true;
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
            PositionGetInteger(POSITION_MAGIC) == (long)magicNumber)
         {
            if(!ClosePosition(ticket))
               allClosed = false;
         }
      }
   }
   
   return allClosed;
}

#endif // LEGSTECH_ENGINE_EXECUTIONENGINE_MQH
