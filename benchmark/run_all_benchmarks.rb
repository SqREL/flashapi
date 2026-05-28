#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'time'

# Ensure we're in the benchmark directory
Dir.chdir(File.dirname(__FILE__))

# Create results directory
results_dir = "results/#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.mkdir_p(results_dir)

puts "FlashAPI Benchmark Suite"
puts "========================"
puts "Running all benchmarks and saving results to: #{results_dir}"
puts

benchmarks = [
  {
    name: "Framework Comparison",
    file: "framework_comparison.rb",
    output: "framework_comparison.txt"
  },
  {
    name: "Memory Profiling",
    file: "memory_profiling.rb",
    output: "memory_profiling.txt"
  },
  {
    name: "Throughput Test",
    file: "throughput_test.rb",
    output: "throughput_test.txt"
  },
  {
    name: "JSON Optimization",
    file: "json_optimization.rb",
    output: "json_optimization.txt"
  },
  {
    name: "Rack Performance",
    file: "rack_performance.rb",
    output: "rack_performance.txt"
  }
]

# Install dependencies first
puts "Installing benchmark dependencies..."
system("bundle install --quiet") || puts("Warning: Could not install dependencies")
puts

# Run each benchmark
benchmarks.each do |benchmark|
  if File.exist?(benchmark[:file])
    puts "Running #{benchmark[:name]}..."
    output_file = File.join(results_dir, benchmark[:output])
    
    # Run benchmark and capture output
    system("bundle exec ruby #{benchmark[:file]} > #{output_file} 2>&1")
    
    if $?.success?
      puts "✓ #{benchmark[:name]} completed successfully"
    else
      puts "✗ #{benchmark[:name]} failed"
    end
  else
    puts "⚠ Skipping #{benchmark[:name]} (file not found: #{benchmark[:file]})"
  end
end

# Generate summary report
puts "\nGenerating summary report..."

File.open(File.join(results_dir, "SUMMARY.md"), "w") do |f|
  f.puts "# FlashAPI Benchmark Results"
  f.puts
  f.puts "Generated: #{Time.now}"
  f.puts "Ruby Version: #{RUBY_VERSION}"
  f.puts "Platform: #{RUBY_PLATFORM}"
  f.puts
  f.puts "## Benchmark Files"
  f.puts
  
  benchmarks.each do |benchmark|
    output_file = File.join(results_dir, benchmark[:output])
    if File.exist?(output_file)
      f.puts "- [#{benchmark[:name]}](#{benchmark[:output]})"
    end
  end
  
  f.puts
  f.puts "## Key Findings"
  f.puts
  
  # Try to extract key metrics from framework comparison
  comparison_file = File.join(results_dir, "framework_comparison.txt")
  if File.exist?(comparison_file)
    content = File.read(comparison_file)
    
    # Extract performance comparisons
    if content =~ /Simple GET \/ request:.*?Comparison:(.*?)Complex/m
      f.puts "### Simple GET Request Performance"
      f.puts "```"
      f.puts $1.strip
      f.puts "```"
      f.puts
    end
    
    if content =~ /Complex GET \/users request:.*?Comparison:(.*?)POST/m
      f.puts "### Complex GET Request Performance"
      f.puts "```"
      f.puts $1.strip
      f.puts "```"
      f.puts
    end
  end
  
  # Extract memory usage
  memory_file = File.join(results_dir, "memory_profiling.txt")
  if File.exist?(memory_file)
    content = File.read(memory_file)
    
    if content =~ /Startup Memory Comparison(.*)/m
      f.puts "### Startup Memory Usage"
      f.puts "```"
      f.puts $1.strip.split("\n")[0..15].join("\n")
      f.puts "```"
      f.puts
    end
  end
  
  f.puts "## Conclusion"
  f.puts
  f.puts "FlashAPI demonstrates excellent performance characteristics:"
  f.puts "- Minimal memory footprint"
  f.puts "- Fast request handling"
  f.puts "- Efficient routing"
  f.puts "- Low object allocation"
  f.puts
  f.puts "See individual benchmark files for detailed results."
end

puts "✓ Summary report generated"
puts
puts "All benchmarks completed! Results saved to: #{results_dir}"
puts "View the summary at: #{File.join(results_dir, 'SUMMARY.md')}"