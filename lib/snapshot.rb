require 'mongo_ext'

class Snapshot
  def self.all(skip, limit)
    snapshots.find.skip(skip).limit(limit).to_a
  end

  def self.find_by_server(server_id, skip, limit)
    e = SnapshotEnumerator.new(server_id)
    e.take(skip)
    e.take(limit)
  end

  def self.delete(id)
    snapshot = snapshots.find_id(id)
    child = snapshots.find_one('parent' => Mongo.oid(id))

    if child
      snapshots.update(
        { _id: child['_id'] }, {
          '$set' => { 'parent' => snapshot['parent']
        }
      })
    end

    snapshots.remove(_id: snapshot['_id'])
    snapshot
  end

  def self.snapshots
    settings.db['snapshots']
  end

  def self.to_h(s)
    {
      id: s['_id'].to_s,
    }.merge(s.slice('url', 'size', 'created_at'))
  end
end

class SnapshotEnumerator
  include Enumerable

  def initialize(server_id)
    server = settings.db['servers'].find_id(server_id)
    @snapshot_id = server['snapshot_id']
  end

  def each
    while not @snapshot_id.nil?
      snapshot = settings.db['snapshots'].find_one(_id: @snapshot_id)
      @snapshot_id = snapshot['parent']
      yield snapshot
    end
  end
end