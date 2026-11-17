//+------------------------------------------------------------------+
//|                                                    IStrategy.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_STRATEGIES_ISTRATEGY_MQH
#define LEGSTECH_STRATEGIES_ISTRATEGY_MQH

#include "..\Core\Defs.mqh"

//+------------------------------------------------------------------+
//| Interface IStrategy: Universal Polymorphic Strategy Contract     |
//+------------------------------------------------------------------+
interface IStrategy
{
   virtual bool            Init(const string symbol, ENUM_TIMEFRAMES timeframe) = 0;
   virtual void            Deinit() = 0;
   virtual void            OnTickHandler() = 0;
   virtual void            OnBarHandler(ENUM_TIMEFRAMES tf) = 0;
   virtual void            EvaluateSetup() = 0;
   virtual bool            GetTradeSignals(STradeSignal &outSignal) = 0;
   virtual void            ManageOpenPositions() = 0;
   virtual ENUM_EA_STATE   GetState() = 0;
   virtual void            SetState(ENUM_EA_STATE newState) = 0;
   virtual void            Reset() = 0;
   virtual string          GetStrategyName() = 0;
   virtual string          GetStatusString() = 0;
};

#endif // LEGSTECH_STRATEGIES_ISTRATEGY_MQH
