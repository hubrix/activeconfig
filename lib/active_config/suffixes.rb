class ActiveConfig
  class Suffixes
    attr_writer :priority
    attr_writer :parent
    attr :symbols
    def overlay= new_overlay
      @parent._flush_cache
      @symbols[:overlay]=(new_overlay.respond_to?(:upcase) ? new_overlay.upcase : new_overlay)
    end
    def initialize(*args)
      @parent=args.shift
      @symbols=HashWithIndifferentAccess.new
      @symbols[:hostname]=proc {|sym_table| ENV['ACTIVE_CONFIG_HOSTNAME'] ||
       Socket.gethostname
      } 
      @symbols[:hostname_short]=proc {|sym_table| sym_table[:hostname].call.sub(/\..*$/, '').freeze}
      @symbols[:mode]=proc { |sym_table|return RAILS_ENV if defined?(RAILS_ENV)}
      @symbols[:overlay]=proc { |sym_table| ENV['ACTIVE_CONFIG_OVERLAY']}
      @priority=[
       nil,
       [:overlay, nil],
       [:local],
       [:overlay, [:local]],
       :config,
       [:overlay, :config],
       :local_config,
       [:overlay, :local_config],
       :hostname,
       [:overlay, :hostname],
       [:hostname, :local_config],
       [:overlay, [:hostname, :local_config]]
      ]
    end
    def method_missing method, val=nil 
      super if method.to_s=~/^_/
      if method.to_s=~/^(.*)=$/
        @parent._flush_cache
        return @symbols[$1]=val
      end      
      ret=@symbols[method]
      if ret 
        return ret.call(@symbols) if ret.respond_to?(:call)
        return ret
      end
      super
    end
    def for file
      suffixes.map { |this_suffix| [file,*this_suffix].compact.join('_')}.compact.uniq
    end
    def suffixes ary=@priority
      ary.map{|e|
        if Array===e
          t=self.suffixes(e).compact
          t.size > 0 ? t.join('_') : nil
        elsif @symbols[e]
          method_missing(e)
        else
          e && e.to_s
        end
      }
    end
    def file fname
      suffixes.map{|m|m="#{m}" if m
"#{fname}#{m}.yml"
}
    end
  end
end