require 'spec_helper'

describe "Compatibility" do
  before do
    @redis = Redis.new
    @feature_flags = FeatureFlags.new(@redis, 'test') # Default group_size 100_000
    @feature_flags_general = FeatureFlagsGeneral::FlagStorage.new(@redis, namespace: 'test') do |rule|
      rule.key_generator = ->(type, feature, state, feature_key, feature_val) do
        parts = [feature_key, feature, state]
        parts << feature_val / 100_000 if state == :blacklist
        parts.join('_'.freeze)
      end
    end
  end

  context 'city' do
    it 'can read each other city' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)
      expect(@feature_flags_general.global_feature(:city, 1, :cashless)).to be(:live)

      @feature_flags_general.set_global_feature(:city, 1, :cashless, :beta)
      expect(@feature_flags.city_state(feature: :cashless, city_id: 1)).to eq('beta')
    end

    it 'can deactivate each other city' do
      @feature_flags.deactivate_city(feature: :cashless, city_id: 1)
      expect(@feature_flags_general.global_feature(:city, 1, :cashless)).to be(nil)
      expect(@feature_flags_general.global_features(:city, 1, [:cashless])).to match({ cashless: nil })
      expect(@feature_flags.city_features(city_id: 1, feature_list: [:cashless])).to match({ cashless: nil })

      @feature_flags_general.set_global_feature(:city, 1, :cashless, :live)
      expect(@feature_flags.city_state(feature: :cashless, city_id: 1)).to eq('live')
      expect(@feature_flags.city_features(city_id: 1, feature_list: [:cashless])).to match({ cashless: 'live' })
      expect(@feature_flags_general.global_features(:city, 1, [:cashless])).to match({ cashless: :live })
    end
  end

  context 'user' do
    it 'can read active' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: true)
      @feature_flags.activate_user(feature: :cashless, city_id: 1, id: 1)

      expect(@feature_flags.user_active_in_city?(feature: :cashless, city_id: 1, id: 1)).to be(true)
      expect(@feature_flags_general.feature?(:city, 1, :user, 1, :cashless)).to be(true)

      expect(@feature_flags.user_state(feature: :cashless, id: 1)).to eq('live')
      expect(@feature_flags_general.local_feature(:user, 1, :cashless)).to be(nil)
    end

    it 'can read not active' do
      @feature_flags.activate_city(feature: :cashless, city_id: 1, live: false)
      @feature_flags.deactivate_user(feature: :cashless, id: 1)

      expect(@feature_flags.user_active_in_city?(feature: :cashless, city_id: 1, id: 1)).to be(false)
      expect(@feature_flags_general.feature?(:city, 1, :user, 1, :cashless)).to be(false)

      expect(@feature_flags.user_state(feature: :cashless, id: 1)).to eq('inactive')
      expect(@feature_flags_general.local_feature(:user, 1, :cashless)).to be(:blacklist)
    end
  end
end

