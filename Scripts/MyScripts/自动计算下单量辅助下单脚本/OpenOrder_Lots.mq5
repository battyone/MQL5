#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

//使脚本可以提供用户输入界面
#property script_show_inputs

#include <MyClass\shuju.mqh>
#include <MyClass\交易类\信息类.mqh>
#include <MyClass\交易类\交易指令.mqh>
#include <MyClass\交易类\仓位管理.mqh>
ShuJu sj;
交易指令 jy;
账户信息 zh;
仓位管理 cw;

//+------------------------------------------------------------------+
//| 初始化全局变量                                                   |
//+------------------------------------------------------------------+

input int MaxRisk = 1;            // 允许最大损失占余额比例
input ENUM_ORDER_TYPE OrderType;  //订单类型
input int SL = 40;                //止损点位

void OnStart()
{  
   sj.getask(Symbol());           //获取做多价格
   sj.getbid(Symbol());           //获取做空价格
   double pip = cw.PIP_Value(Symbol());                     // 一标准手价格波动1pip对应的账户资金价值
   double maxLoss = MaxRisk * zh.账户余额() * 0.01;         // 允许的最大损失所对应的余额价值
   double lots = NormalizeDouble(maxLoss / (SL * pip), 2);  //计算下单手数
   double min_lots = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN); //单笔订单最小下单量
   
   if(lots >= min_lots)
   {
      if(OrderType == ORDER_TYPE_BUY || OrderType == ORDER_TYPE_SELL)
      {
         if(jy.OrderOpen(Symbol(), OrderType, lots, SL, SL, "BUY", 6688, 0) > 0)
         {
            printf(string(OrderType) + "开单成功，此单必盈利！");
         }
      }
      else
      {
         printf("暂不支持此类型的订单，请重新输入市价单类型！");
      }
   }
   else
   {
      printf("下单量过小，请调整【最大损失占比】");
   }
}