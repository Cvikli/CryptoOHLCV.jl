
market_name_process(market_str) = begin
  res = String.(split(market_str, ":"))
	length(res) == 1 && return "binance", market_str, false
  length(res) == 2 && res[2] !== "futures" && return res[1], res[2], false
  length(res) == 2 && res[2]  == "futures" && return "binance", res[1], true
  length(res) == 3 && return res[1], res[2], res[3] == "futures"
	@assert false "unparseable market source $market_str"
end
get_source(ex, market, isfuture) = "$ex:$market$(isfutures_long(isfuture))"

parse_ohlcv_meta(s::String) = begin
	@assert !(s[end]=='s') "Second bar isn't supported yet...!"
	s[end]=='s'     && return :SECOND,     parse(Int,s[1:end-1])
	s[end]=='m'     && return :MINUTE,     parse(Int,s[1:end-1])*60
	s[end]=='h'     && return :HOUR,       parse(Int,s[1:end-1])*60*60
	s[end]=='d'     && return :DAY,        parse(Int,s[1:end-1])*60*60*24
	s[1:4]=="tick"  && return :TICK,       parse(Int,s[5:end])
	return :UNKNOWN, -1
end
reverse_parse_candle(candly_type, candle_value) = begin
	candly_type==:SECOND     && return "$(candle_value)s"
	candly_type==:MINUTE     && return "$(cld(candle_value, 60))m"
	candly_type==:HOUR       && return "$(cld(candle_value, 60*60))h"
	candly_type==:DAY        && return "$(cld(candle_value, 60*60*24))d"
	candly_type==:TICK_STONE && return "sick$(candle_value)"
	candly_type==:TICK_MMM   && return "mick$(candle_value)"
	candly_type==:TICK       && return "tick$(candle_value)"
	throw("Unknown type")
end


UniversalStruct.init(TYPE::Type{OHLCV}, src, candle, fr, to) = begin
	exchange, market, isfutures = market_name_process(src)
	candle_type, candle_value   = parse_ohlcv_meta(candle)
	TYPE(exchange=    exchange,
			 market=      market,
			 is_futures=  isfutures, 
			 candle_type= candle_type,
			 candle_value=candle_value,
			 timestamps = ceil_ts(fr, candle_value):floor_ts(to, candle_value))
end


extend(d::T, o, h, l, c, v, OHLCV_time, misses) where T <: CandleType = begin
	d.ts     = !isempty(d.ts)     ? vcat(d.ts,OHLCV_time) : OHLCV_time
  d.misses = !isempty(d.misses) ? vcat(d.misses,misses) : misses
	d.o,d.h,d.l,d.c,d.v = o, h, l, c, v
end
UniversalStruct.load_data!(o::T) where T <: CandleType = o.candle_type in [
		:TICK, 
	] ? load_new_tick_data(o) : load_new_minute_data(o)

	
load_new_minute_data(d) = begin
	o_fr, o_to = first(d.timestamps), last(d.timestamps)
	if d.exchange !== "binance"
    data_OHLCV, ts, misses    = dwnl_data_ccxt("$(d.exchange):$(d.market):$(d.isfutures)", o_fr, o_to, "1m", ctx.now_ts)
	else
		o, h, l, c, v, ts, misses = dwnl_minute_data(d.market, d.is_futures, o_fr, o_to)
	end
	extend(d, o, h, l, c, v, ts, misses)
	d
end
load_new_tick_data(d) = begin
	o_fr, o_to = first(d.timestamps), last(d.timestamps)
	if d.exchange !== "binance"
    data_OHLCV, ts, misses    = dwnl_tick_ccxt("$(exchange):$(market):$(isfutures)", start_date, end_date, "tick", ctx.now_ts)
	else
		maket = replace(d.market, "_" => "")
		o, h, l, c, v, ts, misses = dwnl_tick_data(maket, d.is_futures, o_fr, o_to)
	end
	extend(d, o, h, l, c, v, ts, misses)
	d
end


dwnl_minute_data(market, isfutures, start_date, end_date) = begin
	metric = candle2metric("1m")
	misses = UnitRange{Int}[]
	market_data                 = query_klines(replace(market, "_"=>""), "1m", start_date, end_date, isfutures ? Val(:FUTURES) : Val(:SPOT));
	o, h, l, c, v, ts           = marketdata2ohlcvt(market_data)
	(o, h, l, c, v), misses, ts = interpolate_missing((o, h, l, c, v), ts, metric*1000)
	return o, h, l, c, v, ts, misses
end

dwnl_tick_data(market, isfutures, start_date, end_date) = begin
	misses = UnitRange{Int}[]
	tick_raw = query_ticks(market, isfutures, start_date, end_date)
	id, ts, c, v = tick_raw
	o=[c[1];c[1:end-1]]
	h=max.(o,c)
	l=min.(o,c)
	return o, h, l, c, v, ts, misses
end
dwnl_data_ccxt(src, start_date, end_date, candle, ct_now) = @assert false "unimplemented... I need to copy this yet..."
dwnl_tick_ccxt(src, start_date, end_date, candle, ct_now) = @assert false "unimplemented... I need to copy this yet..."


postprocess_ohlcv!(o::T) where T <: CandleType = if o.candle_type in 
		[
			:TICK, 
			:TICK_MMM, :TICK_STONE
		]
		@warn "from and to date isn't supported for tick data!! TODO"
		# all_data = refresh_tick_data(  o.exchange, o.market, o.is_futures, first(o.timestamps), last(o.timestamps))
		# cut_data_tick!(o, all_data)
		o.o, o.h, o.l, o.c, o.v, o.ts = combine_klines_fast_tick(o, o.candle_value, Val(o.candle_type))
	else
		# all_data = refresh_minute_data(o.exchange, o.market, o.is_futures, first(o.timestamps), last(o.timestamps))
		# cut_data_1m!(o, all_data)

		@assert o.candle_value>=60 "We cannot handle things under 1min(60s) d.candle_value=$(o.candle_value)"
		metric_round = cld(o.candle_value,60)
		o.o, o.h, o.l, o.c, o.v, o.ts = combine_klines_fast(o, metric_round)

		@assert  all(o.ts[2:end] .- o.ts[1:end-1] .== o.candle_value*1000) "$(o.ts[2:end] .- o.ts[1:end-1])"
	end
