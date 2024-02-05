
using Dates
d2u(v::DateTime) = floor(Int,datetime2unix(v))
u2d(v::Int)      = v > 20_000_000_000 ? unix2datetime(v/1000) : unix2datetime(v)

date_range(fr_ts, to_ts) = u2d(fr_ts), u2d(to_ts)           

