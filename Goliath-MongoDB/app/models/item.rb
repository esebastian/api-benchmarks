require 'digest/sha1'
require 'securerandom'
require 'faker'

class Item
  include Mongoid::Document
  include Mongoid::Timestamps

  RANDOM_SEGMENT_SIZE = 100

  field :name, type: String
  field :uuid, type: String
  field :hc, as: :hash_code, type: String
  field :desc, as: :description, type: String

  field :r, as: :randomizer, type: Integer

  index({ uuid: 1 }, { unique: true, name: "uuid_index" })
  index({ r: 1 }, { unique: false, name: "randomizer_index" })

  index({ uuid: 1, r: 1 }, { unique: true, name: "uuid_randomizer_index" })

  validates :name, presence: true
  validates :uuid, presence: true
  validates :hash_code, presence: true
  validates :description, presence: true

  # translates :name, :description

  before_validation(:on => :create) do
    assign_uuid
    generate_hash_code
  end

  def assign_uuid
    self.uuid = SecureRandom.uuid
  end

  def generate_hash_code
    self.hash_code = Digest::SHA1.hexdigest "#{name}-#{uuid}-#{Time.now.to_f}"
  end


  class << self
    # this generates 1 million records for benchmarking
    def generate_million
      count = 1_000_000
      puts "Generating #{count} items..."
      count.times do |n|
        name = Faker::Company.bs.titleize
        # this will create a randomized segment space of 10,000 integers (0..9999)
        # when indexed, this ensures that we are randomly selecting inside a sub-set of
        #   only 100 records whenever we do a .random(), instead of scanning 1mil records
        randomizer = n % (count / RANDOM_SEGMENT_SIZE)
        puts "#{n} (r: #{randomizer}) / #{name}"
        i = Item.create({
          randomizer: randomizer,
          name: name,
          description: Faker::Lorem.paragraph
          })
        puts "... #{i ? 'saved.' : 'FAIL'}"
      end
    end


    # attempt at a reasonably-performant way to randomly pick a single record
    # without resorting to a nasty full scan of a millon records
    # CAVEAT EMPTOR: 
    #   with a lot of gaps in the randomizer sequence, this becomes less uniformly random
    def random
      coll = self.to_s.tableize
      r = rand(RANDOM_SEGMENT_SIZE)
      # not using mongoid for this; mongoid cannot yet support EM concurrency
      set_size = $moped[coll].find(r: r).count
      h = $moped[coll].find(r: r).skip(rand(RANDOM_SEGMENT_SIZE)).limit(-1).first
      Item.new(h)
    end
  end

end