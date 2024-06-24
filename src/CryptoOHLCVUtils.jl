


print_file(o::OHLCV)   = println("$(get_filename(o)) train: $(unix2datetime(first(o.timestamps))) -> $(unix2datetime(last(o.timestamps)))")


# ceil_ts( ts, cv, context) = (m =  ts%max(cv, context.maximum_candle_size);  m>0 ? ts-m+max(cv, context.maximum_candle_size) : ts)
# floor_ts(ts, cv, context) = ts - (ts%max(cv, context.maximum_candle_size))
ceil_ts( ts, cv) = (m =  ts%cv;  m>0 ? ts-m+cv : ts)
floor_ts(ts, cv) = ts - (ts%cv)


isfutures_str(isfutures::String)  = isfutures=="F" ? true       : false
isfutures_str(isfutures::Bool)    = isfutures      ? "F"        : "S"
isfutures_long(isfutures::Bool)   = isfutures      ? ":futures" : "spot"
candle2metric(candle) = Dict("1m" => 60, "5m" => 300, "15m" => 900, "30m" => 1800, "1s" => 1, "2s" => 2, "15s" => 15, "5s" => 5, "1h" => 3600, "4h" => 3600*4, "tick"=>0)[candle]
metric2candle(type, metric) = type == :TICK ? "$metric" : Dict(60 => "1m", 300 => "5m", 900 => "15m", 1800 => "30m", 1 => "1s", 2 => "2s", 5 => "5s", 15 => "15s", 3600 => "1h", 3600*4 => "4h", 0=>"tick")[metric]


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
unnormalize(meaner::MeanNorm, ohlcv,) = begin
  new_ohlcv = deepcopy(ohlcv)
  denorm!(meaner, new_ohlcv.o)
  denorm!(meaner, new_ohlcv.h)
  denorm!(meaner, new_ohlcv.l)
  denorm!(meaner, new_ohlcv.c)
  new_ohlcv
end

function combine_klines!(arr::Array, idx::Int, ohlcv::Array, from::Int, to::Int)
  high, low, vol = ohlcv[from,HIGH], ohlcv[from,LOW], ohlcv[from,VOLUME]
  for i in from+1:to
    high < ohlcv[i, HIGH] && (high = ohlcv[i, HIGH])
    low  > ohlcv[i, LOW]  && (low  = ohlcv[i, LOW])
    vol += ohlcv[i, VOLUME]
  end
  arr[idx,:] .= (ohlcv[from,OPEN], high, low, ohlcv[to,CLOSE], vol)
  nothing
end
function combine_klines!(arr::NTuple{5,Vector}, idx::Int, ohlcv::NTuple{5,Vector}, from::Int, to::Int)
  OPEN, HIGH, LOW, CLOSE, VOLUME = 1,2,3,4,5
  high, low, vol = ohlcv[HIGH][from], ohlcv[LOW][from], ohlcv[VOLUME][from]
  for i in from+1:to
    high < ohlcv[HIGH][i] && (high = ohlcv[HIGH][i])
    low  > ohlcv[LOW][i]  && (low  = ohlcv[LOW][i])
    vol += ohlcv[VOLUME][i]
  end
  arr[OPEN][idx], arr[HIGH][idx], arr[LOW][idx] = ohlcv[OPEN][from], high, low
  arr[CLOSE][idx] = ohlcv[CLOSE][to]
  arr[VOLUME][idx] = vol
  nothing
end
function combine_klines(o,h,l,c,v,t, fr::Int, to::Int)
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
  window == 1 && return (o,h,l,c,v),t
  inds = 1+offset:window:size(o, 1) - window + 1
  new_o  = Vector{eltype(o)}(undef, length(inds))
  new_h  = Vector{eltype(o)}(undef, length(inds))
  new_l  = Vector{eltype(o)}(undef, length(inds))
  new_c  = Vector{eltype(o)}(undef, length(inds))
  new_v  = Vector{eltype(o)}(undef, length(inds))
  new_ts = Vector{eltype(t)}(undef, length(inds))
  for (j, i) in enumerate(inds)
    new_o[j],new_h[j],new_l[j],new_c[j],new_v[j],new_ts[j] = combine_klines(o,h,l,c,v,t, i, i+window-1)
  end
  (new_o, new_h, new_l, new_c, new_v), new_ts
