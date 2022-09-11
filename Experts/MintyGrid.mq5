//+------------------------------------------------------------------+
//|                                                    MintyGrid.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.0"

#include <checkhistory.mqh>
#include <Trade/Trade.mqh>
#include <Controls/Panel.mqh>
#include <Controls/Label.mqh>

//--- Risk settings parameters
input double   minInitialRiskFactor=0.01; // Initial risk factor, percentage of balance by minimum lot
input double   maxIntialRiskFactor=0.1; // Max initial risk factor, percentage of balance by minimum lot
input double   profitFactor=0.5; // Profit factor, percentage of balance
//--- Martingale grid settings
input double   lotMultiplier=1.5; // Grid step martingale lot multiplier
input double   lotDeviser=3; // Grid reverse martingale lot deviser
input double   gridStep=0.3; // Grid step price movement percentage
//--- trade settings
input bool     buy = true;
input bool     sell = true;
//--- Symbol settings
input string   currencyPairs = "EURUSD,EURGBP,GBPUSD"; // Symbols to trade comma seperated
//--- Expert Advisor settings
input int      magicNumber = 901239; // Magic

CTrade trade;
CPositionInfo position;
COrderInfo order;
CPanel panel;
CLabel label;

string symbols[];
int totalSymbols = 0;
ulong positionsToClose[];


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(1);

   int split=StringSplit(currencyPairs,",",symbols);
   ArrayRemove(symbols,ArraySize(symbols),1);
   totalSymbols=ArraySize(symbols);
   for(int i=0; i<totalSymbols; i++)
     {
      CheckLoadHistory(symbols[i], _Period, 100000);
     }

   trade.SetExpertMagicNumber(magicNumber);
   trade.LogLevel(LOG_LEVEL_NO);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {

  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

  }

int tick = 0;
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(StringLen(symbols[tick])>0)
     {
      Tick(symbols[tick]);
     }
   tick++;
   if(tick == totalSymbols)
     {
      tick=0;
     }
  }

