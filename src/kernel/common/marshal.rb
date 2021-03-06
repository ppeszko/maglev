# file marshal.rb 
# depends on: module.rb class.rb

module Marshal

  class State # [

    def initialize(stream, depth, proc)
      # shared
      @objs_dict = IdentityHash.new
      @objs_output_count = 0
      @objs_input_arr = []
      @syms_dict = IdentityHash.new
      @syms_output_count = 0
      @syms_input_arr = []

      # dumping
      @depth = depth

      # loading
      @stream = stream
      @consumed = 0

      consume(2) if @stream

      @modules = nil
      @has_ivar = []
      @proc = proc
      @call = true
    end

    def add_output_obj(obj)
      count = @objs_output_count
      @objs_dict[obj] = count
      @objs_output_count = count + 1
    end

    def add_output_sym(obj)
      count = @syms_output_count
      @syms_dict[obj] = count
      @syms_output_count = count + 1
    end

    def store_unique_object(obj)
      # used on input
      arr = @objs_input_arr
      arr[arr.length] = obj
      obj
    end

    def call(obj)
      @proc.call obj if @proc and @call
    end

    def construct(ivar_index = nil, call_proc = true) # [
      type = consume_byte

      if type.equal?(TYPE_NIL_ch)
        obj = nil
      elsif type.equal?( TYPE_TRUE_ch )
        obj = true
      elsif type.equal?( TYPE_FALSE_ch )
        obj = false
      elsif type.equal?( TYPE_FIXNUM_ch )
        obj = construct_integer
      elsif type.equal?( TYPE_LINK_ch )
        num = construct_integer
        obj = @objs_input_arr[num]
        raise ArgumentError, "dump format error (unlinked)" if obj.equal?(nil)
        return obj
      elsif type.equal?( TYPE_SYMLINK_ch )
        num = construct_integer
        obj = @syms_input_arr[num]
        raise ArgumentError, "dump format error (symbol unlinked)" if obj.equal?(nil)
        return obj
      elsif type.equal?( TYPE_STRING_ch)
        obj = construct_string
        call obj if call_proc
      elsif type.equal?( TYPE_ARRAY_ch )
        obj = construct_array
        call obj if call_proc
      elsif type.equal?( TYPE_SYMBOL_ch )
        obj = construct_symbol
      elsif type.equal?( TYPE_FLOAT_ch )
        obj = construct_float
      elsif type.equal?( TYPE_BIGNUM_ch )
        obj = construct_bignum
      elsif type.equal?( TYPE_CLASS_ch) || type.equal?( TYPE_MODULE_ch)
        name = construct_symbol
        #obj = Object.const_get(name)
        obj = get_scoped_constant(name)
        store_unique_object(obj)
        call obj if call_proc
      elsif type.equal?( TYPE_REGEXP_ch )
        obj = construct_regexp
        call obj if call_proc
      elsif type.equal?( TYPE_HASH_ch) || type.equal?( TYPE_HASH_DEF_ch)
        obj = construct_hash(type)
        call obj if call_proc
      elsif type.equal?( TYPE_STRUCT_ch )
        obj = construct_struct
        call obj if call_proc
      elsif type.equal?( TYPE_OBJECT_ch )
        obj = construct_object
        call obj if call_proc
      elsif type.equal?( TYPE_USERDEF_ch )
        obj = construct_user_defined ivar_index
        call obj if call_proc
      elsif type.equal?( TYPE_USRMARSHAL_ch )
        obj = construct_user_marshal
        call obj if call_proc
      elsif type.equal?( TYPE_EXTENDED_ch )
        @modules ||= []
        name = get_symbol
        # @modules << Object.const_get(name)
        @modules << get_scoped_constant(name)
        obj = construct( nil, false)
        extend_object( obj)
        call obj if call_proc

      elsif type.equal?( TYPE_UCLASS_ch )
        name = get_symbol
        @user_class = name
        obj = construct( nil, false)
        call obj if call_proc

      elsif type.equal?( TYPE_IVAR_ch )
        ivar_index = @has_ivar.length
        @has_ivar.push(true)
        obj = construct(ivar_index, false)
        set_instance_variables obj if @has_ivar.pop
        call obj if call_proc
      else
        raise ArgumentError, "load error, unknown type #{type}"
      end
      obj
    end # ]

    def construct_array
      obj = @user_class ? get_user_class.new : []
      store_unique_object obj

      for k in (1..construct_integer) do
        obj << construct
      end

      obj
    end

    def construct_bignum
      sign = consume_byte == ?-  ? -1 : 1
      size = construct_integer * 2

      result = 0

      data = consume(size)
      (0...size).each do |exp|
        result += (data[exp] * (1 << (exp*8)) )
      end

      obj = result * sign
    end

    def construct_float
      s = get_byte_sequence
      last_ch = s[-1]
      if last_ch.equal?( ?n ) || last_ch.equal?( ?f )
        if s == "nan"
          obj = 0.0.__divide(0.0)
        elsif s == "inf"
          obj = 1.0.__divide(0.0)
        elsif s == "-inf"
          obj = 1.0.__divide(-0.0)
        else
          obj = s.to_f
        end
      else
        obj = s.to_f
      end
      obj
    end

    def construct_hash(type)
      obj = @user_class ? get_user_class.allocate : {}
      store_unique_object obj

      for k in (1..construct_integer) do
        key = construct
        val = construct
        obj[key] = val
      end

      obj.default = construct if type.equal?( TYPE_HASH_DEF_ch)

      obj
    end

    def construct_integer
      n = consume_byte
      if (n > 0 and n < 5) or n > 251
        if n > 251
          size= 256 - n
          signed = 1 << ((256 - n)*8)
        else
          size = n
          signed = 0
        end

        result = 0
        data = consume(size)

        for exp in (0...size) do
          result += (data[exp] * (1 << (exp*8)) )
        end
        result - signed
      elsif n > 127
        (n - 256) + 5
      elsif n > 4
        n - 5
      else
        n
      end
    end

    def construct_object
      name = get_symbol
      #klass = Object.const_get(name)
      klass = get_scoped_constant(name)
      obj = klass.allocate

      raise TypeError, 'dump format error' unless Object === obj

      store_unique_object obj
      set_instance_variables obj

      obj
    end

    def construct_regexp
      s = get_byte_sequence
      if @user_class
        obj = get_user_class.new(s, consume_byte)
      else
        obj = Regexp.new(s, consume_byte)
      end

      store_unique_object obj
    end

    def construct_string
      obj = get_byte_sequence
      obj = get_user_class.new obj if @user_class

      store_unique_object obj
    end

    def construct_struct
      symbols = []
      values = []

      name = get_symbol
      #

      #klass = Object.const_get(name)
      klass = get_scoped_constant(name)
      members = klass.members

      obj = klass.allocate
      store_unique_object obj

      for i in (0..(construct_integer - 1)) do
        slot = get_symbol
        unless members[i].intern == slot then
          raise TypeError, "struct %s is not compatible (%p for %p)" %
            [klass, slot, members[i]]
        end

        obj.instance_variable_set "@#{slot}", construct
      end

      obj
    end

    def construct_symbol
      obj = get_byte_sequence.to_sym
      arr = @syms_input_arr   # inline store_unique_sym
      arr[arr.length] = obj
      obj
    end

    def construct_user_defined(ivar_index)
      name = get_symbol
      klass = get_scoped_constant(name)
      #klass = Module.const_get(name)

      data = get_byte_sequence

      if ivar_index and @has_ivar[ivar_index] then
        set_instance_variables data
        @has_ivar[ivar_index] = false
      end

      obj = klass._load data

      store_unique_object obj

      obj
    end

    def construct_user_marshal
      name = get_symbol
      #
      klass = get_scoped_constant(name)
      obj = klass.allocate

      extend_object obj if @modules

      unless obj.respond_to? :marshal_load then
        raise TypeError, "instance of #{klass} needs to have method `marshal_load'"
      end

      store_unique_object obj

      data = construct
      obj.marshal_load data

      obj
    end

    def consume(byte_count)
      idx = @consumed
      data = @stream[idx, byte_count]
      idx += byte_count
      @consumed = idx
      data
    end

    def consume_byte
      idx = @consumed
      ch = @stream[idx]
      idx += 1
      @consumed = idx
      ch
    end

    def extend_object(obj)
      obj.extend(@modules.pop) until @modules.empty?
    end

    def get_byte_sequence
      size = construct_integer
      consume(size)
    end

    def _get_module_names(a_class)
      # returns an Array of Symbols
      h = MAGLEV_MARSHAL_CLASS_CACHE
      arr = h[a_class]
      if arr.equal?(nil)
        #        arr = a_class.ancestor_modules_names - ['Enumerable']
        arr = []
        sup = obj.class.superclass
        h[a_class] = arr
      end
      arr
    end

    def get_module_names(obj)
      names = []
