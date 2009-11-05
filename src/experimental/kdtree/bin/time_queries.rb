# Commit the KD Tree Code, then create and commit a tree of random
# locations.
require 'benchmark'

raise "No Committed Data; run: 'rake commit' first." if Maglev::PERSISTENT_ROOT[:RANDOM_KDTREE].nil?

MAX_SCALAR = 360.0
MID_POINT  = MAX_SCALAR / 2.0

num_queries = 1_000
k = 100
count = 0
puts
Benchmark.bm(15) do |r|
  r.report("Iterate Nodes") do
    Maglev::PERSISTENT_ROOT[:RANDOM_KDTREE].each {|el| count += 1 }
  end
end

tms = Benchmark.measure do
  num_queries.times do
    target = KDTree::Point2D.new(rand(MAX_SCALAR) - MID_POINT,
                                 rand(MAX_SCALAR) - MID_POINT,
                                 :target)
    Maglev::PERSISTENT_ROOT[:RANDOM_KDTREE].nearest_k(target, k)
  end
end


times = [tms.utime, tms.stime, tms.total, tms.real]
per_query_times = times.map {|el| el / num_queries }
puts
puts "#{num_queries} queries for #{k} nearest nodes"
puts "               #{Benchmark::Tms::CAPTION}"
puts "Time:          %10.6f %10.6f %10.6f (%10.6f)\n" % times
puts "Per Query:     %10.6f %10.6f %10.6f (%10.6f)\n" % per_query_times

fmt = count.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
puts "\nTree has #{fmt} nodes"
