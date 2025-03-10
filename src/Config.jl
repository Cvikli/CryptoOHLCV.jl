


set_day_range!(ctx; dayframe=0:42) = ctx.timestamps= ts2Δday(last(dayframe)):ts2Δday(first(dayframe))

ts2Δday(ts)    = (Day(unix2datetime(ctx.now_ts)) - Day(unix2datetime(ts/1000))).value
Δday2ts(day)   = cld(ctx.now_ts-day*60*60*24*1000, 60*60*24*1000) * 60*60*24 * 1000
# Δday2date(day) = (global ctx; unix2datetime(ctx.now_ts/1000-day*60*60*24))