#      sup = obj.metaclass.superclass
      sup = obj.class.superclass
#     while sup and [Module].include? sup.class do
      while sup and sup.class.equal?( Module ) do
        names << sup.name
        sup = sup.superclass
      end

      names
    end

    def get_module_namesX(obj)
      # returns an Array of Symbols
      _get_module_names(obj.class)  # Gemstone changes
    end

    def get_scoped_constant(name)
      ns = Module
      name.to_s.split('::').each do |n|
        ns = ns.const_get(n) unless n.empty?
      end
      ns
    end

    def get_user_class
      cls = Module.const_get(@user_class)
      @user_class = nil
      cls
    end

    def get_symbol
      type = consume_byte
      if type.equal?(TYPE_SYMBOL_ch)
        @call = false
        obj = construct_symbol
        @call = true
      elsif type.equal?(TYPE_SYMLINK_ch)
        num = construct_integer
        obj = @syms_input_arr[num]
      else
        raise ArgumentError, "expected TYPE_SYMBOL or TYPE_SYMLINK, got #{type.inspect}"
      end
      obj
    end

    def prepare_ivar(ivar)
      ivar.to_s =~ /\A@/ ? ivar : "@#{ivar}".to_sym
    end

    def serialize(obj)
      raise ArgumentError, "exceed depth limit" if @depth.equal?(0)

      if obj.__isSpecial
        str = obj.to_marshal(self)
      elsif obj._isSymbol
        idx = @syms_dict[obj]
        if idx.equal?(nil)
          add_output_sym(obj)
          str = obj.to_marshal(self)
        else
          # object already seen , by a call to add_output_sym
          str = TYPE_SYMLINK + serialize_integer(idx)
        end
      else
        idx = @objs_dict[obj]
        if idx.equal?(nil)
          @depth -= 1;
          if obj.respond_to? :_dump then
            add_output_obj(obj)
            str = serialize_user_defined obj
          elsif obj.respond_to? :marshal_dump then
            add_output_obj(obj)
            str = serialize_user_marshal obj
          else
            add_output_obj(obj)
            str = obj.to_marshal(self)
          end
          @depth += 1
        else
          # object seen , by a call to add_output_obj
          str = TYPE_LINK + serialize_integer(idx)
        end
      end
      return str
    end

    def serialize_extended_object(obj)
      arr = get_module_names(obj)
      n = 0
      lim = arr.size
      str = ''
      while n < lim
        str << TYPE_EXTENDED + serialize(arr[n])
        n += 1
      end
      str
    end

    def serialize_float_thing(flt)
      str = ''
      mmath = Math 
      flt = mmath.modf(mmath.ldexp(mmath.frexp(flt.abs)[0], 37))[0]
      str << "\0" if flt > 0
      while flt > 0
        mod_arr = mmath.modf(mmath.ldexp(flt, 32))
        flt = mod_arr[0]
        n = mod_arr[1]
        n = n.to_i
        str << to_byte(n >> 24)
        str << to_byte(n >> 16)
        str << to_byte(n >> 8)
        str << to_byte(n & 0x7fffffff)
      end
      str.chop! while str[-1].equal?(0)
      str
    end

    def serialize_instance_variables_prefix(obj, ivars_result)
      # (... exclude_ivars = false)
      # ivars_result is Array of size 1, an output .
      #   ivars_result[0] will be second arg to serialize_instance_variables_suffix
      ivars = obj.instance_variables

      # ivars -= exclude_ivars if exclude_ivars

      ivars_result[0] = ivars
      if ivars.length > 0 then
        TYPE_IVAR
      else
        ''
      end
    end

    def serialize_instance_variables_suffix(obj, ivars)
      # (... , force = false, strip_ivars = false)
      len = ivars.length
      # if force or len > 0 then
      if len > 0 then
        str = serialize_integer( len )
        n = 0
        while n < len
          ivar = ivars[n]
          sym = ivar.to_sym
          val = obj.instance_variable_get(sym)

          #unless strip_ivars then
          #  str << serialize(sym)
          #else
          #  str << serialize(ivar[1..-1].to_sym)
          #end
          str << serialize(sym)

          str << serialize(val)
          n += 1
        end
        str
      else
        ''
      end
    end

    def serialize_integer(n)
      if n.equal?(0)
        s = to_byte(n)
      elsif n > 0 and n < 123
        s = to_byte(n + 5)
      elsif n < 0 and n > -124
        s = to_byte(256 + (n - 5))
      else
        s = "\0"
        cnt = 0
        for k in (1..4) do
          s << to_byte(n)
          n >>= 8
          cnt += 1
          break if n.equal?(0) or n.equal?(-1)
        end
        s[0] = to_byte(n < 0 ? 256 - cnt : cnt)
      end
      s
    end

    def serialize_user_class(obj, cls)
      if obj.class.equal?(cls)
        ''
      else
        TYPE_UCLASS + serialize(obj.class.name.to_sym)
      end
    end

    def serialize_user_defined(obj)
      str = obj._dump(@depth)
      raise TypeError, "_dump() must return string" if str.class != String
      ivars = [ nil ]
      out = serialize_instance_variables_prefix(str, ivars)
      out << TYPE_USERDEF + serialize(obj.class.name.to_sym)
      out << serialize_integer(str.length) + str
      out << serialize_instance_variables_suffix(str, ivars[0])
    end

    def serialize_user_marshal(obj)
      val = obj.marshal_dump

      add_output_obj val

      out = TYPE_USRMARSHAL + serialize(obj.class.name.to_sym)
      out << val.to_marshal(self)
    end

    def set_instance_variables(obj)
      special = obj.respond_to? :from_marshal
      for k in (1..construct_integer) do
        ivar = get_symbol
        value = construct
        if special
          obj.from_marshal(ivar, value)
        else
          obj.instance_variable_set prepare_ivar(ivar), value
        end
      end
    end

    def serialize_ivars(arr)
      siz = arr.size 
      str = serialize_integer( siz >> 1 )
      n = 0
      while n < siz 
        str << arr[n].to_marshal(self)
        str << arr[n + 1].to_marshal(self)
        n += 2 
      end
      str
    end

    def to_byte(n)
      [n].pack('C')
    end

  end  # ]

  def self.dump(obj, an_io=nil, limit=nil)
    if limit.equal?(nil)
      if an_io._isFixnum
        limit = an_io
        an_io = nil
      else
        limit = -1
      end
    end
    if limit.equal?(nil)
      depth = -1
    else
      depth = Type.coerce_to(limit, Fixnum, :to_int )
    end
    ms = State.new(nil, depth, nil)

    if an_io and !an_io.respond_to?(:write )
      raise TypeError, "output must respond to write"
    end

    str = VERSION_STRING + ms.serialize(obj)

    if an_io
      an_io.write(str)
      return an_io
    end

    return str
  end

  def self.load(obj, proc = nil)
    if obj.respond_to? :to_str
      data = obj.to_s
    elsif obj.respond_to? :read
      data = obj.read
      if data.empty?
        raise EOFError, "end of file reached"
      end
    elsif obj.respond_to? :getc  # FIXME - don't read all of it upfront
      data = ''
      data << c while (c = obj.getc.chr)
    else
      raise TypeError, "instance of IO needed"
    end

    major = data[0]
    minor = data[1]

    if major != MAJOR_VERSION or minor > MINOR_VERSION then
      raise TypeError, "incompatible marshal file format (can't be read)\n\tformat version #{MAJOR_VERSION}.#{MINOR_VERSION} required; #{major}.#{minor} given"
    end

    ms = State.new data, nil, proc
    ms.construct
  end

