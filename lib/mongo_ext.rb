module Mongo
  def self.oid(id)
    BSON::ObjectId(id.to_s)
  end

  class Collection
    def find_id(id)
      item = find_one(_id: Mongo.oid(id))
      raise Sinatra::NotFound if item.nil?
      item
    end
  end
end