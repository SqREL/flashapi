# frozen_string_literal: true

require 'benchmark/ips'
require 'json'
require 'oj'
require_relative '../lib/flashapi/json_serializer'

# Sample data structures for benchmarking
SIMPLE_HASH = { name: "John Doe", age: 30, active: true }

COMPLEX_HASH = {
  id: 12345,
  name: "John Doe",
  email: "john@example.com",
  profile: {
    bio: "Software developer with 10 years of experience",
    location: "San Francisco, CA",
    skills: ["Ruby", "JavaScript", "Go", "Python"],
    social: {
      twitter: "@johndoe",
      github: "johndoe",
      linkedin: "john-doe"
    }
  },
  posts: [
    { id: 1, title: "First Post", content: "Lorem ipsum dolor sit amet", likes: 42 },
    { id: 2, title: "Second Post", content: "Consectetur adipiscing elit", likes: 17 },
    { id: 3, title: "Third Post", content: "Sed do eiusmod tempor incididunt", likes: 28 }
  ],
  metadata: {
    created_at: Time.now.to_s,
    updated_at: Time.now.to_s,
    last_login: Time.now.to_s,
    ip_address: "192.168.1.1"
  }
}

ARRAY_DATA = Array.new(100) do |i|
  {
    id: i,
    name: "User #{i}",
    email: "user#{i}@example.com",
    active: i.even?,
    score: rand(100)
  }
end

puts "JSON Serialization Benchmarks"
puts "============================="
puts

# Ensure Oj is configured
FlashAPI::JsonSerializer.configure!

# Benchmark serialization
puts "Serialization (dump) Performance:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Standard JSON (simple)") do
    JSON.generate(SIMPLE_HASH)
  end

  x.report("Oj default (simple)") do
    Oj.dump(SIMPLE_HASH)
  end

  x.report("FlashAPI optimized (simple)") do
    FlashAPI::JsonSerializer.dump(SIMPLE_HASH)
  end

  x.compare!
end

puts "\nComplex Hash Serialization:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Standard JSON (complex)") do
    JSON.generate(COMPLEX_HASH)
  end

  x.report("Oj default (complex)") do
    Oj.dump(COMPLEX_HASH)
  end

  x.report("FlashAPI optimized (complex)") do
    FlashAPI::JsonSerializer.dump(COMPLEX_HASH)
  end

  x.compare!
end

puts "\nArray Serialization:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Standard JSON (array)") do
    JSON.generate(ARRAY_DATA)
  end

  x.report("Oj default (array)") do
    Oj.dump(ARRAY_DATA)
  end

  x.report("FlashAPI optimized (array)") do
    FlashAPI::JsonSerializer.dump(ARRAY_DATA)
  end

  x.compare!
end

# Benchmark deserialization
simple_json = JSON.generate(SIMPLE_HASH)
complex_json = JSON.generate(COMPLEX_HASH)
array_json = JSON.generate(ARRAY_DATA)

puts "\n\nDeserialization (load) Performance:"
puts "====================================="
puts "\nSimple Hash Deserialization:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Standard JSON parse") do
    JSON.parse(simple_json, symbolize_names: true)
  end

  x.report("Oj default load") do
    Oj.load(simple_json, symbol_keys: true)
  end

  x.report("FlashAPI optimized load") do
    FlashAPI::JsonSerializer.load(simple_json)
  end

  x.compare!
end

puts "\nComplex Hash Deserialization:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Standard JSON parse") do
    JSON.parse(complex_json, symbolize_names: true)
  end

  x.report("Oj default load") do
    Oj.load(complex_json, symbol_keys: true)
  end

  x.report("FlashAPI optimized load") do
    FlashAPI::JsonSerializer.load(complex_json)
  end

  x.compare!
end

# Memory allocation comparison
puts "\n\nMemory Allocation Comparison:"
puts "============================="

require 'objspace'

def measure_allocations
  GC.start
  before = ObjectSpace.count_objects
  yield
  GC.start
  after = ObjectSpace.count_objects
  
  diff = {}
  after.each { |k, v| diff[k] = v - before[k] if v != before[k] }
  diff
end

puts "\nSerializing complex hash 1000 times:"
puts "-" * 50

json_allocs = measure_allocations do
  1000.times { JSON.generate(COMPLEX_HASH) }
end

oj_allocs = measure_allocations do
  1000.times { Oj.dump(COMPLEX_HASH) }
end

optimized_allocs = measure_allocations do
  1000.times { FlashAPI::JsonSerializer.dump(COMPLEX_HASH) }
end

puts "Standard JSON allocations: #{json_allocs}"
puts "Oj default allocations: #{oj_allocs}"
puts "FlashAPI optimized allocations: #{optimized_allocs}"