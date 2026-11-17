//+------------------------------------------------------------------+
//|                                                 StateMachine.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_CORE_STATEMACHINE_MQH
#define LEGSTECH_CORE_STATEMACHINE_MQH

#include <Object.mqh>
#include "Defs.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Class CStateMachine: Deterministic 8-State Engine with Guards    |
//+------------------------------------------------------------------+
class CStateMachine : public CObject
{
private:
   ENUM_EA_STATE     m_currentState;
   ENUM_EA_STATE     m_previousState;
   datetime          m_stateEntryTime;
   string            m_stateReason;
   CLogger          *m_logger;
   string            m_context;

   // Internal transition validation matrix
   bool              ValidateTransition(ENUM_EA_STATE fromState, ENUM_EA_STATE toState) const;

public:
                     CStateMachine();
   virtual          ~CStateMachine();

   bool              Init(CLogger *logger, string context = "FSM", ENUM_EA_STATE initialState = EA_STATE_IDLE);
   
   // State Manipulation
   bool              TransitionTo(ENUM_EA_STATE newState, string reason = "");
   void              ForceState(ENUM_EA_STATE forcedState, string reason = "EMERGENCY_OVERRIDE");
   void              Reset(string reason = "MANUAL_RESET");

   // State Inquiries
   bool              CanTransitionTo(ENUM_EA_STATE targetState) const;
   ENUM_EA_STATE     GetCurrentState() const         { return m_currentState; }
   ENUM_EA_STATE     GetPreviousState() const        { return m_previousState; }
   string            GetCurrentStateName() const     { return StateToString(m_currentState); }
   string            GetPreviousStateName() const    { return StateToString(m_previousState); }
   datetime          GetStateEntryTime() const       { return m_stateEntryTime; }
   int               GetStateDurationSeconds() const { return (int)(TimeCurrent() - m_stateEntryTime); }
   string            GetStateReason() const          { return m_stateReason; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStateMachine::CStateMachine()
{
   m_currentState   = EA_STATE_IDLE;
   m_previousState  = EA_STATE_IDLE;
   m_stateEntryTime = 0;
   m_stateReason    = "INITIALIZATION";
   m_logger         = NULL;
   m_context        = "FSM";
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStateMachine::~CStateMachine()
{
}

//+------------------------------------------------------------------+
//| Initialize State Machine                                         |
//+------------------------------------------------------------------+
inline bool CStateMachine::Init(CLogger *logger, string context, ENUM_EA_STATE initialState)
{
   m_logger         = logger;
   m_context        = (context == "" || context == NULL) ? "FSM" : context;
   m_currentState   = initialState;
   m_previousState  = initialState;
   m_stateEntryTime = TimeCurrent();
   m_stateReason    = "INITIAL_STATE";

   if(m_logger != NULL)
   {
      m_logger.Info(StringFormat("FSM initialized to state: %s", StateToString(m_currentState)), m_context);
   }
   return true;
}

//+------------------------------------------------------------------+
//| State Transition Matrix Guard Logic                              |
//+------------------------------------------------------------------+
inline bool CStateMachine::ValidateTransition(ENUM_EA_STATE fromState, ENUM_EA_STATE toState) const
{
   if(fromState == toState)
      return true; // No-op transition allowed

   switch(fromState)
   {
      case EA_STATE_IDLE:
         return (toState == EA_STATE_ANALYSING);

      case EA_STATE_ANALYSING:
         return (toState == EA_STATE_SETUP_FOUND || 
                 toState == EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP || 
                 toState == EA_STATE_IDLE);

      case EA_STATE_SETUP_FOUND:
         return (toState == EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP || 
                 toState == EA_STATE_ENTRY_READY || 
                 toState == EA_STATE_IDLE);

      case EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP:
         return (toState == EA_STATE_ENTRY_READY || 
                 toState == EA_STATE_IDLE || 
                 toState == EA_STATE_ANALYSING);

      case EA_STATE_ENTRY_READY:
         return (toState == EA_STATE_EXECUTED || toState == EA_STATE_IDLE || toState == EA_STATE_ANALYSING);

      case EA_STATE_EXECUTED:
         return (toState == EA_STATE_MANAGING || toState == EA_STATE_IDLE || toState == EA_STATE_CLOSED);

      case EA_STATE_MANAGING:
         return (toState == EA_STATE_CLOSED || toState == EA_STATE_IDLE);

      case EA_STATE_CLOSED:
         return (toState == EA_STATE_IDLE || toState == EA_STATE_ANALYSING);

      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Query if transition is permissible                               |
//+------------------------------------------------------------------+
inline bool CStateMachine::CanTransitionTo(ENUM_EA_STATE targetState) const
{
   return ValidateTransition(m_currentState, targetState);
}

//+------------------------------------------------------------------+
//| Transition to new state with guard check                         |
//+------------------------------------------------------------------+
inline bool CStateMachine::TransitionTo(ENUM_EA_STATE newState, string reason)
{
   if(!ValidateTransition(m_currentState, newState))
   {
      string errMsg = StringFormat("ILLEGAL STATE TRANSITION BLOCKED: %s -> %s (Reason: %s)",
                                   StateToString(m_currentState), StateToString(newState), reason);
      if(m_logger != NULL)
         m_logger.Error(errMsg, m_context);
      else
         PrintFormat("[ERROR] [%s] %s", m_context, errMsg);
      return false;
   }

   // If already in target state, do not spam transition logs
   if(m_currentState == newState)
   {
      return true;
   }

   m_previousState  = m_currentState;
   m_currentState   = newState;
   m_stateEntryTime = TimeCurrent();
   m_stateReason    = reason;

   if(m_logger != NULL)
   {
      m_logger.Info(StringFormat("STATE TRANSITION: %s -> %s | Reason: %s", 
                     StateToString(m_previousState), StateToString(m_currentState), reason), m_context);
      
      // Emit structured telemetry
      m_logger.Telemetry(StringFormat("{\"event\":\"STATE_CHANGE\",\"from\":\"%s\",\"to\":\"%s\",\"reason\":\"%s\",\"time\":%d}",
                          StateToString(m_previousState), StateToString(m_currentState), reason, (int)m_stateEntryTime));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Force State Override (Bypasses guards, for Emergency / Deinit)   |
//+------------------------------------------------------------------+
inline void CStateMachine::ForceState(ENUM_EA_STATE forcedState, string reason)
{
   m_previousState  = m_currentState;
   m_currentState   = forcedState;
   m_stateEntryTime = TimeCurrent();
   m_stateReason    = reason;

   if(m_logger != NULL)
   {
      m_logger.Warning(StringFormat("FORCED STATE OVERRIDE: %s -> %s | Reason: %s", 
                        StateToString(m_previousState), StateToString(m_currentState), reason), m_context);
   }
}

//+------------------------------------------------------------------+
//| Reset State Machine to IDLE                                      |
//+------------------------------------------------------------------+
inline void CStateMachine::Reset(string reason)
{
   ForceState(EA_STATE_IDLE, reason);
}

#endif // LEGSTECH_CORE_STATEMACHINE_MQH
