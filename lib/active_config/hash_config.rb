class ActiveConfig
  class HashConfig < HashWithIndifferentAccess
    # HashWithIndifferentAccess#dup always returns HashWithIndifferentAccess!
    # -- kurt 2007/10/18
    def dup
      self.class.new(self)
    end


    # dotted notation can now be used with arguments (useful for creating mock objects)
    # in the YAML file the method name is a key (just like usual), argument(s)
    # form a nested key, and the value will get returned.
    #
    # For example loading to variable foo a yaml file that looks like:
    # customer:
    #   id: 12345678
    #   verified:
    #     phone: verified
    #     :address: info_not_available
    #     ? [name, employer]
    #     : not_verified
    # 
    # Allows the following calls:
    # foo.customer.id   --> 12345678
    # foo.customer.verified.phone  --> verified
    # foo.customer.verified("phone")  --> verified
    # foo.customer.verified("name", "employer")  --> not_verified
    # foo.customer.verified(:address) --> info_not_available
    #
    # Note that :address is specified as a symbol, where phone is just a string.
    # Depending on what kind of parameter the method being mocked out is going 
    # to be called with, define in the YAML file either a string or a symbol.  
    # This also works inside the composite array keys.
    def method_missing(method, *args)
      method = method.to_s
      # STDERR.puts "CHF#method_missing(#{method.inspect}, #{args.inspect}) on #{self.inspect}:#{self.class}" if method == 'dup'
      value = self[method]
      case args.size
        when 0:
          # e.g.: ActiveConfig.global.method
          ;
        when 1:
          # e.g.: ActiveConfig.global.method(one_arg)
          value = value.send(args[0])
        else
          # e.g.: ActiveConfig.global.method(arg_one, args_two, ...)
          value = value[args]
      end
      # value =  convert_value(value)
      value
    end
    
    ## 
    # Why the &*#^@*^&$ isn't HashWithIndifferentAccess actually doing this?
    #
    def [](key)
      key = key.to_s if key.kind_of?(Symbol)
      super(key)
    end

    # HashWithIndifferentAccess#default is broken!
    define_method(:default_Hash, Hash.instance_method(:default))

    ##
    # Allow hash.default => hash['default']
    # without breaking Hash's usage of default(key)
    #
    @@no_key = [ :no_key ] # magically unique value.
    def default(key = @@no_key)
      key = key.to_s if key.is_a?(Symbol)
      key == @@no_key ? self['default'] : default_Hash(key == @@no_key ? nil : key)
    end
    
    ## 
    # HashWithIndifferentAccess#update is broken!
    # This took way too long to figure this out:
    #
    # Hash#update returns self,
    # BUT,
    # HashWithIndifferentAccess#update does not!
    #
    #   { :a => 1 }.update({ :b => 2, :c => 3 }) 
    #   => { :a => 1, :b => 2, :c => 3 }
    #
    #   HashWithIndifferentAccess.new({ :a => 1 }).update({ :b => 2, :c => 3 })
    #   => { :b => 2, :c => 3 } # WTF?
    #
    # Subclasses should *never* override methods and break their protocols!!!!
    # -- kurt 2007/03/28
    #
    def update(hash)
      super(hash)
      self
    end

    ## 
    # Override WithIndifferentAccess#convert_value
    # return instances of this class for Hash values.
    #
    def convert_value(value)
      # STDERR.puts "convert_value(#{value.inspect}:#{value.class})"
      if value.class == Hash
        value = self.class.new(value)
        value.freeze if self.frozen?
      end
      value
    end
    
  end
end
