require 'spec_helper'

describe FeatureFlagsGeneral do
  let(:redis) { double() }

  subject { FeatureFlagsGeneral::FlagStorage.new(redis) }

  describe '#change_global_feature' do
    it 'updates feature at redis sets' do
      expect(redis).to receive(:srem).with('features_state_city_feature_beta', 9).once
      expect(redis).to receive(:sadd).with('features_state_city_feature_live', 9).once

      subject.change_global_feature(:city, 9, :feature, :live)
    end

    it 'removes feature from redis sets' do
      expect(redis).to receive(:srem).with('features_state_city_feature_beta', 9).once
      expect(redis).to receive(:srem).with('features_state_city_feature_live', 9).once

      subject.change_global_feature(:city, 9, :feature, nil)
    end
  end

  describe '#global_feature' do
    it 'returns feature state :beta' do
      expect(redis).to receive(:sismember).with('features_state_city_feature_beta', 9).and_return(true)

      expect(subject.global_feature(:city, 9, :feature)).to be(:beta)
    end

    it 'return feature state nil' do
      expect(redis).to receive(:sismember).with('features_state_city_feature_beta', 9).and_return(false)
      expect(redis).to receive(:sismember).with('features_state_city_feature_live', 9).and_return(false)

      expect(subject.global_feature(:city, 9, :feature)).to be(nil)
    end
  end

  describe '#global_features' do
    it 'returns feature states in hash' do
      expect(redis).to receive(:sismember).with('features_state_city_featureA_beta', 9).and_return(false)
      expect(redis).to receive(:sismember).with('features_state_city_featureA_live', 9).and_return(false)
      expect(redis).to receive(:sismember).with('features_state_city_featureB_beta', 9).and_return(false)
      expect(redis).to receive(:sismember).with('features_state_city_featureB_live', 9).and_return(true)

      expect(subject.global_features(:city, 9, [:featureA, :featureB])).to match({ featureA: nil, featureB: :live })
    end
  end

  describe '#change_local_feature' do
    it 'updates feature at redis sets' do
      expect(redis).to receive(:srem).with('features_list_user_feature_whitelist', 9).once
      expect(redis).to receive(:sadd).with('features_list_user_feature_blacklist', 9).once

      subject.change_local_feature(:user, 9, :feature, :blacklist)
    end

    it 'removes feature from redis sets' do
      expect(redis).to receive(:srem).with('features_list_user_feature_whitelist', 9).once
      expect(redis).to receive(:srem).with('features_list_user_feature_blacklist', 9).once

      subject.change_local_feature(:user, 9, :feature, nil)
    end
  end

  describe '#local_feature' do
    it 'returns feature list :whitelist' do
      expect(redis).to receive(:sismember).with('features_list_user_feature_whitelist', 9).and_return(true)

      expect(subject.local_feature(:user, 9, :feature)).to be(:whitelist)
    end

    it 'return feature list nil' do
      expect(redis).to receive(:sismember).with('features_list_user_feature_whitelist', 9).and_return(false)
      expect(redis).to receive(:sismember).with('features_list_user_feature_blacklist', 9).and_return(false)

      expect(subject.local_feature(:user, 9, :feature)).to be(nil)
    end
  end

  describe '#local_features' do
    it 'returns feature lists in hash' do
      expect(redis).to receive(:sismember).with('features_list_user_featureA_whitelist', 9).and_return(false)
      expect(redis).to receive(:sismember).with('features_list_user_featureA_blacklist', 9).and_return(false)
      expect(redis).to receive(:sismember).with('features_list_user_featureB_whitelist', 9).and_return(false)
      expect(redis).to receive(:sismember).with('features_list_user_featureB_blacklist', 9).and_return(true)

      expect(subject.local_features(:user, 9, [:featureA, :featureB])).to match({ featureA: nil, featureB: :blacklist })
    end
  end

  describe '#feature?' do
    shared_examples 'state_list_feature_on?' do |state, list, feature_on|
      it "returns #{feature_on}" do
        expect(subject.global_feature(:city, 1, :feature)).to be(state)
        expect(subject.local_feature(:user, 9, :feature)).to be(list)
        expect(subject.feature?(:city, 1, :user, 9, :feature)).to be(feature_on)
      end
    end

    before { allow(redis).to receive(:sismember).and_return(false) }

    context 'nil + nil' do
      it_behaves_like 'state_list_feature_on?', nil, nil, false
    end

    context 'beta + whitelist' do
      before do
        allow(redis).to receive(:sismember).with('features_state_city_feature_beta', 1).and_return(true)
        allow(redis).to receive(:sismember).with('features_list_user_feature_whitelist', 9).and_return(true)
      end

      it_behaves_like 'state_list_feature_on?', :beta, :whitelist, true
    end

    context 'beta + nil' do
      before do
        allow(redis).to receive(:sismember).with('features_state_city_feature_beta', 1).and_return(true)
      end

      it_behaves_like 'state_list_feature_on?', :beta, nil, false
    end

    context 'live + !blacklist' do
      before do
        allow(redis).to receive(:sismember).with('features_state_city_feature_live', 1).and_return(true)
      end

      it_behaves_like 'state_list_feature_on?', :live, nil, true
    end

    context 'live + blacklist' do
      before do
        allow(redis).to receive(:sismember).with('features_state_city_feature_live', 1).and_return(true)
        allow(redis).to receive(:sismember).with('features_list_user_feature_blacklist', 9).and_return(true)
      end

      it_behaves_like 'state_list_feature_on?', :live, :blacklist, false
    end
  end

  describe 'features?' do
    it 'returns features? in hash' do
      allow(redis).to receive(:sismember).and_return(false)

      expect(subject.features?(:city, 1, :user, 9, [:feature, :feature_B])).to match({
        feature: false, feature_B: false })
    end
  end

  context 'customize rules' do
    subject do
      $feature_flags = FeatureFlagsGeneral::FlagStorage.new(redis, namespace: 'flags') do |rule|
        rule.states = %i(sa sb sc)
        rule.lists = %i(la lb lc)

        rule.feature_checker = ->(state, list) do
          return true if :sa == state && :la == list
          false
        end

        rule.key_generator = ->(type, feature_key, feature, state, feature_val) do
          parts = [feature_key, feature, state]
          parts << feature_val % 5 if state == :la
          parts.join('_'.freeze)
        end
      end
    end

    before { allow(redis).to receive(:sismember).and_return(false) }

    it 'returns feature? false' do
      expect(subject.feature?(:city, 1, :user, 9, :feature)).to be(false)
    end

    it 'returns feature? true' do
      allow(redis).to receive(:sismember).with('flags_city_feature_sa', 1).and_return(true)
      allow(redis).to receive(:sismember).with('flags_user_feature_la_4', 9).and_return(true)

      expect(subject.feature?(:city, 1, :user, 9, :feature)).to be(true)
    end
  end
end
