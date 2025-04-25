
extend!(obj,c_obj)                           = merge(request_data_beforehand(obj, c_obj), c_obj, request_data_afterhand(c_obj, obj))
merge(before,         cached,after)          = append!(append!(before,cached),after), true
merge(before::Nothing,cached,after)          = append!(cached,after), true
merge(before,         cached,after::Nothing) = append!(before,cached), true
merge(before::Nothing,cached,after::Nothing) = cached, false


######### Optionalble Redefineable Interfaces
append!(before,          after::Nothing)  = before 
append!(before::Nothing, after)           = after
append!(o::T, c::T) where T <: CandleType = begin 
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

request_data_beforehand(obj, c) = missing_data_before(obj,c) ? load_data!(init_before_data(obj,c)) : nothing
request_data_afterhand(c,  obj) = missing_data_after(obj,c)  ? load_data!(init_after_data(obj,c))  : nothing


missing_data_before(o::T1, c::T2)  where {T1 <: CandleType, T2 <: CandleType} = first(o.timestamps) < first(c.timestamps)
missing_data_after(o::T1,  c::T2)  where {T1 <: CandleType, T2 <: CandleType} = last(c.timestamps)  < last(o.timestamps)

init_before_data(o::T1, c::T2)  where {T1 <: CandleType, T2 <: CandleType} = init(T1, o.set, o.exchange, o.market, o.is_futures, o.candle_type, o.candle_value, first(o.timestamps), first(c.timestamps))
init_after_data(o::T1,  c::T2)  where {T1 <: CandleType, T2 <: CandleType} = init(T2, o.set, o.exchange, o.market, o.is_futures, o.candle_type, o.candle_value, last(c.timestamps),  last(o.timestamps))


trim_to_requested_range!(o::T1, c::T2)    where {T1 <: CandleType, T2 <: CandleType} = return if o.candle_type in [:SECOND,:MINUTE,:HOUR,:DAY]
	trim_1m_data!(o, c)
else
	trim_tick_data!(o, c)
end

trim_1m_data!(o, c) = begin
	o_fr, o_to = first(o.timestamps), last(o.timestamps)
	c_fr       = c.t[1] # first(c.timestamps)

	offset = 1 + cld(o_fr - c_fr, ctx.min_candle_value)
	endset = cld(o_to - o_to % ctx.min_candle_value - c_fr, ctx.min_candle_value)
	@assert endset<=length(c.h) "how can this be bigger?? $(endset), $(length(c.h))"
	
	o.t = c.t[offset:endset]
	o.o = c.o[offset:endset]
	o.h = c.h[offset:endset]
	o.l = c.l[offset:endset]
	o.c = c.c[offset:endset]
	o.v = c.v[offset:endset]
	o
end

trim_tick_data!(o, c) = begin
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

