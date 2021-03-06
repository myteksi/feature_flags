require 'spec_helper'

describe "FeatureFlags" do
  before do
    @redis   = Redis.new
    @feature_flags = FeatureFlags.new(@redis, 'test') # Default group_size 100_000
  end

  describe '#activate_city' do
    it 'adds the city id to the live features set if live is passed as true' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)
      expect(@redis.sismember('test_city_cashless_live', 1)).to be true
      expect(@redis.sismember('test_city_cashless_beta', 1)).to be false
    end

    it 'adds the city id to the beta features set if live is passed as false' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: false)
      expect(@redis.sismember('test_city_cashless_beta', 1)).to be true
      expect(@redis.sismember('test_city_cashless_live', 1)).to be false
    end

    it 'if nil city id is passed in it does not do anything' do
      @feature_flags.activate_city(feature: :cashless, city_id: nil, live: false)
      expect(@redis.sismember('test_city_cashless_beta', 1)).to be false
      expect(@redis.sismember('test_city_cashless_live', 1)).to be false
    end

    it 'if nil feature is passed in it does not do anything' do
      @feature_flags.activate_city(feature: nil, city_id: 1, live: false)
      expect(@redis.sismember('test_city_cashless_beta', 1)).to be false
      expect(@redis.sismember('test_city_cashless_live', 1)).to be false
    end
  end

  describe '#deactivate_city' do
    before { @redis.sadd('test_city_cashless_live', 1) }

    it 'removes the city from both the live set and the beta set' do
      @feature_flags.deactivate_city(feature: :cashless, city_id: 1)
      expect(@redis.sismember('test_city_cashless_live', 1)).to be false
    end
  end

  describe '#city_state' do
    it 'returns false when feature is nil' do
      expect(@feature_flags.city_state(feature: nil, city_id: 1)).to be_nil
    end

    it 'returns false when city_id is nil' do
      expect(@feature_flags.city_state(feature: :cashless, city_id: nil)).to be_nil
    end

    it 'returns false for a feature that does not exist' do
      expect(@feature_flags.city_state(feature: :not_exist, city_id: 1)).to eq('inactive')
    end

    it 'returns "live" when feature is live in that city' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)

      expect(@feature_flags.city_state(feature: :cashless, city_id: 1)).to eq('live')
    end

    it 'returns "beta" when feature is in beta in that city' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: false)

      expect(@feature_flags.city_state(feature: :cashless, city_id: 1)).to eq('beta')
    end
  end

  describe '#city_features' do
    it 'returns an empty hash if no feature list is provided' do
      expect(@feature_flags.city_features(city_id: 1)).to eq({})
    end

    it 'returns nil for features that are specified but do not exist' do
      expect(@feature_flags.city_features(city_id: 1, feature_list: [:cashless])).to eq({ cashless: nil })
    end

    it 'returns beta for beta features' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1)
      expect(@feature_flags.city_features(city_id: 1, feature_list: [:cashless])).to eq({ cashless: 'beta' })
    end

    it 'returns live for live features' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)
      expect(@feature_flags.city_features(city_id: 1, feature_list: [:cashless])).to eq({ cashless: 'live' })
    end
  end

  describe '#activate_user' do
    it 'does not add the user to any list if city is live' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)
      @feature_flags.activate_user(feature: :cashless, city_id: 1, id: 123_456)

      expect(@redis.sismember('test_user_cashless_blacklist_1', 123_456)).to be false
      expect(@redis.sismember('test_user_cashless_whitelist', 123_456)).to be false
    end

    it 'adds the user to the whitelist if city is beta' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: false)
      @feature_flags.deactivate_user(feature: :cashless, id: 234_567)
      expect(@redis.sismember('test_user_cashless_blacklist_2', 234_567)).to be true
      expect(@redis.sismember('test_user_cashless_whitelist', 234_567)).to be false

      @feature_flags.activate_user(feature: :cashless, city_id: 1, id: 234_567)
      expect(@redis.sismember('test_user_cashless_blacklist_2', 234_567)).to be false
      expect(@redis.sismember('test_user_cashless_whitelist', 234_567)).to be true
    end

    it 'removes user from both lists if city is off or feature not exist' do
      @feature_flags.deactivate_city(feature: :cashless, city_id: 1)

      expect(@redis).to receive(:srem).exactly(:twice)
      expect(@redis).not_to receive(:sadd)

      @feature_flags.activate_user(feature: :cashless, city_id: 1, id: 345_678)
      expect(@redis.sismember('test_user_cashless_blacklist_1', 345_678)).to be false
      expect(@redis.sismember('test_user_cashless_whitelist', 345_678)).to be false
    end
  end

  describe '#deactivate_user' do
    it 'adds the user to the blacklist and remove it from the whitelist' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: false)
      @feature_flags.activate_user(feature: :cashless, city_id: 1, id: 567_890)
      expect(@redis.sismember('test_user_cashless_whitelist', 567_890)).to be true

      @feature_flags.deactivate_user(feature: :cashless, id: 567_890)

      expect(@redis.sismember('test_user_cashless_blacklist_5', 567_890)).to be true
      expect(@redis.sismember('test_user_cashless_whitelist', 567_890)).to be false
    end
  end

  describe '#user_active_in_city?' do
    it 'returns false when feature is nil' do
      expect(@feature_flags.user_active_in_city?(feature: nil, city_id: 1, id: 1)).to be false
    end

    it 'returns false when city_id is nil' do
      expect(@feature_flags.user_active_in_city?(feature: :cashless, city_id: nil, id: 1)).to be false
    end

    it 'returns false when id is nil' do
      expect(@feature_flags.user_active_in_city?(feature: :cashless, city_id: 1, id: nil)).to be false
    end

    it 'returns false for a feature that does not exist' do
      expect(@feature_flags.user_active_in_city?(feature: :not_exist, city_id: 1, id: 1)).to be false
    end

    it 'returns false when blacklisted for a feature which is live' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)
      @redis.sadd('test_user_cashless_blacklist_7', 789_012)

      expect(@feature_flags.user_active_in_city?(feature: :cashless, city_id: 1, id: 789_012)).to be false
    end

    it 'returns false when not whitelisted for a feature which is in beta' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: false)
      @redis.srem('test_user_cashless_whitelist', 1)

      expect(@feature_flags.user_active_in_city?(feature: :cashless, city_id: 1, id: 1)).to be false
    end

    it 'returns true when whitelisted for a feature which is beta' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: false)
      @redis.sadd('test_user_cashless_whitelist', 1)

      expect(@feature_flags.user_active_in_city?(feature: :cashless, city_id: 1, id: 1)).to be true
    end

    it 'returns true when not blacklisted for a feature which is live' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)
      @redis.srem('test_user_cashless_blacklist_8', 890_123)

      expect(@feature_flags.user_active_in_city?(feature: :cashless, city_id: 1, id: 890_123)).to be true
    end
  end

  describe '#user_state' do
    it 'returns nil when feature is nil' do
      expect(@feature_flags.user_state(feature: nil, id: 1)).to eq(nil)
    end

    it 'returns nil when id is nil' do
      expect(@feature_flags.user_state(feature: :cashless, id: nil)).to eq(nil)
    end

    it 'returns "live" when feature is live for the user' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)
      @feature_flags.activate_user(feature: :cashless, city_id: 1, id: 1)
      expect(@feature_flags.user_state(feature: :cashless, id: 1)).to eq('live')
    end

    it 'returns "beta" when feature is beta for the user' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: false)
      @feature_flags.activate_user(feature: :cashless, city_id: 1, id: 1)
      expect(@feature_flags.user_state(feature: :cashless, id: 1)).to eq('beta')
    end

    it 'returns "inactive" when feature is disabled for the user' do
      @feature_flags.deactivate_user(feature: :cashless, id: 1)
      expect(@feature_flags.user_state(feature: :cashless, id: 1)).to eq('inactive')
    end
  end

  describe '#user_features' do
    it 'returns an empty hash if no feature list is provided' do
      expect(@feature_flags.user_features(id: 1, city_id: 1)).to eq({})
    end

    it 'returns false for features that are specified but do not exist' do
      expect(@feature_flags.user_features(id: 1, city_id: 1, feature_list: [:not_exist])).to eq({ not_exist: false })
    end

    it 'returns true if the user is activated for the feature' do
      expect(@feature_flags).to receive(:user_active_in_city?).with(feature: :cashless, city_id: 1, id: 1).and_return true
      expect(@feature_flags.user_features(id: 1, city_id: 1, feature_list: [:cashless])).to eq({ cashless: true })
    end

    it 'returns false if the user is deactivated for the feature' do
      expect(@feature_flags).to receive(:user_active_in_city?).with(feature: :cashless, city_id: 1, id: 1).and_return false
      expect(@feature_flags.user_features(id: 1, city_id: 1, feature_list: [:cashless])).to eq({ cashless: false })
    end
  end
end
