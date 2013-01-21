require 'json'
require 'sinatra'
require 'mongo'

configure do
  set :db, begin
    uri = ENV['MONGO_URL'] || 'mongodb://localhost:27017/grayskull_development'
    mongo = ::Mongo::Connection.from_uri(uri)

    if mongo.is_a? ::Mongo::MongoReplicaSetClient
      # this should be in the damn ruby driver
      mongo_uri = ::Mongo::URIParser.new(uri)
      auth = mongo_uri.auths.first

      db = mongo[auth['db_name']]
      db.authenticate auth['username'], auth['password']
      db
    else
      db_name = mongo.auths.any? ? mongo.auths.first['db_name'] : nil
      db_name ||= URI.parse(uri).path[1..-1]
      mongo[db_name]
    end
  end
end

use(Rack::Auth::Basic, 'Restricted Area') do |username, password|
  username == 'minefold' and password == 'carlsmum'
end

post '/servers' do
  id = BSON::ObjectId.new
  ts = Time.now

  settings.db['servers'].insert(
    _id: id,
    created_at: ts,
    updated_at: ts
  )

  content_type :json
  JSON.dump({id: id.to_s, created_at: ts, updated_at: ts})
end
