//+------------------------------------------------------------------+
//|                                                        Theme.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_UI_THEME_MQH
#define LEGSTECH_UI_THEME_MQH

#include <Object.mqh>
#include "..\Core\Defs.mqh"

//+------------------------------------------------------------------+
//| Color Constants & Design Tokens (LEGsTECH Brand Glassmorphism)   |
//+------------------------------------------------------------------+
#define COLOR_BRAND_BLUE         C'0,102,255'   // #0066FF Electric Royal Blue (Official Logo Color)
#define COLOR_BRAND_CYAN         C'0,229,255'   // #00E5FF Cyber Cyan (Official Tagline Accent)
#define COLOR_BRAND_GOLD         C'255,184,0'   // #FFB800 Institutional Gold (Profit & Highlight)
#define COLOR_BRAND_RED          C'239,68,68'   // #EF4444 Vibrant Brand Crimson
#define COLOR_BG_DARK_NAVY       C'8,13,26'     // #080D1A Deep Obsidian Base (Main Panel Surface)
#define COLOR_BG_CARD            C'15,23,42'    // #0F172A Slate Navy Card Surface
#define COLOR_BORDER_CARD        C'30,46,74'    // #1E2E4A Crisp High-Tech Border
#define COLOR_HEADER_DARK        C'10,15,29'    // #0A0F1D Matching logo_dark.bmp background
#define COLOR_TEXT_PRIMARY       C'241,245,249' // #F1F5F9 Crisp High-Contrast White
#define COLOR_TEXT_SECONDARY     C'148,163,184' // #94A3B8 Muted Slate Gray
#define COLOR_TEXT_DIM           C'100,116,139' // #64748B Dim Steel Gray
#define COLOR_TEXT_MUTED         C'71,85,105'   // #475569 Subtle Footnotes
#define COLOR_PROFIT_GREEN       C'16,185,129'  // #10B981 Vibrant Institutional Emerald
#define COLOR_LOSS_RED           C'239,68,68'   // #EF4444 Vibrant Coral Red
#define COLOR_WARN_AMBER         C'245,158,11'  // #F59E0B Warning Amber
#define COLOR_HALTED_RED         C'127,29,29'   // #7F1D1D Emergency Halted Dark Crimson

//+------------------------------------------------------------------+
//| Struct SUITheme: Palette, Typography & Styling Tokens            |
//+------------------------------------------------------------------+
struct SUITheme
{
   // Background & Surfaces
   color clrBackground;          // Main panel background (#0D1117)
   color clrCardBg;              // Section card container background (#161B22)
   color clrCardBorder;          // Section card container border (#30363D)
   color clrHeaderBg;            // Top branding banner background (#1F242C)
   
   // Brand & Accent Colors
   color clrPrimaryRed;          // Deep Spanish Red (#C0392B)
   color clrAccentGold;          // Saffron Gold (#F39C12)
   color clrAccentCyan;          // Cyber Cyan (#00D2FF)
   
   // Text Hierarchy
   color clrTextPrimary;         // Crisp White (#F0F6FC)
   color clrTextSecondary;       // Muted Slate Gray (#8B949E)
   color clrTextDim;             // Dim Gray (#586069)
   color clrTextMuted;           // Dim Slate (#484F58)
   
   // Status & Alerts
   color clrSuccess;             // Emerald Green (#2ECC71)
   color clrDanger;              // Crimson Alert (#E74C3C)
   color clrWarning;             // Amber Warning (#E67E22)
   
   // FSM State Colors
   color clrStateIdle;           // State IDLE (#95A5A6 Muted Silver)
   color clrStateAnalyzing;      // State ANALYSING (#3498DB Sky Blue)
   color clrStateSetupFound;     // State SETUP_FOUND (#F39C12 Gold / #9B59B6 Purple)
   color clrStateWaiting;        // State WAITING_FOR_CONFIRMATION_OR_TAP (#00D2FF Cyan / #E67E22 Amber)
   color clrStateWaitingTap;     // Alias WAITING_FOR_CONFIRMATION_OR_TAP
   color clrStateEntryReady;     // State ENTRY_READY (#2ECC71 Emerald Green)
   color clrStateExecuted;       // State EXECUTED (#9B59B6 Vivid Purple)
   color clrStateExecuting;      // Alias EXECUTED
   color clrStateManaging;       // State MANAGING (#E67E22 Warning Amber)
   color clrStateClosed;         // State CLOSED (#7F8C8D Neutral Gray)
   
