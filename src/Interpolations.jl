
using BoilerplateCvikli

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
	last_pos = 1
	new_data = Tuple(zeros(T, N) for v in data)
	pos = 1
	for (i, ts) in enumerate(basis)
		pos = (ts - basis[1]) ÷ basis_step + 1
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
	@sizes new_data, misses
	new_data, misses, basis[1]:basis_step:basis[end]
end
function interpolate_missing(data::Matrix{T}, basis::Vector{Int}, basis_step, method=:linear) where T
	N = (basis[end] - basis[1]) ÷ basis_step + 1
	misses = UnitRange[]
	size(data, 1) == N && return data, misses, basis
	last_pos = 1
	new_data = zeros(T, N, 5)
	pos = 1
	for (i, ts) in enumerate(basis)
		pos = (ts - basis[1]) ÷ basis_step + 1
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



