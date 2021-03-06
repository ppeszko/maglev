# ~
# ---------------------------------
#  Bignum and Integer
#
# The Smalltalk hierarchy is
#      Integer
#        LargeInteger
#        SmallInteger
#

class Integer

  def coerce(param)
    if param._isFloat
      s = self.to_f 
      if s._isFloat && ! s.nan?
        return [ param, s ]
      end
    elsif param._isInteger
      return [ param, self ]
    elsif param._isString
      return [ Float(param), self.to_f ]
    end
    super(param)
  end

  def self.induced_from(obj)
    if obj._isInteger
      obj
    elsif obj._isFloat
      obj.to_i
    else
      raise TypeError, "argument to induced_from neither Float nor Integer"
      nil
    end
  end

    # following 3 prims contain handler for RubyBreakException
    primitive_env 'times&', '_rubyTimes', ':'
    # def times(&block) ; end 

    # def upto(n, &block) ; end 
    primitive_env 'upto&', '_rubyUpto', ':block:'

    # def downdo(n, &block) ; end 
    primitive_env 'downto&', '_rubyDownto', ':block:'


    def chr
        if self > 255 || self < 0
            raise RangeError, "#{self} out of char range"
        end
        string = ' '
        string[0] = self
        string
    end

    def next
      self + 1
    end

    def succ
      self + 1
    end
        primitive_nobridge '+', '_rubyAdd:'
        primitive_nobridge '-', '_rubySubtract:'
        primitive_nobridge '*', '_rubyMultiply:'
        primitive_nobridge '/', '_rubyDivide:'
        primitive_nobridge '__divide', '_rubyDivide:'

        primitive_nobridge '%', '_rubyModulo:'
        primitive_nobridge 'modulo', '_rubyModulo:'

        primitive_nobridge '**', '_rubyRaisedTo:'

        def _fraised_to(arg)
          # handles coercion for _rubyRaisedTo:
          if arg._isInteger 
            raise TypeError , 'coercion error in ** '
          elsif arg._isNumeric
            c = arg.coerce(self)
            c[0] ** c[1]
          else
            raise TypeError, 'numeric coercion failed'
            nil
          end
        end 

        primitive_nobridge '~', 'bitInvert'
        primitive_nobridge '&', '_rubyBitAnd:'
        primitive_nobridge '|', '_rubyBitOr:'
        primitive_nobridge '^', '_rubyBitXor:'
        primitive_nobridge '<<', '_rubyShiftLeft:'

        def >>(arg)
          unless arg._isFixnum
            arg = Type.coerce_to(arg, Integer, :to_int)
            unless arg._isFixnum 
	      if (self >= 0)
	        return 0
	      else
	        return -1
              end
            end
          end
          self << ( 0 - arg )
        end

       # following handle primitive failures of  _rubyBitOr:, etc
       def _bit_and(arg)
         a = Type.coerce_to(arg, Integer, :to_int) 
         self & a 
       end

       def _bit_or(arg)
         a = Type.coerce_to(arg, Integer, :to_int) 
         self | a 
       end

       def _bit_xor(arg)
         a = Type.coerce_to(arg, Integer, :to_int) 
         self ^ a 
       end

       def _shift_left(arg)
         a = Type.coerce_to(arg, Integer, :to_int) 
         unless a._isFixnum
           raise RangeError, 'argument must be a Fixnum'
         end
         self << a 
       end

     primitive '<',  '_rubyLt:'
     primitive '<=', '_rubyLteq:'
     primitive '>' , '_rubyGt:'
     primitive '>=', '_rubyGteq:'
     primitive '==', '_rubyEqual:'

     def <=>(arg)
       if arg._isInteger
         if self < arg
           -1
         elsif self == arg
           0
         else
           1  
         end
       elsif arg._isFloat
         sf = Type.coerce_to(self, Float, :to_f)
         sf <=> arg
       else
         super
       end
     end

     primitive_nobridge '__bit_at', 'bitAt:'
     
     def [](arg)
       a = Type.coerce_to(arg, Integer, :to_int)
       if (a < 0)
         0
       else
         if a._isFixnum
           self.__bit_at(a)
         else
           self < 0 ? 1 : 0 
         end
       end 
     end

    def abs
      if self < 0
	- self
      else
	self
      end
    end

     def ceil
       self
     end

        primitive 'eql?', '_ruby_eqlQ:'

        def divmod(arg)
          if arg._isInteger
            q = self.__divide(arg)
            r = self - (q * arg)
            [ q, r ]
          elsif arg._isNumeric
            c = arg.coerce(self)
            c[0].divmod(c[1])
          else
            raise TypeError, 'numeric coercion failed'
            nil
          end
        end

        def div(arg)
          if arg._isFloat 
            if arg == 0.0
              raise FloatDomainError, 'argument to div is zero'
            end
            self.to_f.div(arg)
          else
            q = self.__divide(arg)
            q.to_int
          end
        end

        primitive 'hash'

        
        def quo(param)
           (self.to_f ).__divide(param)
        end

#  remainder  inherited from numeric

        primitive 'size', 'size'
        primitive 'to_f', 'asFloat'
        primitive '__to_float', 'asFloat'
        primitive 'to_i', 'truncated'
        primitive 'to_int' , 'truncated'

        primitive '__to_s_base_show', 'printStringRadix:showRadix:'

        # primitive to_s  is the zero arg form 
        primitive 'to_s', 'asString'

        def to_s(base)
          unless base._isFixnum 
            raise TypeError, 'arg must be a Fixnum'
          end
          __to_s_base_show(base, false)
        end

        primitive 'truncate' , 'truncated'

#  methods from Numeric
        primitive 'floor', 'floor'
        primitive 'round', 'rounded'

  def zero? 
    self == 0
  end

  def nonzero?
    if self == 0
      nil
    else
      self
    end
  end

# Were in String.rb
    def __split_string(string, limit)
        self.chr.__split_string(string, limit)
    end

# primitives added to support BigDecimal implementation

  class_primitive_nobridge '__from_string', 'fromString:'

  primitive_nobridge '__decimal_digits_length_approx', '_decimalDigitsLength:' 
    # argument is useApproximationBoolean , if true result may  be
    # slightly smaller than actual number of digits

  primitive_nobridge '__min', 'min:'  # Smalltalk coercion on arg
  primitive_nobridge '__max', 'max:'  # Smalltalk coercion on arg
  primitive_nobridge '__quo_rem', 'quoRem:into:' # Smalltalk coercion on arg

end
