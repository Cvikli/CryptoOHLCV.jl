



UniversalStruct.need_data_before(o::T, c::T)  where T <: CandleType = first(o.timestamps) < first(c.timestamps)
UniversalStruct.need_data_after(o::T,  c::T)  where T <: CandleType = last(c.timestamps)  < last(o.timestamps)

UniversalStruct.init_before_data(o::T, c::T)  where T <: CandleType = UniversalStruct.init(T, get_source(o.exchange, o.market, o.is_futures), reverse_parse_candle(o.candle_type, o.candle_value), first(o.timestamps), first(c.timestamps))
UniversalStruct.init_after_data(o::T,  c::T)  where T <: CandleType = UniversalStruct.init(T, get_source(o.exchange, o.market, o.is_futures), reverse_parse_candle(o.candle_type, o.candle_value), last(c.timestamps),  last(o.timestamps))


UniversalStruct.append(o::T, c::T)            where T <: CandleType = begin 
	o.ts = vcat(o.ts,c.ts) # TODO... this seems bad!!
	o.o  = vcat(o.o, c.o)
	o.h  = vcat(o.h, c.h)
	o.l  = vcat(o.l, c.l)
	o.c  = vcat(o.c, c.c)
	o.v  = vcat(o.v, c.v)
	o.timestamps = first(o.timestamps):last(c.timestamps)
	return o
end

UniversalStruct.cut_requested!(o::T, c::T)    where T <: CandleType = return if o.candle_type in [:SECOND,:MINUTE,:HOUR,:DAY]
	cut_data_1m!(o, c)
else
	cut_data_tick!(o, c)
end
cut_data_tick!(o, c) = begin
	o_fr, o_to = first(o.timestamps)*1000, last(o.timestamps)*1000
	offset = 1
	endset = length(c.ts)
	while c.ts[offset] < o_fr && offset < endset
		offset+=1; end
	while c.ts[endset] > o_to && endset > offset-1
		endset-=1; end
	
	o.ts = c.ts[offset:endset]
	o.o  = c.o[offset:endset]
	o.h  = c.h[offset:endset]
	o.l  = c.l[offset:endset]
	o.c  = c.c[offset:endset]
	o.v  = c.v[offset:endset]
	o
end
cut_data_1m!(o, c) = begin
	min_candle_value = 60
	o_fr, o_to = first(o.timestamps), last(o.timestamps)
	c_fr       = first(c.timestamps)

	offset = cld(o_fr - c_fr, min_candle_value)
	endset = cld(o_to - c_fr, min_candle_value)
	@assert endset-1<=length(c.h) "how can this be bigger?? $(endset-1), $(length(c.h))"
	
	o.ts = c.ts[1+offset:endset]
	o.o  = c.o[1+offset:endset]
	o.h  = c.h[1+offset:endset]
	o.l  = c.l[1+offset:endset]
	o.c  = c.c[1+offset:endset]
	o.v  = c.v[1+offset:endset]
	o
end


