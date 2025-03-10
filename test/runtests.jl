using CryptoOHLCV
using Test
using Dates

# Include the data integrity tests
include("data_integrity_tests.jl")

@testset "CryptoOHLCV.jl" begin
    # Test day-timestamp conversion
    @testset "Day-Timestamp Conversion" begin
        # Test that day 0 corresponds to the reference timestamp
        @test day_to_timestamp(0) == REFERENCE_TIMESTAMP
        
        # Test conversion back and forth
        for day in [0, 1, 7, 30, 365]
            ts = day_to_timestamp(day)
            back_day = timestamp_to_day(ts)
            @test back_day == day
        end
    end
    
    # Test OHLCV configuration
    @testset "OHLCV Configuration" begin
        config = OHLCVConfig(
            exchange = "test_exchange",
            market = "TEST_USDT",
            is_futures = true,
            timeframe = "4h",
            from_day = 10,
            to_day = 5
        )
        
        @test config.exchange == "test_exchange"
        @test config.market == "TEST_USDT"
        @test config.is_futures == true
        @test config.timeframe == "4h"
        @test config.from_day == 10
        @test config.to_day == 5
    end
    
    # Test OHLCV structure
    @testset "OHLCV Structure" begin
        # Create a simple OHLCV object with test data
        config = OHLCVConfig(market = "TEST_USDT")
        
        # Create sample data
        t = [REFERENCE_TIMESTAMP - i * 60000 for i in 0:9]  # 10 minutes of data
        o = Float32[100.0 + i for i in 0:9]
        h = Float32[105.0 + i for i in 0:9]
        l = Float32[95.0 + i for i in 0:9]
        c = Float32[102.0 + i for i in 0:9]
        v = Float32[1000.0 + i*100 for i in 0:9]
        
        ohlcv = OHLCV(
            t = t,
            o = o,
            h = h,
            l = l,
            c = c,
            v = v,
            config = config
        )
        
        # Test basic properties
        @test length(ohlcv) == 10
        @test ohlcv.set == :TRAIN
        
        # Test data integrity
        results = test_ohlcv_integrity(ohlcv, verbose=false)
        @test results.passed
    end
    
    # Test parsing source string
    @testset "Parse Source String" begin
        # Test with full source string
        source = "binance:BTC_USDT@1h:futures|0*7"
        exchange, market, timeframe, is_futures, from_day, to_day = CryptoOHLCV.parse_source_string(source)
        
        @test exchange == "binance"
        @test market == "BTC_USDT"
        @test timeframe == "1h"
        @test is_futures == true
        @test from_day == 7
        @test to_day == 0
        
        # Test with minimal source string
        source = "ETH_USDT"
        exchange, market, timeframe, is_futures, from_day, to_day = CryptoOHLCV.parse_source_string(source)
        
        @test exchange == "binance"  # default
        @test market == "ETH_USDT"
        @test timeframe == "1m"      # default
        @test is_futures == false    # default
        @test from_day == 0          # default
        @test to_day == 7            # default
    end
    
    # Only run API tests if credentials are available
    if haskey(ENV, "BINANCE_API_KEY") && haskey(ENV, "BINANCE_API_SECRET")
        @testset "API Integration" begin
            # Initialize API
            initialize_api()
            
            # Test getting OHLCV data
            @testset "Get OHLCV Data" begin
                # Get a small amount of data to keep tests fast
                data = get_ohlcv("binance:BTC_USDT@1h:futures|0*1")
                
                # Basic checks
                @test !isempty(data.t)
                @test length(data.o) == length(data.t)
                @test length(data.h) == length(data.t)
                @test length(data.l) == length(data.t)
                @test length(data.c) == length(data.t)
                @test length(data.v) == length(data.t)
                
                # Check data integrity
                results = test_ohlcv_integrity(data, verbose=false)
                @test results.passed
            end
            
            # Test caching
            @testset "OHLCV Caching" begin
                # First request should download data
                t1 = @elapsed data1 = get_ohlcv("binance:ETH_USDT@15m:futures|0*1")
                
                # Second request should use cache
                t2 = @elapsed data2 = get_ohlcv("binance:ETH_USDT@15m:futures|0*1")
                
                # Cache should be faster
                @test t2 < t1
                
                # Data should be identical
                @test data1.t == data2.t
                @test data1.c == data2.c
            end
        end
    else
        @warn "Skipping API tests: Binance API credentials not found in environment variables"
    end
end
