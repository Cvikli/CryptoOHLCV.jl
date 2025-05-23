

init(TYPE::Type{T}, set, exchange, market, is_futures, candle_type, candle_value, fr, to) where T <: CandleType = begin
	@assert datetime2unix(now(UTC))*1000 + 1000 > to "We want to query data from the future... please be careful: NOW: $(now(UTC)) TO: $(unix2datetime(to ÷ 1000))" 
	@assert fr < to "Wrong dates: from $fr to $to is wrong as it is: $(to-fr) time"
	TYPE(timestamps = fr:to
			;set, exchange, market, is_futures, candle_type, candle_value,
	)
end

load(obj::T)                           where T <: CandleType        = begin # we could pass args and kw_args too...
	c = load_disk(obj)
	c, needsave = !isa(c, Nothing) ? extend!(obj,c) : (load_data!(obj), true)
	needsave && save_disk(c, need_clean=!isa(c, Nothing))
	trim_to_requested_range!(obj, c)
end

load_data!(o::T) where T <: CandleType = o.candle_type in [ :TICK, :TICK_MMM, :TICK_STONE ] ? load_new_tick_data(o) : load_new_minute_data(o)
	
load_new_minute_data(d) = begin
	o_fr, o_to = first(d.timestamps), last(d.timestamps)
	o, h, l, c, v, t, misses = dwnl_minute_binance(d.market, d.is_futures, o_fr, o_to)
	d.t, d.o,d.h,d.l,d.c,d.v, d.misses = o, h, l, c, v, t, misses
	d
end
load_new_tick_data(d) = begin
	o_fr, o_to = first(d.timestamps), last(d.timestamps)
	o, h, l, c, v, t, misses = dwnl_tick_binance(d.market, d.is_futures, o_fr, o_to)
	d.t, d.o,d.h,d.l,d.c,d.v, d.misses = o, h, l, c, v, t, misses
	d
end

dwnl_minute_binance(market, isfutures, start_date, end_date) = begin
	metric = candle2metric("1m")
	misses = UnitRange{Int}[]
	market_data                = query_klines(replace(market, "_"=>""), "1m", start_date, end_date, isfutures ? Val(:FUTURES) : Val(:SPOT));
	o, h, l, c, v, t           = marketdata2ohlcvt(market_data)
	(o, h, l, c, v), misses, t = interpolate_missing((o, h, l, c, v), t, metric*1000)
	return o, h, l, c, v, t, misses
end

dwnl_tick_binance(market, isfutures, start_date, end_date) = begin
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

function trim_data_to_day!(ohlcv)
  ts = ohlcv.t
  metric = (ts[2] - ts[1]) ÷ 1000
	date = unix2datetime(ts[1] ÷ 1000)
  year, month, day = Dates.year(date), Dates.month(date), Dates.day(date)
  next_day_start = DateTime(year, month, day)
	if Dates.datetime2unix(next_day_start) != ts[1] ÷ 1000
		next_day_start += Day(1)
	end
	next_day_start_unix = Dates.datetime2unix(next_day_start)
  cut_size = Int(ceil((next_day_start_unix*1000 - ts[1]) / (metric*1000))) + 1
	ohlcv.o, ohlcv.h, ohlcv.l, ohlcv.c, ohlcv.v, ohlcv.t = ohlcv.o[cut_size:end], ohlcv.h[cut_size:end], ohlcv.l[cut_size:end], ohlcv.c[cut_size:end], ohlcv.v[cut_size:end], ohlcv.t[cut_size:end] 
end

postprocess_ohlcv!(o::T; trim_to_date=false) where T <: CandleType = if o.candle_type in 
		[
			:TICK, 
			:TICK_MMM, :TICK_STONE
		]
		@warn "from and to date isn't supported for tick data!! todo"
		# all_data = refresh_tick_data(  o.exchange, o.market, o.is_futures, first(o.timestamps), last(o.timestamps))
		# trim_tick_data!(o, all_data)
		# trim_tick_data!(o, c)
		(o.o, o.h, o.l, o.c, o.v), o.t = combine_klines_fast_tick(o, o.candle_value, Val(o.candle_type))
	else
		# all_data = refresh_minute_data(o.exchange, o.market, o.is_futures, first(o.timestamps), last(o.timestamps))
		# trim_1m_data!(o, all_data)

		@assert o.candle_value>=60 "We cannot handle things under 1min(60s) d.candle_value=$(o.candle_value)"
		fr     = first(o.timestamps)
		# @show ceil_ts(fr, o.candle_value)-fr
		offset = cld(ceil_ts(fr, o.candle_value*1000)-ceil_ts(fr,60_000),60_000)
		@assert 60_000 == o.t[2]-o.t[1] "We have not tested other cases yet..."
		metric_round = cld(o.candle_value,60)
		# trim_1m_data!(o, c)

		# @display [unix2datetime.(floor.([Int64], o.t ./ 1000)) o.c]
		@assert  all(o.t[2:end] .- o.t[1:end-1] .== 60_000) "$(o.t[2:end] .- o.t[1:end-1])  ?== $(60_000)"
		(o.o, o.h, o.l, o.c, o.v), o.t = combine_klines_fast(o, metric_round, offset)
		trim_to_date && trim_data_to_day!(o)
		# @display [unix2datetime.(floor.([Int64], o.t ./ 1000)) o.c]
		@assert  all(o.t[2:end] .- o.t[1:end-1] .== o.candle_value*1000) "$(o.t[2:end] .- o.t[1:end-1])  ?== $(o.candle_value*1000)"
	end
+	