   // Interactive Elements
   color clrButtonKillBg;        // Emergency Kill Button Normal Background (#C0392B)
   color clrButtonKillText;      // Emergency Kill Button Text (#FFFFFF)
   color clrButtonHaltedBg;      // Emergency Kill Button Active/Halted Background (#781919)
   
   // Typography Fonts
   string fontBrand;             // Brand heading font ("Trebuchet MS")
   string fontTitle;             // Primary section title font ("Trebuchet MS")
   string fontBody;              // Interface labels & body font ("Segoe UI")
   string fontMono;              // Telemetry, tickers & numeric values ("Consolas")
   
   // Font Sizes (Points)
   int fontSizeBrand;            // Brand title size (11pt)
   int fontSizeTitle;            // Title font size (10pt)
   int fontSizeHeader;           // Header font size (9pt)
   int fontSizeMetric;           // Metric highlight font size (10pt / 11pt)
   int fontSizeBody;             // Body text font size (8pt)
   int fontSizeSmall;            // Micro captions font size (7pt)

   // Initialize Default Dark Glassmorphism Theme
   void SetDefaultDarkTheme()
   {
      clrBackground       = COLOR_BG_DARK_NAVY;
      clrCardBg           = COLOR_BG_CARD;
      clrCardBorder       = COLOR_BORDER_CARD;
      clrHeaderBg         = COLOR_HEADER_DARK;
      
      clrPrimaryRed       = COLOR_BRAND_BLUE;
      clrAccentGold       = COLOR_BRAND_GOLD;
      clrAccentCyan       = COLOR_BRAND_CYAN;
      
      clrTextPrimary      = COLOR_TEXT_PRIMARY;
      clrTextSecondary    = COLOR_TEXT_SECONDARY;
      clrTextDim          = COLOR_TEXT_DIM;
      clrTextMuted        = COLOR_TEXT_MUTED;
      
      clrSuccess          = COLOR_PROFIT_GREEN;
      clrDanger           = COLOR_LOSS_RED;
      clrWarning          = COLOR_WARN_AMBER;
      
      clrStateIdle        = C'149,165,166'; // #95A5A6 Muted Silver
      clrStateAnalyzing   = C'52,152,219';  // #3498DB Sky Blue
      clrStateSetupFound  = COLOR_BRAND_GOLD; // #F39C12 Saffron Gold
      clrStateWaiting     = COLOR_BRAND_CYAN; // #00D2FF Cyber Cyan
      clrStateWaitingTap  = COLOR_BRAND_CYAN; // #00D2FF Cyber Cyan
      clrStateEntryReady  = COLOR_PROFIT_GREEN; // #2ECC71 Emerald Green
      clrStateExecuted    = C'155,89,182';  // #9B59B6 Vivid Purple
      clrStateExecuting   = C'155,89,182';  // #9B59B6 Vivid Purple
      clrStateManaging    = COLOR_WARN_AMBER; // #E67E22 Amber
      clrStateClosed      = C'127,140,141'; // #7F8C8D Neutral Gray
      
      clrButtonKillBg     = COLOR_BRAND_RED;
      clrButtonKillText   = C'255,255,255';
      clrButtonHaltedBg   = COLOR_HALTED_RED;
      
      fontBrand           = "Trebuchet MS";
      fontTitle           = "Trebuchet MS";
      fontBody            = "Segoe UI";
      fontMono            = "Consolas";
      
      fontSizeBrand       = 11;
      fontSizeTitle       = 10;
      fontSizeHeader      = 9;
      fontSizeMetric      = 10;
      fontSizeBody        = 8;
      fontSizeSmall       = 7;
   }
};

//+------------------------------------------------------------------+
//| Class CTheme: Theme Management & High-Performance Formatters     |
//+------------------------------------------------------------------+
class CTheme : public CObject
{
private:
   SUITheme             m_theme;

public:
                        CTheme()  { m_theme.SetDefaultDarkTheme(); }
   virtual             ~CTheme() {}

   void                 GetTheme(SUITheme &outTheme) const { outTheme = m_theme; }
   void                 SetTheme(const SUITheme &theme)    { m_theme = theme; }

