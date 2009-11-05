# Commit the KD Tree Code, then create and commit a tree of random
# locations.  Prints time stats for operations.
require 'benchmark'

puts "== Committing tree2d.rb"
Maglev.persistent do
  require 'tree2d'
end
Maglev.commit_transaction

num_nodes = 1_000_000
MAX_SCALAR = 360.0
MID_POINT  = MAX_SCALAR / 2.0

Benchmark.bm do |r|
  puts "== Creating tree of #{num_nodes} random nodes"
  r.report("Create Random Points") do
    points = Array.new(num_nodes) do |i|
      KDTree::Point2D.new(rand(MAX_SCALAR) - MID_POINT,
                          rand(MAX_SCALAR) - MID_POINT,
                          i)
    end
  end

  r.report("Create random tree") do
    Maglev::PERSISTENT_ROOT[:RANDOM_KDTREE] = KDTree::Tree2D.new(points)
  end

  r.report("Commit data") do
    Maglev.commit_transaction
  end
  puts "== Committed tree as Maglev::PERSISTENT_ROOT[:RANDOM_KDTREE]"
end
