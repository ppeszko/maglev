#---------------------------------
# Symbol
#    Smalltalk Symbol and Ruby Symbol are identical classes .
#    In Smalltalk, the superclass of Symbol is String .
#
#    You cannot code  'class Symbol < Object' in this file
#    because Object would not match the Smalltalk superclass.
#    In environments >= 1, at the end of bootstrapping,
#    the superclass of Symbol is changed to be Object by use 
#    of RubyContext>>_fixSymbolSuperclass:  in the .mcz code.

class Symbol
  # returns an Array containing all keys in the Smalltalk dictionary AllSymbols
  class_primitive_nobridge 'all_symbols', '_rubyAllSymbols'

  primitive_nobridge 'id2name', 'asString'
  primitive_nobridge '==', '='  # uses Symbol>>= which is identity compare
  primitive_nobridge 'eql?', '='  # uses Symbol>>= which is identity compare
  primitive_nobridge 'hash'

  def inspect
    ':'._concatenate(self)
  end

  # You may not create symbols directly
  def self.new
    raise 'Illegal creation of a Symbol'
  end
  def initialize
    raise 'Illegal construction of a Symbol'
  end

  # You may not copy Symbols
  def dup
    self
  end
  def clone
    self
  end

  primitive_nobridge 'to_i', 'asOop'
  primitive_nobridge 'to_int', 'asOop'
  primitive_nobridge 'to_s', 'asString'
  primitive_nobridge 'to_sym', 'asSymbol'
  primitive_nobridge 'exception', 'asRubyException'

  def call(value)
    value.__send__(self)
  end

  def respond_to?(sym)
    if sym.equal?(:to_str)
      false
    else
      super(sym)
    end
  end

  def taint
    self # do nothing
  end

end
