
using Boilerplate

function linear_interpolate!(vec, range, start_val, end_val)
	w_idxs = 1:length(range)
	w = w_idxs / (length(range)+1)
	for (i, idx) in enumerate(range)
		lin_range_value = (1-w[i]) * start_val + w[i] * end_val
		vec[idx] = lin_range_value
	end
end
function interpolate_missing(data::NTuple{5, Vector{T}}, basis, basis_step, method=:linear) where T
	N = (basis[end] - basis[1]) ÷ basis_step + 1
	misses = UnitRange[]
	length(data[1]) == N && return data, misses, basis
	idxs = zeros(Int, length(basis));
	last_pos = 1
	new_data = Tuple(zeros(T, N) for v in data)
	pos = 1
	for (i, ts) in enumerate(basis)
		pos = (ts - basis[1]) ÷ basis_step + 1
		idxs[i] = pos
		@inbounds for (j, v) in enumerate(new_data)
			v[pos] = data[j][i]
			if i>1 && pos - last_pos != 1
				# @show pos - last_pos, last_pos:pos
				linear_interpolate!(v, last_pos+1:pos-1, v[last_pos], v[pos])
				push!(misses, last_pos+1:pos-1)
			end 
		end
		last_pos = pos
	end
	@sizes new_data
	new_data, misses, basis[1]:basis_step:basis[end]
end
function interpolate_missing(data::Matrix{T}, basis::Vector{Int}, basis_step, method=:linear) where T
	N = (basis[end] - basis[1]) ÷ basis_step + 1
	misses = UnitRange[]
	size(data, 1) == N && return data, misses, basis
	idxs = zeros(Int, length(basis));
	last_pos = 1
	new_data = zeros(T, N, 5)
	pos = 1
	for (i, ts) in enumerate(basis)
		pos = (ts - basis[1]) ÷ basis_step + 1
		idxs[i] = pos
    new_data[pos, :] .= data[i, :]
		@inbounds for j in 1:size(new_data,2)
			if i>1 && pos - last_pos != 1
				# @show pos - last_pos, last_pos:pos
				@views linear_interpolate!(view(new_data, :,j), last_pos+1:pos-1, new_data[last_pos, j], new_data[pos, j])
			end 
		end
    pos - last_pos >1 && push!(misses, last_pos+1:pos-1)
		last_pos = pos
	end
	new_data, misses, basis[1]:basis_step:basis[end]
end
# market_req = "binance:BNB_USDT:futures"
# candle = "1h"
# filename = "$(market_req)_OHLCVT_all_$(candle).jld2"
# @load "./data/$filename" OHLCV meta
# @sizes OHLCV
# @sizes meta.timestamps
# OHLCV_new,miss = interpolate(OHLCV, meta.timestamps, meta.metric*1000)
# @show miss
# @sizes OHLCV_new

