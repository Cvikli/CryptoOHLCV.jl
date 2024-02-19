# CryptoOHLCV.jl
Simplest Crypto Data management

```julia
using CryptoOHLCV

d = ohlcv"1h"           # the 1h candles of the train set for the market and range that is configured by the "ctx" module variable
d = ohlcv"5m"
d = ohlcv"1m"
d = ohlcv"tick100"
d = ohlcv_v"5m"         # validation 5m candles for the configured market
d = ohlcv_v"30m"   
d = ohlcv_v"tick500"
```

Basically you can get the timeframe data anytime.

To configure your dataset you have to set the "Config"

```julia
using CryptoOHLCV
ctx.market   = "binance:BNB_BTC:futures"
ctx.dayframe = 0:2
```

`ctx` is a Config struct, the important things are: 
```julia
@kwdef mutable struct Config
  use_cache::Bool   = true 
  market::String    ="binance:BTC_USDT:futures"
	dayframe::UnitRange{Int}     = 30:41
	dayframe_v::UnitRange{Int}   = 50:60
	timestamps::UnitRange{Int}   = -1:-1
	timestamps_v::UnitRange{Int} = -1:-1
  maximum_candle_size::Int     = 3600
  data_path::String = "./data"
end
 ```
So the key is to "set the data range accurately" => Then work with this. 

# Features
- It handles different timeframes
- Configurable timerange and dataset with days (or timestamps) with `ctx`.
- Caches locally (so the next time you access the ohlcv"5m" on this range it is just map out the value from the dictionary)
- Caches to the disk, so whenever you download some new dataset, it will be reused later on by extending this further.
- Automatically cleans the data that is overlapped by bigger dataset.
- `tick100` or... so `tick`N options to address tick data on a range
- Candle sync, so basically we cut every "start timestamp" to be divideable with a "hour" so if you use different timeframes, you still work on the same dataset, till you are below 1 hour. If you are over that, then you have to change the "maximum_candle_size" (in seconds)
- It handles validation and train dataset with a `_v` suffix. So we can make sure we don't overlap due to we select diffferent ranges for sure. 
- CCXT is used, it can be easily extended to handle even more exchange. (Not sure if it is working atm but it is easily implementable for sure from here)


# TODO:
- We have to implement the "LIVE" feature. so the data would be always addressing the "from:LIVE" range. VERY easy to do... so later on!
- checking for errors!

# Any advice is appreciated!


