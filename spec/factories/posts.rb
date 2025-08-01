FactoryBot.define do
  factory :post do
    association :user
    
    title { Faker::Lorem.sentence(word_count: 4, supplemental: false, random_words_to_add: 2) }
    
    # Use a more realistic content structure
    content do
      paragraphs = Array.new(rand(3..7)) do
        Faker::Lorem.paragraph(sentence_count: rand(3..6), supplemental: false, random_sentences_to_add: 2)
      end
      
      # Sometimes add headings and lists
      if rand < 0.3
        paragraphs.insert(rand(paragraphs.length), "## #{Faker::Lorem.sentence(word_count: 3)}")
      end
      
      if rand < 0.2
        list_items = Array.new(rand(3..5)) { "- #{Faker::Lorem.sentence(word_count: rand(5..10))}" }
        paragraphs.insert(rand(paragraphs.length), list_items.join("\n"))
      end
      
      paragraphs.join("\n\n")
    end
    
    status { :draft }
    created_at { rand(1.month.ago..1.week.ago) }
    updated_at { rand(created_at..Time.current) }

    trait :draft do
      status { :draft }
      published_at { nil }
      bluesky_uri { nil }
    end

    trait :published do
      status { :published }
      published_at { rand(1.week.ago..Time.current) }
      bluesky_uri { "at://did:plc:#{SecureRandom.alphanumeric(22)}/com.whtwnd.blog.entry/#{SecureRandom.alphanumeric(13)}" }
    end

    trait :archived do
      status { :archived }
      published_at { rand(1.month.ago..1.week.ago) }
    end

    trait :failed do
      status { :failed }
      published_at { nil }
      bluesky_uri { nil }
    end

    trait :short do
      content { Faker::Lorem.paragraph(sentence_count: 2) }
    end

    trait :long do
      content do
        Array.new(15) do
          Faker::Lorem.paragraph(sentence_count: rand(4..8), supplemental: false, random_sentences_to_add: 3)
        end.join("\n\n")
      end
    end

    trait :with_rich_content do
      content do
        <<~CONTENT
          # #{Faker::Lorem.sentence(word_count: 4)}

          #{Faker::Lorem.paragraph(sentence_count: 4)}

          ## Key Points

          - #{Faker::Lorem.sentence}
          - #{Faker::Lorem.sentence}
          - #{Faker::Lorem.sentence}

          #{Faker::Lorem.paragraph(sentence_count: 6)}

          > #{Faker::Lorem.sentence(word_count: 12)}

          #{Faker::Lorem.paragraph(sentence_count: 3)}

          ```ruby
          def example_method
            puts "Hello, World!"
          end
          ```

          #{Faker::Lorem.paragraph(sentence_count: 4)}
        CONTENT
      end
    end

    trait :recent do
      created_at { rand(1.day.ago..Time.current) }
      updated_at { created_at + rand(1.hour) }
    end

    trait :old do
      created_at { rand(6.months.ago..1.month.ago) }
      updated_at { created_at + rand(1.week) }
    end
  end
end
