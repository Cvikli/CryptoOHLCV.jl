module CryptoOHLCV


using Revise
using Boilerplate
using Boilerplate: @async_showerr

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

using MemoizeTyped
using UniversalStruct
using UniversalStruct: load_nocache



abstract type CandleType <: Universal end


@kwdef mutable struct OHLCV <: CandleType
	set::Symbol         
	exchange::String    = ""
	market::String      = ""
	is_futures::Bool    = false
	candle_type::Symbol = :UNKNOWN   # :TICK, :SECOND, :MINUTE, :HOUR, :DAY
	candle_value::Int   = -1
	timestamps::UnitRange{Int} = UnitRange{Int}(first(ctx.timestamps),last(ctx.timestamps))
	
	data_path::String   = ctx.data_path

	misses::Vector{UnitRange}  = UnitRange{Int}[]

	t::Vector{Int}     = Int[]
	o::Vector{Float32} = Float32[]
	h::Vector{Float32} = Float32[]
	l::Vector{Float32} = Float32[]
	c::Vector{Float32} = Float32[]
	v::Vector{Float32} = Float32[]

	LIVE::Bool         = false
	used::Event        = Event()
end


date_range(ohlcv::T)    where T <: CandleType = date_range(first(ohlcv.timestamps),last(ohlcv.timestamps)) # format(DateTime(first(ohlcv.t)), "yyyy.mm.dd HH:MM")
splatt(ohlcv::T)        where T <: CandleType = (ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.t)
splatt_notime(ohlcv::T) where T <: CandleType = (ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v)
Base.getindex(ohlcv::OHLCV, idx::Int64) = ohlcv[idx:idx]
Base.getindex(ohlcv::OHLCV, rang::UnitRange{Int64}) = begin
	ex,market,fut = reconstruct_src(ohlcv)
	candle = reverse_parse_candle(ohlcv)
	d = get_ohlcv("$ex:$market@$(candle)$fut|$(first(rang))*$(last(rang))")
	d.set = ohlcv.set
	d
end

include("CryptoOHLCVUtils.jl")
include("CryptoOHLCV_Memoizable.jl")
include("CryptoOHLCV_InitLoad.jl")
include("CryptoOHLCV_Extend.jl")
include("CryptoOHLCV_Persist.jl")

const ohlcv_load = Dict{Tuple{DataType, Symbol, String, String, Bool, Symbol, Int, Int, Int},OHLCV}()

get_ohlcv(source, context=ctx) = begin
	key = unique_key(OHLCV, :TRAIN, source, context)
	# @show key
	d = key in keys(ohlcv_load) ? ohlcv_load[key] : (ohlcv_load[key] = ((x=load(key...)); postprocess_ohlcv!(x, true); x))
	# d = ((x= load(key...)); postprocess_ohlcv!(x, true); x)
	# d = @memoize_typed OHLCV load(OHLCV, market, candle, fr, to)
	d
end
macro ohlcv_str(source); get_ohlcv(source); end

get_ohlcv_v(source, context=ctx) = begin
	key = unique_key(OHLCV, :VALIDATION, source, context)
	d = key in keys(ohlcv_load) ? ohlcv_load[key] : (ohlcv_load[key] = ((x=load(key...)); postprocess_ohlcv!(x, true); x))
	d.set = :VALIDATION # TODO check if this is really needed. as for now I do this for safety reasons, although it could be because ohlcv was mutably changed before, but not anymore.
	# d = @memoize_typed OHLCV_v load(OHLCV_v, market, candle, fr, to)
	d
end
macro ohlcv_v_str(source); get_ohlcv_v(source); end
					
include("CryptoOHLCV_LIVE.jl")



end # module CryptoOHLCV
