


extend(d::T, o, h, l, c, v, OHLCV_time, misses) where T <: CandleType = begin
    d.t      = !isempty(d.t)      ? vcat(d.t,OHLCV_time)  : OHLCV_time
    d.misses = !isempty(d.misses) ? vcat(d.misses,misses) : misses
    d.o,d.h,d.l,d.c,d.v = o, h, l, c, v
end
    
load_new_candle_data(d) = begin
    o_fr, o_to = first(d.timestamps), last(d.timestamps)
    candle = reverse_parse_candle(d)
    o, h, l, c, v, t, misses = dwnl_candle_data(d.market, d.is_futures, o_fr, o_to, candle)
    extend(d, o, h, l, c, v, t, misses)
    d
end

load_new_tick_data(d) = begin
    o_fr, o_to = first(d.timestamps), last(d.timestamps)
    o, h, l, c, v, t, misses = dwnl_tick_data(d.market, d.is_futures, o_fr, o_to)
    extend(d, o, h, l, c, v, t, misses)
    d
end

dwnl_candle_data(market, isfutures, start_date, end_date, candle="1m") = begin
    metric = candle2metric(candle)
    misses = UnitRange{Int}[]
    market_data = query_klines(replace(market, "_"=>""), candle, start_date, end_date, isfutures ? Val(:FUTURES) : Val(:SPOT))
    o, h, l, c, v, t = marketdata2ohlcvt(market_data)
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

dwnl_minute_data(market, isfutures, start_date, end_date) = begin
	metric = candle2metric("1m")
	misses = UnitRange{Int}[]
	market_data                = query_klines(replace(market, "_"=>""), "1m", start_date, end_date, isfutures ? Val(:FUTURES) : Val(:SPOT));
	o, h, l, c, v, t           = marketdata2ohlcvt(market_data)
	(o, h, l, c, v), misses, t = interpolate_missing((o, h, l, c, v), t, metric*1000)
	return o, h, l, c, v, t, misses
end

dwnl_data_ccxt(src, start_date, end_date, candle, ct_now) = @assert false "unimplemented... I need to copy this yet..."
dwnl_tick_ccxt(src, start_date, end_date, candle, ct_now) = @assert false "unimplemented... I need to copy this yet..."

function cut_data_to_day!(ohlcv)
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
postprocess_ohlcv!(o::T, need_cut=false) where T <: CandleType = if o.candle_type in 
		[
			:TICK, 
			:TICK_MMM, :TICK_STONE
		]
		@warn "from and to date isn't supported for tick data!! todo"
		# all_data = refresh_tick_data(  o.exchange, o.market, o.is_futures, first(o.timestamps), last(o.timestamps))
		# cut_data_tick!(o, all_data)
		# cut_data_tick!(o, c)
		(o.o, o.h, o.l, o.c, o.v), o.t = combine_klines_fast_tick(o, o.candle_value, Val(o.candle_type))
	else
		# all_data = refresh_minute_data(o.exchange, o.market, o.is_futures, first(o.timestamps), last(o.timestamps))
		# cut_data_1m!(o, all_data)

		@assert o.candle_value>=60 "We cannot handle things under 1min(60s) d.candle_value=$(o.candle_value)"
		fr     = first(o.timestamps)
		# @show ceil_ts(fr, o.candle_value)-fr
		offset = cld(ceil_ts(fr, o.candle_value*1000)-ceil_ts(fr,60_000),60_000)
		@assert 60_000 == o.t[2]-o.t[1] "We have not tested other cases yet..."
		metric_round = cld(o.candle_value,60)
		# cut_data_1m!(o, c)

		# @display [unix2datetime.(floor.([Int64], o.t ./ 1000)) o.c]
		@assert  all(o.t[2:end] .- o.t[1:end-1] .== 60_000) "$(o.t[2:end] .- o.t[1:end-1])  ?== $(60_000)"
		(o.o, o.h, o.l, o.c, o.v), o.t = combine_klines_fast(o, metric_round, offset)
		need_cut && cut_data_to_day!(o)
		# @display [unix2datetime.(floor.([Int64], o.t ./ 1000)) o.c]
		@assert  all(o.t[2:end] .- o.t[1:end-1] .== o.candle_value*1000) "$(o.t[2:end] .- o.t[1:end-1])  ?== $(o.candle_value*1000)"
	end
+