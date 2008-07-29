class Regexp
    primitive 'search', '_search:from:to:'
    primitive 'compile', '_compile:options:'
    primitive 'source', 'source'    
    self.class.primitive 'alloc', '_basicNew'

    def initialize(str, options, lang)
        if options.kind_of? Integer
            o = options
        else
           o = options ? 1 : 0
        end
        compile(str, o)
    end
    
    def match(str)
        return nil unless str && str.length > 0
        $~ = search(str, 0, nil)
=begin
#needed by racc
        if $~
            $& = $~[0]
            $' = $~.post_match
            $` = $~.pre_match
        end
=end
        return $~
    end

    def =~(str)
        if match(str)
            $~.begin(0)
        end
    end
    
    def each_match(str, &block)
        pos = 0
        while(pos < str.length)
            $~ = match = search(str, pos, nil)
            return unless match
            pos = match.end(0)
            if match.begin(0) == pos
                pos += 1
            else
                block.call(match)
            end
        end
    end
    
    def all_matches(str)
        matches = []
        each_match(str){|m| matches << m}
        matches
    end
    
    def ===(str)
      if str.kind_of?(String)
        if  self.=~(str) 
          return true 
        end
      end   
      return false
    end
    
    def self.escape(str)
        str
    end
    
    def to_rx
      self
    end
    
    IGNORECASE = 1
    EXTENDED = 2
    MULTILINE = 4
end

class MatchData
    primitive 'at', 'at:'

    def begin(group)
        at((group*2)+1)
    end
    
    def end(group)
        at((group*2)+2)
    end

    def string
        @inputString
    end

    def pre_match
        string[0..self.begin(0)-1]
    end
    
    def post_match
        string[self.begin(0)+self[0].size..-1]
    end

    primitive '[]' , '_rubyAt:'
    primitive '[]' , '_rubyAt:length:'

    # Ruby global variables $1..$9 implemented by MatchData(C)>>nthRegexRef:
end