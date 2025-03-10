using CryptoOHLCV
using Test
using Dates
using Statistics

"""
    test_ohlcv_integrity(ohlcv::OHLCV; verbose=true)

Run a comprehensive set of integrity tests on OHLCV data.
Returns a named tuple with test results and any issues found.
"""
function test_ohlcv_integrity(ohlcv::OHLCV; verbose=true)
    issues = Dict{Symbol, Vector{Any}}()
    
    # Initialize issue trackers
    issues[:high_below_low] = []
    issues[:open_outside_range] = []
    issues[:close_outside_range] = []
    issues[:negative_values] = []
    issues[:zero_volume] = []
    issues[:timestamp_gaps] = []
    issues[:timestamp_duplicates] = []
    issues[:price_jumps] = []
    
    # Skip empty data
    if isempty(ohlcv.t)
        verbose && println("Empty OHLCV data, skipping tests")
        return (passed=false, issues=issues)
    end
    
    # Get expected time interval
    if length(ohlcv.t) >= 2
        expected_interval = ohlcv.t[2] - ohlcv.t[1]
    else
        # Default to the timeframe from config
        candle = ohlcv.config.timeframe
        if startswith(candle, "tick")
            expected_interval = 0  # Ticks don't have a fixed interval
        else
            expected_interval = candle2metric(candle) * 1000
        end
    end
    
    # Test 1: Check high >= low for all candles
    high_low_valid = all(ohlcv.h .>= ohlcv.l)
    if !high_low_valid
        for i in findall(ohlcv.h .< ohlcv.l)
            push!(issues[:high_below_low], (
                index=i, 
                time=unix2datetime(ohlcv.t[i] ÷ 1000), 
                high=ohlcv.h[i], 
                low=ohlcv.l[i]
            ))
        end
    end
    
    # Test 2: Check open is between high and low
    open_valid = all(ohlcv.o .<= ohlcv.h) && all(ohlcv.o .>= ohlcv.l)
    if !open_valid
        for i in findall((ohlcv.o .> ohlcv.h) .| (ohlcv.o .< ohlcv.l))
            push!(issues[:open_outside_range], (
                index=i, 
                time=unix2datetime(ohlcv.t[i] ÷ 1000), 
                open=ohlcv.o[i], 
                high=ohlcv.h[i], 
                low=ohlcv.l[i]
            ))
        end
    end
    
    # Test 3: Check close is between high and low
    close_valid = all(ohlcv.c .<= ohlcv.h) && all(ohlcv.c .>= ohlcv.l)
    if !close_valid
        for i in findall((ohlcv.c .> ohlcv.h) .| (ohlcv.c .< ohlcv.l))
            push!(issues[:close_outside_range], (
                index=i, 
                time=unix2datetime(ohlcv.t[i] ÷ 1000), 
                close=ohlcv.c[i], 
                high=ohlcv.h[i], 
                low=ohlcv.l[i]
            ))
        end
    end
    
    # Test 4: Check for negative values
    negative_values = any(ohlcv.o .< 0) || any(ohlcv.h .< 0) || any(ohlcv.l .< 0) || any(ohlcv.c .< 0) || any(ohlcv.v .< 0)
    if negative_values
        for i in 1:length(ohlcv.t)
            if ohlcv.o[i] < 0 || ohlcv.h[i] < 0 || ohlcv.l[i] < 0 || ohlcv.c[i] < 0 || ohlcv.v[i] < 0
                push!(issues[:negative_values], (
                    index=i, 
                    time=unix2datetime(ohlcv.t[i] ÷ 1000), 
                    open=ohlcv.o[i], 
                    high=ohlcv.h[i], 
                    low=ohlcv.l[i], 
                    close=ohlcv.c[i], 
                    volume=ohlcv.v[i]
                ))
            end
        end
    end
    
    # Test 5: Check for zero volume (might be valid in some cases but suspicious)
    zero_volume = any(ohlcv.v .== 0)
    if zero_volume
        for i in findall(ohlcv.v .== 0)
            push!(issues[:zero_volume], (
                index=i, 
                time=unix2datetime(ohlcv.t[i] ÷ 1000)
            ))
        end
    end
    
    # Test 6: Check for timestamp gaps
    timestamp_gaps = false
    if expected_interval > 0 && length(ohlcv.t) > 1
        for i in 2:length(ohlcv.t)
            interval = ohlcv.t[i] - ohlcv.t[i-1]
            if interval != expected_interval
                timestamp_gaps = true
                push!(issues[:timestamp_gaps], (
                    index=i, 
                    previous_time=unix2datetime(ohlcv.t[i-1] ÷ 1000),
                    current_time=unix2datetime(ohlcv.t[i] ÷ 1000),
                    gap=interval ÷ 1000,  # in seconds
                    expected=expected_interval ÷ 1000  # in seconds
                ))
            end
        end
    end
    
    # Test 7: Check for duplicate timestamps
    timestamp_duplicates = length(unique(ohlcv.t)) != length(ohlcv.t)
    if timestamp_duplicates
        # Find duplicates
        counts = Dict{Int, Int}()
        for ts in ohlcv.t
            counts[ts] = get(counts, ts, 0) + 1
        end
        
        for (ts, count) in counts
            if count > 1
                push!(issues[:timestamp_duplicates], (
                    time=unix2datetime(ts ÷ 1000),
                    count=count
                ))
            end
        end
    end
    
    # Test 8: Check for suspicious price jumps (>40% for hourly data)
    price_jumps = false
    if length(ohlcv.c) > 1
        # Adjust threshold based on timeframe
        threshold = if startswith(ohlcv.config.timeframe, "1h")
            0.40  # 40% for hourly
        elseif startswith(ohlcv.config.timeframe, "1d")
            0.60  # 60% for daily
        elseif startswith(ohlcv.config.timeframe, "1m")
            0.20  # 20% for minute
        else
            0.30  # Default
        end
        
        for i in 2:length(ohlcv.c)
            prev_close = ohlcv.c[i-1]
            curr_close = ohlcv.c[i]
            
            if prev_close > 0
                change_pct = abs(curr_close - prev_close) / prev_close
                
                if change_pct > threshold
                    price_jumps = true
                    push!(issues[:price_jumps], (
                        index=i,
                        time=unix2datetime(ohlcv.t[i] ÷ 1000),
                        previous_close=prev_close,
                        current_close=curr_close,
                        change_pct=change_pct * 100  # as percentage
                    ))
                end
            end
        end
    end
    
    # Summarize results
    all_passed = high_low_valid && open_valid && close_valid && !negative_values && 
                 !timestamp_gaps && !timestamp_duplicates && !price_jumps
    
    if verbose
        println("OHLCV Data Integrity Test Results for $(ohlcv.config.market) $(ohlcv.config.timeframe):")
        println("  ✓ High >= Low: ", high_low_valid ? "PASSED" : "FAILED ($(length(issues[:high_below_low])) issues)")
        println("  ✓ Open in range: ", open_valid ? "PASSED" : "FAILED ($(length(issues[:open_outside_range])) issues)")
        println("  ✓ Close in range: ", close_valid ? "PASSED" : "FAILED ($(length(issues[:close_outside_range])) issues)")
        println("  ✓ No negative values: ", !negative_values ? "PASSED" : "FAILED ($(length(issues[:negative_values])) issues)")
        println("  ✓ No zero volume: ", !zero_volume ? "PASSED" : "FAILED ($(length(issues[:zero_volume])) issues)")
        println("  ✓ No timestamp gaps: ", !timestamp_gaps ? "PASSED" : "FAILED ($(length(issues[:timestamp_gaps])) issues)")
        println("  ✓ No duplicate timestamps: ", !timestamp_duplicates ? "PASSED" : "FAILED ($(length(issues[:timestamp_duplicates])) issues)")
        println("  ✓ No suspicious price jumps: ", !price_jumps ? "PASSED" : "FAILED ($(length(issues[:price_jumps])) issues)")
        println("  Overall: ", all_passed ? "PASSED" : "FAILED")
        
        # Print details of issues if any
        for (issue_type, issue_list) in issues
            if !isempty(issue_list)
                println("\nDetails for $issue_type:")
                for (i, issue) in enumerate(issue_list)
                    println("  Issue $i: $issue")
                    i >= 5 && length(issue_list) > 5 && (println("  ... and $(length(issue_list) - 5) more"); break)
                end
            end
        end
    end
    
    return (passed=all_passed, issues=issues)
