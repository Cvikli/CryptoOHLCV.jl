using CryptoOHLCV: get_ohlcv

# Example 1: Using global context
# ctx.market = "BTC_USDT"
# ctx.exchange = "binance"
# ctx.is_futures = true

# # Load data using context
# data1 = load_market_data("1h|0*580")
# data2 = load_market_data(timeframe="1h", from_day=0, to_day=7)

# # Example 2: Using explicit parameters without global context
# data3 = get_ohlcv_pro(
#     "BTC_USDT",    # market
#     "1h",         # timeframe
#     0,           # from_day
#     580,          # to_day
#     exchange="binance",
#     is_futures=true
# )

# Example 3: Using string syntax directly
@time get_ohlcv("binance:BTC_USDT@4h:futures|0*200")  # Last 7 days of hourly data
@time get_ohlcv("binance:ETH_USDT@4h:futures|0*100")  # Last 7 days of hourly data
# @time data4 = get_ohlcv("binance:DOGE_USDT@1d:futures|0*200")  # Last 7 days of hourly data

@show size(data4.c)
;
#%%
