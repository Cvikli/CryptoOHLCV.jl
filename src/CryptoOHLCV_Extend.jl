


extend!(obj,c_obj)                           = merge(data_before(obj, c_obj), c_obj, data_after(c_obj, obj))
merge(before,         cached,after)          = append!(append!(before,cached),after), true
merge(before::Nothing,cached,after)          = append!(cached,after), true
merge(before,         cached,after::Nothing) = append!(before,cached), true
merge(before::Nothing,cached,after::Nothing) = cached, false


######### Optionalble Redefineable Interfaces
append!(before,          after::Nothing) = before 
append!(before::Nothing, after)          = after

data_before(obj, c)         = need_data_before(obj,c) ? load_data!(init_before_data(obj,c)) : nothing
data_after(c,  obj)         = need_data_after(obj,c)  ? load_data!(init_after_data(obj,c))  : nothing


need_data_before(o::T1, c::T2)  where {T1 <: CandleType, T2 <: CandleType} = first(o.timestamps) < first(c.timestamps)
need_data_after(o::T1,  c::T2)  where {T1 <: CandleType, T2 <: CandleType} = last(c.timestamps)  < last(o.timestamps)

init_before_data(o::T1, c::T2)  where {T1 <: CandleType, T2 <: CandleType} = init(T1, o.set, o.exchange, o.market, o.is_futures, o.candle_type, o.candle_value, first(o.timestamps), first(c.timestamps))
init_after_data(o::T1,  c::T2)  where {T1 <: CandleType, T2 <: CandleType} = init(T2, o.set, o.exchange, o.market, o.is_futures, o.candle_type, o.candle_value, last(c.timestamps),  last(o.timestamps))


append!(o::T1, c::T2)                where {T1 <: CandleType, T2 <: CandleType} = begin 
	if o.t[end]==c.t[1]
		o.t = vcat(o.t[1:end-1], c.t)
		o.o = vcat(o.o[1:end-1], c.o)
		o.h = vcat(o.h[1:end-1], c.h)
		o.l = vcat(o.l[1:end-1], c.l)
		o.c = vcat(o.c[1:end-1], c.c)
		o.v = vcat(o.v[1:end-1], c.v)
	else
		o.t = vcat(o.t, c.t) # TODO... this seems bad!!
		o.o = vcat(o.o, c.o)
		o.h = vcat(o.h, c.h)
		o.l = vcat(o.l, c.l)
		o.c = vcat(o.c, c.c)
		o.v = vcat(o.v, c.v)
	end
	o.timestamps = first(o.timestamps):last(c.timestamps)
	return o
end

cut_requested!(o::T1, c::T2)    where {T1 <: CandleType, T2 <: CandleType} = return if o.candle_type in [:SECOND,:MINUTE,:HOUR,:DAY]
	cut_data_1m!(o, c)
else
	cut_data_tick!(o, c)
end

cut_data_1m!(o, c) = begin
	min_candle_value = 60_000
	o_fr, o_to = first(o.timestamps), last(o.timestamps)
	c_fr       = c.t[1] # first(c.timestamps)

	offset = cld(o_fr - c_fr, min_candle_value)
	endset = cld(o_to - o_to%min_candle_value - c_fr, min_candle_value)
	# @show first(c.timestamps)%min_candle_value
	# @show o.timestamps
	# @show c.timestamps
	# @show -(c_fr-o_to)/min_candle_value
	# @show c.t[end-30:end]
	# @display unix2datetime.(c.t[end-7:end]./1000)
	# @show (c.t[1])
	# @show (c.t[offset])
	# @show (c.t[end])
	# @show (1640619660-c_fr)
	# @show (c.t[offset])
	# @show (c.t[end])
	# @show unix2datetime(c_fr)
	# @show unix2datetime(o_fr)
	# @show unix2datetime(o_to)
	# @show unix2datetime(c.t[1]./1000)
	# @show unix2datetime(c.t[1+offset]./1000)
	# @show unix2datetime(c.t[endset]./1000)
	# @show unix2datetime(c.t[end]./1000)
	# @show all(c.t[2:end].- c.t[1:end-1].==60000)
	# @show o.t
	# @show offset.-1149500
	# @show endset.-1149500
	# @show (endset-offset)./60
	@assert endset<=length(c.h) "how can this be bigger?? $(endset), $(length(c.h))"
	
	o.t = c.t[1+offset:endset]
	o.o = c.o[1+offset:endset]
	o.h = c.h[1+offset:endset]
	o.l = c.l[1+offset:endset]
	o.c = c.c[1+offset:endset]
	o.v = c.v[1+offset:endset]
	o
end

cut_data_tick!(o, c) = begin
	o_fr, o_to = first(o.timestamps), last(o.timestamps)
	offset = 1
	endset = length(c.t)
	while c.t[offset] < o_fr && offset < endset
		offset+=1; end
	while c.t[endset] > o_to && endset > offset-1
		endset-=1; end
	
	o.t = c.t[offset:endset]
	o.o = c.o[offset:endset]
	o.h = c.h[offset:endset]
	o.l = c.l[offset:endset]
	o.c = c.c[offset:endset]
	o.v = c.v[offset:endset]
	o
end

