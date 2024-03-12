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

using Base: @kwdef

using HTTP
using JSON

using MemoizeTyped
using UniversalStruct



abstract type CandleType <: Universal end



@kwdef mutable struct OHLCV <: CandleType
	exchange::String    = ""
	market::String      = ""
	is_futures::Bool    = false
	candle_type::Symbol = :UNKNOWN   # :TICK, :SECOND, :MINUTE, :HOUR, :DAY
	candle_value::Int   = -1
	timestamps::UnitRange{Int} = UnitRange{Int}(first(ctx.timestamps),last(ctx.timestamps))
	
	context::OHLCVConfig= ctx

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
@kwdef mutable struct OHLCV_v <: CandleType  # for validation to make sure we don't make mistakes!
	exchange::String    = ""
	market::String      = ""
	is_futures::Bool    = false
	candle_type::Symbol = :UNKNOWN   # :TICK, :SECOND, :MINUTE, :HOUR, :DAY
	candle_value::Int   = -1
	timestamps::UnitRange{Int} = UnitRange{Int}(first(ctx.timestamps_v),last(ctx.timestamps_v))
	
	context::OHLCVConfig= ctx

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

set(::OHLCV)   = :TRAIN
set(::OHLCV_v) = :VALIDATION

date_range(ohlcv::T) where T <: CandleType = date_range(first(ohlcv.timestamps),last(ohlcv.timestamps)) # format(DateTime(first(ohlcv.t)), "yyyy.mm.dd HH:MM")
splatt(ohlcv::T)     where T <: CandleType = (ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.t)

fix_type(d::OHLCV_v, ::Type{OHLCV_v}) = d
fix_type(d::OHLCV,   ::Type{OHLCV})   = d
fix_type(d::OHLCV,   ::Type{OHLCV_v}) = OHLCV_v(d.exchange, d.market, d.is_futures, d.candle_type, d.candle_value, d.timestamps,d.context,
																								d.misses, d.t, d.o,d.h,d.l,d.c,d.v, d.LIVE, d.used)
fix_type(d::OHLCV_v, ::Type{OHLCV})   = OHLCV(d.exchange,   d.market, d.is_futures, d.candle_type, d.candle_value, d.timestamps,d.context,
																							d.misses,   d.t, d.o,d.h,d.l,d.c,d.v, d.LIVE, d.used)
														



include("CryptoOHLCVUtils.jl")
include("CryptoOHLCV_InitLoad.jl")
include("CryptoOHLCV_Extend.jl")
include("CryptoOHLCV_Persist.jl")

const ohlcv_load   = Dict{Tuple{DataType, String, String, Int, Int},OHLCV}()
const ohlcv_v_load = Dict{Tuple{DataType, String, String, Int, Int},OHLCV_v}()

get_ohlcv(candle, context=ctx) = begin
	fr, to, market = first(context.timestamps), last(context.timestamps), context.market
  @assert (datetime2unix(now(UTC))*1000 +1000 > to) "We want to query data from the future... please be careful: NOW: $(now(UTC)) TO: $(unix2datetime(to))" 
	key = (OHLCV, market, candle, fr, to)
	d = key in keys(ohlcv_load) ? ohlcv_load[key] : (ohlcv_load[key] = ((x=load(OHLCV, market, candle, fr, to, context)); postprocess_ohlcv!(x);x))
	# d = @memoize_typed OHLCV load(OHLCV, market, candle, fr, to)
	d
end
macro ohlcv_str(candle); get_ohlcv(candle); end

get_ohlcv_v(candle, context=ctx) = begin
	fr, to, market = first(context.timestamps_v), last(context.timestamps_v), context.market
	@assert (datetime2unix(now(UTC))*1000 +1000 > to) "We want to query data from the future... please be careful: NOW: $(now(UTC)) TO: $(unix2datetime(to))" 
	key = (OHLCV_v, market, candle, fr, to)
	d = key in keys(ohlcv_v_load) ? ohlcv_v_load[key] : (ohlcv_v_load[key] = ((x=load(OHLCV_v, market, candle, fr, to)); postprocess_ohlcv!(x);x))
	# d = @memoize_typed OHLCV_v load(OHLCV_v, market, candle, fr, to)
	d
end
macro ohlcv_v_str(candle); get_ohlcv_v(candle); end
					
include("CryptoOHLCV_LIVE.jl")



end # module CryptoOHLCV
