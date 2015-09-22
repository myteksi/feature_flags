class FeatureFlags
  def initialize(redis, namespace, group_size = 100_000)
    @feature_flags = FeatureFlagsGeneral::FlagStorage.new(redis, namespace: namespace) do |rule|
      rule.key_generator = ->(type, feature, state, feature_key, feature_val) do
        parts = [feature_key, feature, state]
        parts << feature_val % group_size if state == :la
        parts.join('_'.freeze)
      end
    end

    @redis = redis
    @namespace = namespace
    @group_size = group_size
  end

  # cashless_live: [1, 2, 3] # cashless_beta: [4, 5, 6]
  def activate_city(feature:, city_id:, live: false)
    return if city_id.nil? || feature.nil?

    @feature_flags.set_global_feature(:city, city_id, feature.to_sym, live ? :live : :beta)
  end

  # Neither live / beta
  def deactivate_city(feature:, city_id:)
    return if feature.nil? || city_id.nil?

    @feature_flags.set_global_feature(:city, city_id, feature.to_sym, nil)
  end

  def city_state(feature:, city_id:)
    return nil if feature.nil? || city_id.nil?

    @feature_flags.global_feature(:city, city_id, feature.to_sym).to_s
  end

  # Returns a hash as follows { cashless: 'live', beta: nil, something: 'beta' }
  def city_features(city_id: , feature_list: [])
    @feature_flags.global_features(:city, city_id, feature_list.map(&:to_sym))
  end

  # deprecated, should be whitelist_user, blacklist_user
  def activate_user(feature:, city_id:, id:)
    # @feature_flags.set_local_feature(:user, id, feature.to_sym, :whitelist)
    # @feature_flags.set_local_feature(:user, id, feature.to_sym, :blacklist)

    if city_beta?(feature: feature, city_id: city_id)
      @redis.sadd(whitelist_user_key(feature), id)
      @redis.srem(blacklist_user_key(feature, id), id)
    else
      @redis.srem(blacklist_user_key(feature, id), id)
      @redis.srem(whitelist_user_key(feature), id)
    end
  end

  # deprecated, should remove user from all lists
  def deactivate_user(feature:, id:)
    # @feature_flags.set_local_feature(:user, id, feature.to_sym, nil)

    @redis.sadd(blacklist_user_key(feature, id), id)
    @redis.srem(whitelist_user_key(feature), id)
  end

  def user_active_in_city?(feature:, city_id:, id:)
    return false if feature.nil? || city_id.nil? || id.nil?

    @feature_flags.feature?(:city, city_id, :user, id, feature.to_sym)
  end

  # return of :whitelist, :blacklist, nil
  def user_state(feature:, id:)
    @feature_flags.local_feature(:user, id, feature.to_sym).to_s
  end

  # Returns a hash as follows { cashless: 'live', beta: nil, something: 'beta' }
  def user_features(id:, city_id:, feature_list: [])
    @feature_flags.local_features(:user, id, feature_list.map(&:to_sym))
  end

  private

  def city_live?(feature:, city_id:)
   @redis.sismember(live_features_key(feature), city_id)
  end

  def city_beta?(feature:, city_id:)
    @redis.sismember(beta_features_key(feature), city_id)
  end

  def live_features_key(feature)
    "#{@namespace}_city_#{feature}_live"
  end

  def beta_features_key(feature)
    "#{@namespace}_city_#{feature}_beta"
  end

  def blacklist_user_key(feature, id)
    "#{@namespace}_user_#{feature}_blacklist_#{id / @group_size}"
  end

  def whitelist_user_key(feature)
    "#{@namespace}_user_#{feature}_whitelist"
  end
end