end

"""
    fix_ohlcv_data!(ohlcv::OHLCV; auto_fix=true)

Attempt to fix common issues in OHLCV data.
Returns the fixed OHLCV object and a report of changes made.
"""
function fix_ohlcv_data!(ohlcv::OHLCV; auto_fix=true)
    fixes_applied = Dict{Symbol, Int}()
    fixes_applied[:high_below_low] = 0
    fixes_applied[:open_outside_range] = 0
    fixes_applied[:close_outside_range] = 0
    fixes_applied[:negative_values] = 0
    
    # Fix 1: Ensure high >= low
    for i in 1:length(ohlcv.t)
        if ohlcv.h[i] < ohlcv.l[i]
            if auto_fix
                # Swap high and low
                ohlcv.h[i], ohlcv.l[i] = ohlcv.l[i], ohlcv.h[i]
                fixes_applied[:high_below_low] += 1
            end
        end
    end
    
    # Fix 2: Ensure open is between high and low
    for i in 1:length(ohlcv.t)
        if ohlcv.o[i] > ohlcv.h[i]
            if auto_fix
                # Set high to max of high and open
                ohlcv.h[i] = ohlcv.o[i]
                fixes_applied[:open_outside_range] += 1
            end
        elseif ohlcv.o[i] < ohlcv.l[i]
            if auto_fix
                # Set low to min of low and open
                ohlcv.l[i] = ohlcv.o[i]
                fixes_applied[:open_outside_range] += 1
            end
        end
    end
    
    # Fix 3: Ensure close is between high and low
    for i in 1:length(ohlcv.t)
        if ohlcv.c[i] > ohlcv.h[i]
            if auto_fix
                # Set high to max of high and close
                ohlcv.h[i] = ohlcv.c[i]
                fixes_applied[:close_outside_range] += 1
            end
        elseif ohlcv.c[i] < ohlcv.l[i]
            if auto_fix
                # Set low to min of low and close
                ohlcv.l[i] = ohlcv.c[i]
                fixes_applied[:close_outside_range] += 1
            end
        end
    end
    
    # Fix 4: Fix negative values
    for i in 1:length(ohlcv.t)
        if ohlcv.o[i] < 0 || ohlcv.h[i] < 0 || ohlcv.l[i] < 0 || ohlcv.c[i] < 0 || ohlcv.v[i] < 0
            if auto_fix
                # Set negative prices to absolute values
                ohlcv.o[i] = abs(ohlcv.o[i])
                ohlcv.h[i] = abs(ohlcv.h[i])
                ohlcv.l[i] = abs(ohlcv.l[i])
                ohlcv.c[i] = abs(ohlcv.c[i])
                ohlcv.v[i] = abs(ohlcv.v[i])
                fixes_applied[:negative_values] += 1
            end
        end
    end
    
    # Note: We don't attempt to fix timestamp gaps or duplicates as that would
    # require more complex interpolation or data removal
    
    return (ohlcv=ohlcv, fixes=fixes_applied)
end

# Test different timeframes and markets
test_cases = [
    "binance:BTC_USDT@1h:futures|0*1500",
    "binance:BTC_USDT@1h:futures|-300*1500",
    "binance:ETH_USDT@15m:futures|0*300",
    "binance:SOL_USDT@1d:futures|0*300"
]

for test_case in test_cases
    println("\n\nTesting $test_case")
    println("=" ^ 50)
    
    data = get_ohlcv(test_case)
    results = test_ohlcv_integrity(data)
    
    if !results.passed
        println("\nAttempting to fix issues...")
        fixed = fix_ohlcv_data!(data)
        println("Fixes applied:")
        for (fix_type, count) in fixed.fixes
            count > 0 && println("  - $fix_type: $count fixes")
        end
        
        # Verify fixes
        println("\nVerifying fixes...")
        new_results = test_ohlcv_integrity(data)
        if new_results.passed
            println("All issues fixed successfully!")
        else
            println("Some issues remain after fixing.")
        end
    end
end
