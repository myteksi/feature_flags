module FeatureFlagsGeneral
  # features = FlagAccessor.new(storage, :user, features: features, global_key: :city)
  # features.cashless? #=> :whitelist
  # features.cachless_in_city?(city_id) #=> true
  class FlagAccessor
    def initialize(storage, key, value, features:, global_key: nil)
      @storage = storage
      @key = key
      @value = value
      @features = features
      @global_key = global_key
    end

    def feature(name)
      if @global_key.nil?
        @storage.global_feature(@key, @value, name.to_sym)
      else
        @storage.local_feature(@key, @value, name.to_sym)
      end
    end

    def features
      if @global_key.nil?
        @storage.global_features(@key, @val, @features)
      else
        @storage.local_features(@key, @val, @features)
      end
    end

    def set_feature(name, to_state)
      if @global_key.nil?
        @storage.set_global_feature(@key, @value, name.to_sym, to_state)
      else
        @storage.set_local_feature(@key, @value, name.to_sym, to_state)
      end
    end

    def feature_in?(name, global_val)
      raise ArgumentError.new('@global_key not specified') if @global_key.nil?
      @storage.feature?(@global_key, global_val, @key, @value, name)
    end

    def features_in?(global_val)
      raise ArgumentError.new('@global_key not specified') if @global_key.nil?
      @storage.features?(@global_key, global_val, @key, @value, @features)
    end

    def method_missing(method_name, *args, &block)
      if !@global_key.nil? && method_name.to_s =~ /^(\w+)_in_#{@global_key}\?$/
        return features_in?(args[0]) if $1 == 'features'.freeze
        return feature_in?($1, args[0]) if @features.include?($1.to_sym)
      elsif method_name.to_s =~ /^(\w+)\?$/
        return feature($1) if @features.include?($1.to_sym)
      elsif method_name.to_s =~ /^(\w+)\=$/
        return set_feature($1, args[0]) if @features.include?($1.to_sym)
      end

      super
    end

    def respond_to_missing?(method_name, include_private = false)
      if !@global_key.nil? && method_name.to_s =~ /^(\w+)_in_#{@global_key}\?$/
        return $1 == 'features'.freeze || @features.include?($1.to_sym)
      elsif method_name.to_s =~ /^(\w+)[\?\=]$/
        return @features.include?($1.to_sym)
      end

      super
    end
  end
end
