# frozen_string_literal: true

FactoryBot.define do
  factory :post do
    user
    title { Faker::Book.title }
    sequence(:slug) { |n| "#{Faker::Internet.slug}-#{n}" }
    subtitle { Faker::Lorem.sentence }
    description_uk { "<p>#{Faker::Lorem.sentence}</p>" }
    description_en { "<p>#{Faker::Lorem.sentence}</p>" }
    photo do
      Rack::Test::UploadedFile.new(File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')))
    end
    status { :active }
    main_post { false }

    trait :main_post do
      main_post { true }
    end

    trait :inactive do
      status { :inactive }
    end

    trait :with_tag do
      after(:create) do |post|
        post.tags << create(:tag)
      end
    end
  end
end
