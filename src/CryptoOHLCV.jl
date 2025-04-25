module CryptoOHLCV


using BoilerplateCvikli
using BoilerplateCvikli: @async_showerr

using BinanceAPI: query_klines, query_ticks, initialize_binance, marketdata2ohlcvt, get_stream_url, CANDLE_TO_MS
using Dates
using Base: Event, notify, reset


export @ohlcv_str, @ohlcv_v_str, ctx, CandleType


include("Consts.jl")
include("Utils.jl")
include("Interpolations.jl")
include("Config.jl")
include("Normalizer.jl")

using Base: @kwdef

using HTTP
using HTTP.Exceptions: ConnectError
using JSON3



include("CryptoOHLCV_Types.jl")
include("CryptoOHLCV_Utils.jl")
include("CryptoOHLCV_Memoizable.jl")
include("CryptoOHLCV_InitLoad.jl")
include("CryptoOHLCV_Extend.jl")
include("CryptoOHLCV_Persist.jl")
include("CryptoOHLCV_Core.jl")
					
include("CryptoOHLCV_LIVE.jl")



end # module CryptoOHLCV
