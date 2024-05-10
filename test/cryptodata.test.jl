# dev ./CryptoOHLCV
using RelevanceStacktrace
using Boilerplate
using Revise
using UniversalStruct
using CryptoOHLCV
# ctx.source   = "binance:BNB_BTC:futures"
# set_day_range!(ctx; dayframe = 3:4)
# set_day_range!(ctx; dayframe = 14:31)

d= ohlcv"1m"
d= ohlcv"BTC_USDT@1m:futures"
# d = ohlcv"1h"
# d= ohlcv"5m"
# d= ohlcv"tick100"
# d= ohlcv"sick100"
# d= ohlcv"mick100"
# d= ohlcv_v"5m"
# d= ohlcv_v"30m"
# d= ohlcv_v"tick500"

#%%
@sizes d.t
#%%
using Dates
now(UTC)
#%%
using Dates
display([unix2datetime.(floor.([Int64], d.t ./ 1000)) d.c])
#%%
using Dates
display.(unix2datetime.(floor.([Int64], d.t ./ 1000)))
#%%
all(d.t[2:end].-d.t[1:end-1] .== 60000)
#%%
using Dates
unix2datetime(1709567940)
#%%

using CryptoOHLCV: start_LIVE_data, stop_LIVE_data

start_LIVE_data(d)
@show "ok"
#%%
stop_LIVE_data(d)
@show "super"

#%%
@show "okfefe"
#%%
(UniversalStruct.folder(d))
#%%
f=Int.((d.t .+  60000) ./ 3600000)
#%%
println(f[2:end] .- f[1:end-1])
#%%
(f[3]+1) /36
#%%
floor(Int,datetime2unix(now()))
#%%
using Dates
unix2datetime.(d.t ./1000)
#%%
d.c
#%%

ctx.dayframe=22:23
d= ohlcv"tick100"

#%%
using CryptoOHLCV: query_trades

a = query_trades("BTC/USDT", 1703617440, 1703619440)

#%%
using Boilerplate
@sizes a
#%%
1706959343, 
1706959380
1707045720
1707045743

xx=[1707042420000, 1707042480000, 1707042540000, 1707042600000, 1707042660000, 1707042720000, 1707042780000, 1707042840000, 1707042900000, 1707042960000, 1707043020000, 1707043080000, 1707043140000, 1707043200000, 1707043260000, 1707043320000, 1707043380000, 1707043440000, 1707043500000, 1707043560000, 1707043620000, 1707043680000, 1707043740000, 1707043800000, 1707043860000, 1707043920000, 1707043980000, 1707044040000, 1707044100000, 1707044160000, 1707044220000, 1707044280000, 1707044340000, 1707044400000, 1707044460000, 1707044520000, 1707044580000, 1707044640000, 1707044700000, 1707044760000, 1707044820000, 1707044880000, 1707044940000, 1707045000000, 1707045060000, 1707045120000, 1707045180000, 1707045240000, 1707045300000, 1707045360000, 1707045420000, 1707045480000, 1707045540000, 1707045600000, 1707045660000, 1707045720000]

#%%

12:59 -  67399.1  -  67399.1
13:00 -  67396.2  -  67399.1
13:59 -  67851.9  -  
14:00 -  67763.9  -  67851.9
14:59 -  68809.6  -
15:00 -  68863.9  -  68809.6
#%%
00  00 0 
01  00 0
02  00 0
03  00 0
04  00 0
05  05 0
06  05 0
07  05 0
08  05 0
.. 
58  55 0
59  55 0
00  00 1

#%%
