
abstract type CandleType end


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

# We recreate a new OHLCV from the old ohlcv
create_OHLCV_from(orig, o,h,l,c,v,t) = OHLCV(orig.set, orig.exchange, orig.market, orig.is_futures, orig.candle_type, orig.candle_value, orig.timestamps, "", orig.misses, t, o,h,l,c,v, false, Event())

date_range(ohlcv::T)    where T <: CandleType = date_range(first(ohlcv.timestamps),last(ohlcv.timestamps)) # format(DateTime(first(ohlcv.t)), "yyyy.mm.dd HH:MM")
splatt(ohlcv::T)        where T <: CandleType = (ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.t)
splatt_notime(ohlcv::T) where T <: CandleType = (ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v)
Base.length(ohlcv::OHLCV) = length(ohlcv.t)
Base.getindex(ohlcv::OHLCV, idx::Int64) = ohlcv[idx:idx]
Base.getindex(ohlcv::OHLCV, rang::UnitRange{Int64}) = begin
	ex,market,fut = reconstruct_src(ohlcv)
	candle = reverse_parse_candle(ohlcv)
	d = get_ohlcv("$ex:$market@$(candle)$fut|$(first(rang))*$(last(rang))")
	d.set = ohlcv.set
	d
end
