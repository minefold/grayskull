$:.unshift File.expand_path('../lib', __FILE__)

require 'json'
require 'sinatra'
require 'bugsnag'
require 'mongo'
require 'snapshot'

if development?
  require 'sinatra/reloader'
  also_reload 'lib/snapshot.rb'
end

configure do
  $stdout.sync = true

  Bugsnag.configure do |config|
    config.api_key = ENV['BUGSNAG']
  end

  enable :raise_errors

  set :db, begin
    uri = ENV['MONGO_URL'] || 'mongodb://localhost:27017/minefold_development'
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
  (username == 'minefold' and password == 'carlsmum') or
  (username == 'foo' and password == 'bar') or
  (username == ENV['API_TOKEN'])
end

post '/servers' do
  id = BSON::ObjectId.new
  ts = Time.now

  if env['REMOTE_USER'] != 'foo'
    settings.db['servers'].insert(
      _id: id,
      created_at: ts,
      updated_at: ts
    )
  end

  content_type :json
  JSON.dump({id: id.to_s, created_at: ts, updated_at: ts})
end

# Arguments
#   count: optional, default is 10
#          A limit on the number of snapshots to be returned. Count can range between 1 and 100 snapshots.
#   offset: optional, default is 0
#          An offset into your snapshots array. The API will return the requested number of snapshots starting at that offset.
#   server: optional
#          Only return snapshots for the server specified by this server ID.

get '/snapshots' do
  content_type :json
  limit = (params[:count] || 10).to_i
  skip = (params[:offset] || 0).to_i

  snapshots = if params[:server]
    Snapshot.find_by_server(params[:server], skip, limit)
  else
    Snapshot.all(skip, limit)
  end

  json({
    object: 'list',
    url: env['REQUEST_PATH'],
    count: snapshots.size,
    data: snapshots.map{|s| {
      snapshot: Snapshot.to_h(s)
    }}
  })
end

delete '/snapshots/:id' do
  s = Snapshot.delete(params[:id])
  json(Snapshot.to_h(s))
end

def json(h)
  JSON.pretty_generate(h)
end

class Hash
  def slice(*keys)
    keys = keys.map! { |key| convert_key(key) } if respond_to?(:convert_key)
    hash = self.class.new
    keys.each { |k| hash[k] = self[k] if has_key?(k) }
    hash
  end
end