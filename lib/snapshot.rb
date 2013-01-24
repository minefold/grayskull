class Snapshot
  def self.all(skip, limit)
    settings.db['snapshots'].
      find.
      skip(skip).
      limit(limit).to_a
  end

  def self.find_by_server(server_id, skip, limit)
    e = SnapshotEnumerator.new(settings.db, server_id)
    e.take(skip)
    e.take(limit)
  end

  def self.oid(id)
    BSON::ObjectId(id.to_s)
  end
end

class SnapshotEnumerator
  include Enumerable

  def initialize(db, server_id)
    @db = db
    server = settings.db['servers'].
      find_one(_id: BSON::ObjectId(server_id.to_s))

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