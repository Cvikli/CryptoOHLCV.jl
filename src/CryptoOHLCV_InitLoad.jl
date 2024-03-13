
UniversalStruct.init(TYPE::Type{T}, set, exchange, market, is_futures, candle_type, candle_value, fr, to) where T <: CandleType = begin
  @assert (datetime2unix(now(UTC))*1000 + 1000 > to) "We want to query data from the future... please be careful: NOW: $(now(UTC)) TO: $(unix2datetime(to))" 
	@assert fr < to "Wrong dates: from $fr to $to is wrong as it is: $(to-fr) time"
	TYPE(timestamps = fr:to
			;set, exchange, market, is_futures, candle_type, candle_value,
	)
end


UniversalStruct.load_data!(o::T) where T <: CandleType = o.candle_type in [
		:TICK, 
	] ? load_new_tick_data(o) : load_new_minute_data(o)

	
extend(d::T, o, h, l, c, v, OHLCV_time, misses) where T <: CandleType = begin
	d.t      = !isempty(d.t)      ? vcat(d.t,OHLCV_time)  : OHLCV_time
	d.misses = !isempty(d.misses) ? vcat(d.misses,misses) : misses
	d.o,d.h,d.l,d.c,d.v = o, h, l, c, v
end
	
load_new_minute_data(d) = begin
	o_fr, o_to = first(d.timestamps), last(d.timestamps)
	if d.exchange !== "binance"
    o, h, l, c, v, t, misses = dwnl_data_ccxt("$(d.exchange):$(d.market):$(d.isfutures)", o_fr, o_to, "1m", d.context.now_ts)
	else
		o, h, l, c, v, t, misses = dwnl_minute_data(d.market, d.is_futures, o_fr, o_to)
	end
	extend(d, o, h, l, c, v, t, misses)
	d
end
load_new_tick_data(d) = begin
	o_fr, o_to = first(d.timestamps), last(d.timestamps)
	if d.exchange !== "binance"
    o, h, l, c, v, t, misses = dwnl_tick_ccxt("$(exchange):$(market):$(isfutures)", start_date, end_date, "tick", d.context.now_ts)
	else
		maket = replace(d.market, "_" => "")
		o, h, l, c, v, t, misses = dwnl_tick_data(maket, d.is_futures, o_fr, o_to)
	end
	extend(d, o, h, l, c, v, t, misses)
	d
end


dwnl_minute_data(market, isfutures, start_date, end_date) = begin
	metric = candle2metric("1m")
	misses = UnitRange{Int}[]
	market_data                = query_klines(replace(market, "_"=>""), "1m", start_date, end_date, isfutures ? Val(:FUTURES) : Val(:SPOT));
	o, h, l, c, v, t           = marketdata2ohlcvt(market_data)
	(o, h, l, c, v), misses, t = interpolate_missing((o, h, l, c, v), t, metric*1000)
	return o, h, l, c, v, t, misses
end

dwnl_tick_data(market, isfutures, start_date, end_date) = begin
	misses = UnitRange{Int}[]
	tick_raw = query_ticks(market, isfutures, start_date, end_date)
	id, t, c, v = tick_raw
	o=[c[1];c[1:end-1]]
	h=max.(o,c)
	l=min.(o,c)
	return o, h, l, c, v, t, misses
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
		# cut_data_tick!(o, c)
		o.o, o.h, o.l, o.c, o.v, o.t = combine_klines_fast_tick(o, o.candle_value, Val(o.candle_type))
	else
		# all_data = refresh_minute_data(o.exchange, o.market, o.is_futures, first(o.timestamps), last(o.timestamps))
		# cut_data_1m!(o, all_data)

		@assert o.candle_value>=60 "We cannot handle things under 1min(60s) d.candle_value=$(o.candle_value)"
		fr     = first(o.timestamps)
		offset = cld(ceil_ts(fr, o.candle_value)-fr,60)
		metric_round = cld(o.candle_value,60)
		# cut_data_1m!(o, c)

		# floor_ts(to, candle_value, ctxt)
		# @display [unix2datetime.(floor.([Int64], o.t ./ 1000)) o.c]
		@assert  all(o.t[2:end] .- o.t[1:end-1] .== 60*1000) "$(o.t[2:end] .- o.t[1:end-1])  ?== $(60*1000)"
		o.o, o.h, o.l, o.c, o.v, o.t = combine_klines_fast(o, metric_round, offset)
		# @display [unix2datetime.(floor.([Int64], o.t ./ 1000)) o.c]
		@assert  all(o.t[2:end] .- o.t[1:end-1] .== o.candle_value*1000) "$(o.t[2:end] .- o.t[1:end-1])  ?== $(o.candle_value*1000)"
	end