   // Dynamic Color Mapping (Instance Methods)
   color                GetStateBadgeColor(ENUM_EA_STATE state) const
   {
      return GetStateColor(state, m_theme);
   }

   color                GetPnLColor(double pnl) const
   {
      return GetPnLColor(pnl, m_theme);
   }

   color                GetDrawdownColor(double currentDD, double maxDD) const
   {
      return GetDrawdownColor(currentDD, maxDD, m_theme);
   }

   color                GetSpreadColor(double currentSpread, double maxSpread) const
   {
      return GetSpreadColor(currentSpread, maxSpread, m_theme);
   }

   // Dynamic Color Mapping (Static Functions)
   static color GetStateColor(ENUM_EA_STATE state, const SUITheme &theme)
   {
      switch(state)
      {
         case EA_STATE_IDLE:                            return theme.clrStateIdle;
         case EA_STATE_ANALYSING:                       return theme.clrStateAnalyzing;
         case EA_STATE_SETUP_FOUND:                     return theme.clrStateSetupFound;
         case EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP: return theme.clrStateWaiting;
         case EA_STATE_ENTRY_READY:                     return theme.clrStateEntryReady;
         case EA_STATE_EXECUTED:                        return theme.clrStateExecuted;
         case EA_STATE_MANAGING:                        return theme.clrStateManaging;
         case EA_STATE_CLOSED:                          return theme.clrStateClosed;
         default:                                       return theme.clrStateIdle;
      }
   }

   static color GetPnLColor(double pnl, const SUITheme &theme)
   {
      if(pnl > 0.0001)  return theme.clrSuccess;
      if(pnl < -0.0001) return theme.clrDanger;
      return theme.clrTextSecondary;
   }

   static color GetDrawdownColor(double currentDD, double maxDD, const SUITheme &theme)
   {
      if(maxDD <= 0.0) return theme.clrTextPrimary;
      if(currentDD >= maxDD) return theme.clrDanger;
      if(currentDD >= maxDD * 0.70) return theme.clrWarning;
      return theme.clrTextSecondary;
   }

   static color GetSpreadColor(double currentSpread, double maxSpread, const SUITheme &theme)
   {
      if(maxSpread <= 0.0) return theme.clrTextPrimary;
      if(currentSpread > maxSpread) return theme.clrDanger;
      if(currentSpread > maxSpread * 0.75) return theme.clrAccentGold;
      return theme.clrSuccess;
   }

   // Formatting Utilities (Overloaded for Maximum Flexibility)
   static string FormatMoney(double amount, string currency = "$", int digits = 2, bool showSign = true)
   {
      if(amount > 0.00001)
      {
         string signStr = showSign ? "+" : "";
         return StringFormat("%s%s%.*f", signStr, currency, digits, amount);
      }
      else if(amount < -0.00001)
      {
         return StringFormat("-%s%.*f", currency, digits, MathAbs(amount));
      }
      return StringFormat("%s0.00", currency);
   }

   static string FormatMoney(double amount, int digits, bool showSign = true)
   {
      return FormatMoney(amount, "$", digits, showSign);
   }

   static string FormatPercent(double percent, bool showSign = true, int digits = 2)
   {
      if(percent > 0.00001)
      {
         string signStr = showSign ? "+" : "";
         return StringFormat("%s%.*f%%", signStr, digits, percent);
      }
      else if(percent < -0.00001)
      {
         return StringFormat("%.*f%%", digits, percent);
      }
      return "0.00%";
   }

   static string FormatPercent(double percent, int digits, bool showSign = false)
   {
      return FormatPercent(percent, showSign, digits);
   }

   static string FormatPips(double pips, int digits = 1)
   {
      if(pips > 0.00001)
         return StringFormat("+%.*f pips", digits, pips);
      else if(pips < -0.00001)
         return StringFormat("%.*f pips", digits, pips);
      return "0.0 pips";
   }

   static string FormatWinRate(double winRatePct, int wins, int total)
   {
      return StringFormat("%.1f%% (%d/%d)", winRatePct, wins, total);
   }
};

//+------------------------------------------------------------------+
//| Global Helper Function for State Color Resolution                |
//+------------------------------------------------------------------+
inline color GetStateColor(ENUM_EA_STATE state, const SUITheme &theme)
{
   return CTheme::GetStateColor(state, theme);
}

#endif // LEGSTECH_UI_THEME_MQH