end

class Object
  # replicate some constants so code in marshal2.rb can resolve at boot compile
  Marshal__TYPE_OBJECT = Marshal::TYPE_OBJECT
  Marshal__TYPE_NIL = Marshal::TYPE_NIL
  Marshal__TYPE_TRUE = Marshal::TYPE_TRUE
  Marshal__TYPE_FALSE = Marshal::TYPE_FALSE
  Marshal__TYPE_CLASS = Marshal::TYPE_CLASS
  Marshal__TYPE_MODULE = Marshal::TYPE_MODULE
  Marshal__TYPE_SYMBOL = Marshal::TYPE_SYMBOL
  Marshal__TYPE_STRING = Marshal::TYPE_STRING
  Marshal__TYPE_FIXNUM = Marshal::TYPE_FIXNUM
  Marshal__TYPE_BIGNUM = Marshal::TYPE_BIGNUM
  Marshal__TYPE_REGEXP = Marshal::TYPE_REGEXP 
  Marshal__TYPE_STRUCT = Marshal::TYPE_STRUCT 
  Marshal__TYPE_ARRAY = Marshal::TYPE_ARRAY
  Marshal__TYPE_HASH_DEF = Marshal::TYPE_HASH_DEF
  Marshal__TYPE_HASH = Marshal::TYPE_HASH
  Marshal__TYPE_FLOAT = Marshal::TYPE_FLOAT
end


# optimization, code moved to common/marshal2.rb
#  so constants can be resolved during bootstrap compile