end
function combine_klines_fast(ohlcv::Tuple{Vector{T}, Vector{T}, Vector{T}, Vector{T}, Vector{T}, Vector{T2}}, window, offset=0) where {T, T2}
  window == 1 && return ohlcv[1:5], ohlcv[6]
  inds = 1+offset:window:length(ohlcv[1]) - window + 1
  ohlcv_no_time = ohlcv[1:5]
  new_ohlcv::NTuple{5,Vector{T}} = Tuple(zeros(T, length(inds)) for _ in 1:5)
  for (j, i) in enumerate(inds)
    combine_klines!(new_ohlcv, j, ohlcv_no_time, i, i+window-1)
  end
  new_ohlcv, ohlcv[6][inds]
end
function combine_klines_fast(ohlcv::Array, window, offset=0)
  window == 1 && return ohlcv
  inds = 1+offset:window:size(ohlcv, 1) - window + 1
  new_ohlcv = zeros(eltype(ohlcv), length(inds), 5)
  for (j, i) in enumerate(inds)
    combine_klines!(new_ohlcv, j, ohlcv, i, i+window-1)
  end
  new_ohlcv
end
function combine_klines_fast(ohlcv::NTuple{5,Vector{T}}, window, offset=0) where T
  window == 1 && return ohlcv
  inds = 1+offset:window:length(ohlcv[1]) - window + 1
  new_ohlcv::NTuple{5,Vector{T}} = Tuple(zeros(T, length(inds)) for _ in 1:5)
  for (j, i) in enumerate(inds)
    combine_klines!(new_ohlcv, j, ohlcv, i, i+window-1)
  end
  new_ohlcv
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
	i = 1
	j = 0
	while i+window < max_len
		j+=1
		new_o[j] = o[i]
		high, low, vol = h[i], l[i], v[i]
		bi = i + window
		while i < bi
			i+=1
			high < h[i] && (high = h[i])
			low  > l[i] && (low  = l[i])
			vol += v[i]
		end
    new_h[j],new_l[j],new_c[j],new_v[j],new_ts[j] = high, low, c[i-1], vol, t[i-1]
  end
  (new_o[1:j], new_h[1:j], new_l[1:j], new_c[1:j], new_v[1:j]), new_ts[1:j]
end

# a candle combiner which starts every candle on year start.
function combine_klines_big(ohlcvt::Tuple, repetition, offset=0) 
  repetition == 1 && return ohlcvt
  o,h,l,c,v,ts = ohlcvt
  year = Dates.year(unix2datetime(ts[1] ÷ 1000))
  year_start_unix = Dates.datetime2unix(DateTime(year, 1, 1))
  metric = (ts[2] - ts[1]) ÷ 1000
  start_year_unix = Int64(year_start_unix)*1000
  year_start_break_size = ceil((ts[1] - start_year_unix) / (metric*1000))
  year_start_initial_idx::Int = repetition - Int(year_start_break_size % repetition)
  # @assert year_start_initial_idx > 1 "Still the case when it is 0 or 1 things are not tested!"
  inds, new_ts = [1,],[ts[1]]
  if year_start_initial_idx > 1
    push!(inds, year_start_initial_idx)
    push!(new_ts, ts[year_start_initial_idx])
  end
  for (i, t) in enumerate(ts)
    i <= year_start_initial_idx && continue
    if year != Dates.year(unix2datetime(t ÷ 1000))
      year = Dates.year(unix2datetime(t ÷ 1000))
      year_start_unix = Dates.datetime2unix(DateTime(year, 1, 1))
      push!(inds, i)
      push!(new_ts, t)
    elseif inds[end] + repetition == i
      push!(inds, i)
      push!(new_ts, t)
    end

  end
  # inds = 1+offset:repetition:length(ohlcv[1]) - repetition + 1
  new_ohlcv = Tuple(zeros(eltype(o), length(inds)) for _ in 1:5)
  for (j, i) in enumerate(inds) # assigning upsampled candles into new_ohlcv (on index j) 
    endidx = j == length(inds) ? length(o) : inds[j+1]
    endidx <i+1 && continue
    combine_klines!(new_ohlcv, j, (o,h,l,c,v), i+1, endidx)
  end
  new_ohlcv, new_ts, inds
end









