#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <MyClass\交易类\交易指令.mqh>
交易指令 jy;
#include <MyClass\交易类\仓位管理.mqh>
仓位管理 hg;

void OnStart()
{  
   double lots = hg.HG_LOTS(Symbol(), 20);
   double buy_sl = hg.HG_SL(Symbol(), 20, ORDER_TYPE_BUY);
   double sell_sl = hg.HG_SL(Symbol(), 20, ORDER_TYPE_SELL);
   
   jy.OrderOpen(Symbol(), ORDER_TYPE_BUY, lots, 200, 200, "BUY", 123, 5);
   
   jy.OrderModify(Symbol(), POSITION_TYPE_BUY, buy_sl, 0, 123); 

   //jy.OrderModify(Symbol(), POSITION_TYPE_SELL, sell_sl, 0.0, 123);  
   
   

}