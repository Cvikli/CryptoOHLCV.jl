


print_file(o::OHLCV)   = println("$(get_filename(o)) train: $(unix2datetime(first(o.timestamps))) -> $(unix2datetime(last(o.timestamps)))")


# ceil_ts( ts, cv, context) = (m =  ts%max(cv, context.maximum_candle_size);  m>0 ? ts-m+max(cv, context.maximum_candle_size) : ts)
# floor_ts(ts, cv, context) = ts - (ts%max(cv, context.maximum_candle_size))
ceil_ts( ts, cv) = (m =  ts%cv;  m>0 ? ts-m+cv : ts)
floor_ts(ts, cv) = ts - (ts%cv)


isfutures_str(isfutures::String) = isfutures=="F" ? true : false
isfutures_str(isfutures::Bool)   = isfutures ? "F" : "N"
isfutures_long(isfutures::Bool)   = isfutures ? ":futures" : ""
candle2metric(candle) = Dict("1m" => 60, "5m" => 300, "15m" => 900, "30m" => 1800, "1s" => 1, "2s" => 2, "15s" => 15, "5s" => 5, "1h" => 3600, "tick"=>0)[candle]
metric2candle(metric) = Dict(60 => "1m", 300 => "5m", 900 => "15m", 1800 => "30m", 1 => "1s", 2 => "2s", 5 => "5s", 15 => "15s", 3600 => "1h", 0=>"tick")[metric]


normalize(meaner::MeanNorm, ohlcv, ) = begin
  new_ohlcv = deepcopy(ohlcv)
  norm!(meaner, new_ohlcv.o)
  norm!(meaner, new_ohlcv.h)
  norm!(meaner, new_ohlcv.l)
  norm!(meaner, new_ohlcv.c)
  new_ohlcv
end
normalize(ohlcv::OHLCV) = begin
  normer = MeanNorm(sum(ohlcv.c)/length(ohlcv.c))
  normalize(normer, ohlcv)
end
normalize(ohlcv::OHLCV, ohlcv_v) = begin
  mean = (sum(ohlcv.c)+sum(ohlcv_v.c)) ./ (length(ohlcv.c)+length(ohlcv_v.c))
  normer = MeanNorm(mean)
  normalize(normer, ohlcv), normalize(normer, ohlcv_v), normer
end
unnormalize(ohlcv,meaner::MeanNorm) = begin
  new_ohlcv = deepcopy(ohlcv)
  denorm!(meaner, new_ohlcv.o)
  denorm!(meaner, new_ohlcv.h)
  denorm!(meaner, new_ohlcv.l)
  denorm!(meaner, new_ohlcv.c)
  new_ohlcv
end




combine_klines!(o,h,l,c,v,t, fr::Int, to::Int) = begin
  high, low, vol = h[fr], l[fr], v[fr]
  for i in fr+1:to
    high < h[i] && (high = h[i])
    low  > l[i] && (low  = l[i])
    vol += v[i]
  end
  o[fr], high, low, c[to], vol, t[fr]
end
combine_klines_fast(ohlcv, window, offset=0) = begin
	o,h,l,c,v,t = ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.t
  window == 1 && return o,h,l,c,v,t
  inds = 1+offset:window:size(o, 1) - window + 1
  new_o  = Vector{eltype(o)}(undef, length(inds))
  new_h  = Vector{eltype(o)}(undef, length(inds))
  new_l  = Vector{eltype(o)}(undef, length(inds))
  new_c  = Vector{eltype(o)}(undef, length(inds))
  new_v  = Vector{eltype(o)}(undef, length(inds))
  new_ts = Vector{eltype(t)}(undef, length(inds))
  for (j, i) in enumerate(inds)
    new_o[j],new_h[j],new_l[j],new_c[j],new_v[j],new_ts[j] = combine_klines!(o,h,l,c,v,t, i, i+window-1)
  end
  new_o, new_h, new_l, new_c, new_v, new_ts
end
combine_klines_fast_tick(ohlcv, window, ::Val{:TICK}, offset=0) = begin
	o,h,l,c,v,t = ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.t
  window == 1 && return o,h,l,c,v,t
	max_len = length(o)
	ass_len = cld(length(o), window)
  new_o  = Vector{eltype(o)}(undef, ass_len)
  new_h  = Vector{eltype(o)}(undef, ass_len)
  new_l  = Vector{eltype(o)}(undef, ass_len)
  new_c  = Vector{eltype(o)}(undef, ass_len)
  new_v  = Vector{eltype(o)}(undef, ass_len)
  new_ts = Vector{eltype(t)}(undef, ass_len)
	i = 2
	j = 0
	while i < max_len
		j+=1
		bi = 1
		new_o[j] = o[i]
		high, low, vol = h[i], l[i], v[i]
		while bi <= window
			high < h[i] && (high = h[i])
			low  > l[i] && (low  = l[i])
			vol += v[i]
			i+=1
			bi+= 1
		end
    new_h[j],new_l[j],new_c[j],new_v[j],new_ts[j] = high, low, c[i-1], vol, t[i-1]
  end
  new_o[1:j], new_h[1:j], new_l[1:j], new_c[1:j], new_v[1:j], new_ts[1:j]
end










