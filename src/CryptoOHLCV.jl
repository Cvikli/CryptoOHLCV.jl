module CryptoOHLCV


using Revise
using Boilerplate

using BinanceAPI: query_klines, query_ticks, initialize_binance, marketdata2ohlcvt
using Dates


export @ohlcv_str, @ohlcv_v_str, ctx, CandleType


include("Consts.jl")
include("Utils.jl")
include("Interpolations.jl")
include("Config.jl")

using Base: @kwdef

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

	misses::Vector{UnitRange}  = UnitRange{Int}[]

	ts::Vector{Int}     = Int[]
	o::Vector{Float32}  = Float32[]
	h::Vector{Float32}  = Float32[]
	l::Vector{Float32}  = Float32[]
	c::Vector{Float32}  = Float32[]
	v::Vector{Float32}  = Float32[]
end
@kwdef mutable struct OHLCV_v <: CandleType  # for validation to make sure we don't make mistakes!
	exchange::String    = ""
	market::String      = ""
	is_futures::Bool    = false
	candle_type::Symbol = :UNKNOWN   # :TICK, :SECOND, :MINUTE, :HOUR, :DAY
	candle_value::Int   = -1
	timestamps::UnitRange{Int} = UnitRange{Int}(first(ctx.timestamps_v),last(ctx.timestamps_v))

	misses::Vector{UnitRange}  = UnitRange{Int}[]

	ts::Vector{Int}     = Int[]
	o::Vector{Float32}  = Float32[]
	h::Vector{Float32}  = Float32[]
	l::Vector{Float32}  = Float32[]
	c::Vector{Float32}  = Float32[]
	v::Vector{Float32}  = Float32[]
end

set(::OHLCV)   = :TRAIN
set(::OHLCV_v) = :VALIDATION

date_range(ohlcv::T) where T <: CandleType = date_range(first(ohlcv.timestamps),last(ohlcv.timestamps)) # format(DateTime(first(ohlcv.ts)), "yyyy.mm.dd HH:MM")
splatt(ohlcv::T)     where T <: CandleType = (ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.ts)

fix_type(d::OHLCV_v, ::Type{OHLCV_v}) = d
fix_type(d::OHLCV,   ::Type{OHLCV})   = d
fix_type(d::OHLCV,   ::Type{OHLCV_v}) = OHLCV_v(d.exchange, d.market, d.is_futures, d.candle_type, d.candle_value, d.timestamps,
																								d.misses, d.ts, d.o,d.h,d.l,d.c,d.v)
fix_type(d::OHLCV_v, ::Type{OHLCV})   = OHLCV(d.exchange, d.market, d.is_futures, d.candle_type, d.candle_value, d.timestamps,
																							d.misses, d.ts, d.o,d.h,d.l,d.c,d.v)
														



include("CryptoOHLCVUtils.jl")
include("CryptoOHLCV_InitLoad.jl")
include("CryptoOHLCV_Extend.jl")
include("CryptoOHLCV_Persist.jl")

const ohlcv_load   = Dict{Tuple{DataType, String, String, Int, Int},OHLCV}()
const ohlcv_v_load = Dict{Tuple{DataType, String, String, Int, Int},OHLCV_v}()

get_ohlcv(candle, context=ctx) = begin
	fr, to, market = first(context.timestamps), last(context.timestamps), context.market
	key = (OHLCV, market, candle, fr, to)
	d = key in keys(ohlcv_load) ? ohlcv_load[key] : (ohlcv_load[key] = ((x=load(OHLCV, market, candle, fr, to)); postprocess_ohlcv!(x);x))
	# d = @memoize_typed OHLCV load(OHLCV, market, candle, fr, to)
	d
end
macro ohlcv_str(candle); get_ohlcv(candle); end

get_ohlcv_v(candle, context=ctx) = begin
	fr, to, market = first(context.timestamps_v), last(context.timestamps_v), context.market
	key = (OHLCV_v, market, candle, fr, to)
	d = key in keys(ohlcv_v_load) ? ohlcv_v_load[key] : (ohlcv_v_load[key] = ((x=load(OHLCV_v, market, candle, fr, to)); postprocess_ohlcv!(x);x))
	# d = @memoize_typed OHLCV_v load(OHLCV_v, market, candle, fr, to)
	d
end
macro ohlcv_v_str(candle); get_ohlcv_v(candle); end
					

# include("CryptoOHLCVFns.jl")


end # module CryptoOHLCV
