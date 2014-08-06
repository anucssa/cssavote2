require 'sinatra'
require 'redis'
require 'json'

redis = Redis.new

get('/admin/candidates') do
  content_type 'text/json'

  payload = redis.smembers("candidates").map do |uid|
    {
      id: uid,
      elections: redis.smembers("election:#{uid}")
    }.merge(redis.hgetall("candidate:#{uid}"))
  end

  JSON.generate(payload)
end

post('/admin/candidates') do
  input = JSON.parse(request.body.read)
  input.each {|n| return 500 unless n.id }

  # Clear out the current candidates
  redis.smembers("candidates").each do |n|
    redis.del("candidate:#{n}")
    redis.del("election:#{n}")
  end
  redis.del("candidates")

  input.each {|n| redis.sadd("candidates", n.id) }
  input.each do |n|
    redis.hmset("candidate:#{n.id}", "name", n.name)
    n.elections.each {|e| redis.sadd("election:#{n.id}", e) }
  end
end

get('/admin/elections') do
end

post('/admin/elections') do
end

get('/admin/votingcodes') do
end

get('/admin/votingcodes/more') do
end

post('/admin/votingcodes') do
end

post('/votingcode') do
end

get('/elections') do
end

post('/votes') do
end