//---
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void Tick(string symbol)
  {
   double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   double profit = AccountInfoDouble(ACCOUNT_PROFIT);

   double lotMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotMax = SymbolInfoDouble(symbol,SYMBOL_VOLUME_LIMIT);
   if(lotMax==0)
      lotMax=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   int lotDecimals = lotStep > 0.09 ? lotStep > 0.9 ? 0 : 1 : 2;
   double initialLots = NormalizeDouble(balance/totalSymbols/(100)*minInitialRiskFactor*lotMin,lotDecimals);
   double maxInitialLot = NormalizeDouble(balance/totalSymbols/(100)*maxIntialRiskFactor*lotMin,lotDecimals);
   double targetProfit = balance/totalSymbols/100*profitFactor;

   int buyPositions = 0;
   int sellPositions = 0;

   double buyProfit = 0;
   double sellProfit = 0;

   double lowestBuyPrice = 0;
   double highestBuyPrice = 0;
   double highestBuyLots = 0;
   double highestOverallBuyLots = 0;
   double totalOverallBuyLots = 0;

   double lowestSellPrice = 0;
   double highestSellPrice = 0;
   double highestSellLots = 0;
   double highestOverallSellLots = 0;
   double totalOverallSellLots = 0;

   double totalOverallLots = 0;

   double buyLots = 0;
   double sellLots = 0;

   double symbolProfit = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      position.SelectByIndex(i);
      symbolProfit = position.Profit();
      if(position.PositionType() == POSITION_TYPE_BUY && position.Symbol() == symbol && position.Magic() == magicNumber)
        {
         buyPositions++;
         buyLots += position.Volume();
         buyProfit += position.Profit();
         if(lowestBuyPrice == 0 || position.PriceOpen() < lowestBuyPrice)
           {
            lowestBuyPrice = position.PriceOpen();
           }
         if(highestBuyPrice == 0 || position.PriceOpen() > highestBuyPrice)
           {
            highestBuyPrice = position.PriceOpen();
           }
         if(highestBuyLots == 0 || position.Volume() > highestBuyLots)
           {
            highestBuyLots = position.Volume();
           }
        }
      if(position.PositionType() == POSITION_TYPE_BUY && position.Magic() == magicNumber)
        {
         if(highestOverallBuyLots == 0 || position.Volume() > highestOverallBuyLots)
           {
            highestOverallBuyLots = position.Volume();
            totalOverallBuyLots += position.Volume();
            totalOverallLots += position.Volume();
           }
        }
      if(position.PositionType() == POSITION_TYPE_SELL && position.Magic() == magicNumber)
        {
         if(highestOverallSellLots == 0 || position.Volume() > highestOverallSellLots)
           {
            highestOverallSellLots = position.Volume();
            totalOverallSellLots += position.Volume();
            totalOverallLots += position.Volume();
           }

        }
      if(position.PositionType() == POSITION_TYPE_SELL && position.Symbol() == symbol && position.Magic() == magicNumber)
        {
         sellPositions++;
         sellLots += position.Volume();
         sellProfit += position.Profit();
         if(lowestSellPrice == 0 || position.PriceOpen() < lowestSellPrice)
           {
            lowestSellPrice = position.PriceOpen();
           }
         if(highestSellPrice == 0 || position.PriceOpen() > highestSellPrice)
           {
            highestSellPrice = position.PriceOpen();
           }
         if(highestSellLots == 0 || position.Volume() > highestSellLots)
           {
            highestSellLots = position.Volume();
           }
        }

     }

   if(sellProfit > targetProfit)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.PositionType() == POSITION_TYPE_SELL && position.Symbol() == symbol && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }

   if(buyProfit > targetProfit)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.PositionType() == POSITION_TYPE_BUY && position.Symbol() == symbol && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }

   if(buyProfit+sellProfit > targetProfit && (lowestSellPrice > highestBuyPrice))
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.Symbol() == symbol && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }


   if(lowestBuyPrice-(lowestBuyPrice/100*gridStep) >= ask && buyLots != 0)
     {
      double volume = buyPositions*initialLots*lotMultiplier > highestBuyLots*lotMultiplier ? buyPositions*initialLots*lotMultiplier : highestBuyLots*lotMultiplier;
      volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotDecimals);
      volume =  NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotDecimals);

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_BUY) && totalOverallLots+volume < lotMax)
        {
         trade.Buy(volume,symbol,0,0,0,"MintyGrid Buy " + symbol + " step " + IntegerToString(buyPositions + 1));
        }

     }

   if(highestSellPrice+(highestSellPrice/100*gridStep) <= bid && sellLots != 0)
     {
      double volume = sellPositions*initialLots*lotMultiplier > highestSellLots*lotMultiplier ? sellPositions*initialLots*lotMultiplier : highestSellLots*lotMultiplier;
      volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotDecimals);
      volume = NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotDecimals);

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_SELL) && totalOverallLots+volume < lotMax)
        {
         trade.Sell(volume,symbol,0,0,0,"MintyGrid Sell " + symbol + " step " + IntegerToString(sellPositions + 1));
        }
     }

   if(buyPositions == 0 && buy)
     {
      double highestLot = sellPositions == 0 ? 0 : sellLots/sellPositions/lotDeviser;
      double volume = highestLot < initialLots ? initialLots : highestLot;
      volume = volume > maxInitialLot ? maxInitialLot : volume;
      volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotDecimals);
      volume =  NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotDecimals);
      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_BUY) && totalOverallLots+volume < lotMax)
        {
         trade.Buy(volume,symbol,0,0,0,"MintyGrid Buy " + symbol + " step " + IntegerToString(buyPositions + 1));
        }
     }

   if((buyPositions > 0 || !buy) && sellPositions == 0 && (bid > lowestBuyPrice) && sell)
     {
      double highestLot = buyPositions == 0 ? 0 : buyLots/buyPositions/lotDeviser;
      double volume = highestLot < initialLots ? initialLots : highestLot;
      volume = volume > maxInitialLot ? maxInitialLot : volume;
      volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotDecimals);
      volume = NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotDecimals);
      
      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_SELL) && totalOverallLots+volume < lotMax)
        {
         trade.Sell(volume,symbol,0,0,0,"MintyGrid Sell " + symbol + " step " + IntegerToString(sellPositions + 1));
        }
     }

   closeOpenPositions();

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckMoneyForTrade(string symb,double lots,ENUM_ORDER_TYPE type)
  {
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!OrderCalcMargin(type,symb,lots,price,margin))
     {

      return(false);
     }
   if(margin>free_margin)
     {

      return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int StringSplit(string string_value,string separator,string &result[],int limit = 0)
  {
   int n=1, pos=-1, len=StringLen(separator);
   while((pos=StringFind(string_value,separator,pos))>=0)
     {
      ArrayResize(result,++n);
      result[n-1]=StringSubstr(string_value,0,pos);
      if(n==limit)
         return n;
      string_value=StringSubstr(string_value,pos+len);
      pos=-1;
     }
//--- append the last part
   ArrayResize(result,++n);
   result[n-1]=string_value;
   return n;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closePosition(ulong ticket)
  {
   int index = ArraySize(positionsToClose);

   for(int i = 0; i < index; i++)
     {
      if(positionsToClose[i] == ticket)
        {
         return;
        }
     }

   ArrayResize(positionsToClose, index+1);
   positionsToClose[index] = ticket;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeOpenPositions()
  {
   for(int i = 0; i < ArraySize(positionsToClose); i++)
     {
      position.SelectByTicket(positionsToClose[i]);
      if(position.PriceCurrent() > 0)
        {
         trade.PositionClose(position.Ticket());
        }
     }
  }

//+------------------------------------------------------------------+