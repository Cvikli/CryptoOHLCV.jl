
combine_klines!(o,h,l,c,v,ts, fr::Int, to::Int) = begin
  high, low, vol = h[fr], l[fr], v[fr]
  for i in fr+1:to
    high < h[i] && (high = h[i])
    low  > l[i] && (low  = l[i])
    vol += v[i]
  end
  o[fr], high, low, c[to], vol, ts[to]
end
combine_klines_fast(ohlcv, window, offset=0) = begin
	o,h,l,c,v,ts = ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.ts
  window == 1 && return o,h,l,c,v,ts
  inds = 1+offset:window:size(o, 1) - window + 1
  new_o  = Vector{eltype(o )}(undef, length(inds))
  new_h  = Vector{eltype(o )}(undef, length(inds))
  new_l  = Vector{eltype(o )}(undef, length(inds))
  new_c  = Vector{eltype(o )}(undef, length(inds))
  new_v  = Vector{eltype(o )}(undef, length(inds))
  new_ts = Vector{eltype(ts)}(undef, length(inds))
  for (j, i) in enumerate(inds)
    new_o[j],new_h[j],new_l[j],new_c[j],new_v[j],new_ts[j] = combine_klines!(o,h,l,c,v,ts, i, i+window-1)
  end
  new_o, new_h, new_l, new_c, new_v, new_ts
end
combine_klines_fast_tick(ohlcv, window, ::Val{:TICK}, offset=0) = begin
	o,h,l,c,v,ts = ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.ts
  window == 1 && return o,h,l,c,v,ts
	max_len = length(o)
	ass_len = cld(length(o), window)
  new_o  = Vector{eltype(o )}(undef, ass_len)
  new_h  = Vector{eltype(o )}(undef, ass_len)
  new_l  = Vector{eltype(o )}(undef, ass_len)
  new_c  = Vector{eltype(o )}(undef, ass_len)
  new_v  = Vector{eltype(o )}(undef, ass_len)
  new_ts = Vector{eltype(ts)}(undef, ass_len)
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
    new_h[j],new_l[j],new_c[j],new_v[j],new_ts[j] = high, low, c[i-1], vol, ts[i-1]
  end
  new_o[1:j], new_h[1:j], new_l[1:j], new_c[1:j], new_v[1:j], new_ts[1:j]
end

norm_data!(ohlcv,avg) = begin
  ohlcv.o ./= avg
  ohlcv.h ./= avg
  ohlcv.l ./= avg
  ohlcv.c ./= avg
end
function normalize!(ohlcv, ohlcv_v)
  avg = (sum(ohlcv.c)+sum(ohlcv_v.c)) ./ (length(ohlcv.c)+length(ohlcv_v.c))
  norm_data!(ohlcv, avg), norm_data!(ohlcv_v, avg)
  avg
end









