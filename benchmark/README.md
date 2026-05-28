# FlashAPI Benchmark Suite

This directory contains comprehensive benchmarks comparing FlashAPI performance against popular Ruby web frameworks.

## Running Benchmarks

### Quick Start

Run all benchmarks and generate a report:

```bash
./run_all_benchmarks.rb
```

Results will be saved to `results/YYYYMMDD_HHMMSS/` with individual benchmark outputs and a summary report.

### Individual Benchmarks

You can run specific benchmarks individually:

```bash
# Framework comparison (requests per second)
bundle exec ruby framework_comparison.rb

# Memory profiling
bundle exec ruby memory_profiling.rb

# Throughput testing (realistic workload)
bundle exec ruby throughput_test.rb

# JSON serialization optimization
bundle exec ruby json_optimization.rb

# Raw Rack performance
bundle exec ruby rack_performance.rb
```

## Benchmark Descriptions

### framework_comparison.rb
Compares FlashAPI, Sinatra, and Grape across different request types:
- Simple GET requests
- Complex GET requests with large JSON payloads
- POST requests with JSON parsing
- 404 error handling
- Memory usage comparison

### memory_profiling.rb
Detailed memory analysis using memory_profiler gem:
- Startup memory usage
- Memory allocation per request
- Object allocation by type
- Memory usage by gem

### throughput_test.rb
Realistic API workload simulation:
- Mixed request types (GET, POST, PUT, DELETE)
- Weighted request distribution
- Error handling
- Pagination support
- Concurrent-like request patterns

### json_optimization.rb
JSON serialization performance:
- Oj optimization settings
- Comparison with standard JSON
- Memory allocation analysis

### rack_performance.rb
Raw Rack adapter performance:
- Baseline performance metrics
- Overhead measurement
- Optimization validation

## Interpreting Results

### Requests Per Second (RPS)
Higher is better. Shows how many requests the framework can handle per second.

### Memory Usage
Lower is better. Shows memory consumption for both startup and per-request.

### Response Time
Lower is better. Shows how long it takes to process a request.

## Dependencies

The benchmark suite requires additional gems not included in the main gemspec:
- sinatra (~> 4.0)
- grape (~> 2.0)
- memory_profiler (~> 1.0)
- benchmark-ips (~> 2.13)

These are specified in the benchmark/Gemfile.

## Adding New Benchmarks

To add a new benchmark:

1. Create a new `.rb` file in this directory
2. Follow the existing pattern for output formatting
3. Add it to the `benchmarks` array in `run_all_benchmarks.rb`
4. Document it in this README

## Performance Goals

FlashAPI targets:
- < 0.1ms overhead per request
- > 50,000 req/s on single core
- < 10MB memory for 1000 concurrent connections
- Zero allocations for common request path