NoArg = 4
class CB
  class NoArg < self
  end
end
r = NoArg  # expect 4
unless r == 4
  raise 'ERROR'
end
r = CB::NoArg  
rcls = r.class
n = rcls.name
# note Gemstone result not in agreement with MRI yet
unless n == 'CB__NoArg class'
  puts r
  raise 'ERROR'
end
true