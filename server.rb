require 'sinatra'
require 'redis'
require 'json'

$redis = Redis.new

def candidates_for(election)
  candidates = $redis.smembers("candidates").map do |n|
    { uid: n,
      name: $redis.hget("candidate:#{n}", "name"),
      elections: $redis.smembers("election:#{n}")
    }
  end

  candidates.delete_if do |i|
    not i[:elections].include?(election)
  end

  candidates.map! do |i|
    i.delete("elections")
    i
  end

  candidates
end

before '/admin/*' do
  if params["token"] != ENV["AUTH_TOKEN"]
    status 403
    halt
  end
end

get('/admin/candidates') do
  content_type 'text/json'

  payload = $redis.smembers("candidates").map do |uid|
    {
      id: uid,
      elections: $redis.smembers("election:#{uid}")
    }.merge($redis.hgetall("candidate:#{uid}"))
  end

  JSON.generate(payload)
end

post('/admin/candidates') do
  input = JSON.parse(request.body.read)
  input.each {|n| return 500 unless n["id"] }

  # Clear out the current candidates
  $redis.smembers("candidates").each do |n|
    $redis.del("candidate:#{n}")
    $redis.del("election:#{n}")
  end
  $redis.del("candidates")

  input.each {|n| $redis.sadd("candidates", n["id"]) }
  input.each do |n|
    $redis.hmset("candidate:#{n["id"]}", "name", n["name"])
    n["elections"].each {|e| $redis.sadd("election:#{n["id"]}", e) }
  end

  200
end

get('/admin/elections') do
  content_type 'text/json'

  payload = $redis.smembers("elections").map do |election|
    {name: election}.merge($redis.hgetall("election:#{election}"))
  end

  JSON.generate(payload)
end

post('/admin/elections') do
  input = JSON.parse(request.body.read)

  input.each do |election|
    $redis.sadd("elections", election["name"])
    $redis.hmset("election:#{election["name"]}",
      "positions", election["positions"]
    )
  end

  200
end

get('/admin/votingcodes') do
  content_type 'text/json'

  payload = $redis.smembers("votingcodes").map do |code|
    info = $redis.hgetall("votingcode:#{code}")
    {
      code: code,
      used: info["used"],
      new:  info["new"]
    }
  end

  JSON.generate(payload)
end

get('/admin/votingcodes/more') do

  input = $redis.get("votingcode_increment").to_i

  $redis.set("votingcode_increment", 0) unless input

  10.times do
    code = (Digest::SHA2.new() << input.to_s + Time.now.to_s).to_s.slice(0,7)
    $redis.sadd("votingcodes", code)
    $redis.hmset("votingcode:#{code}",
      "code", code,
      "token", nil,
      "used", false,
      "new", true
    )
    input += 1
  end

  $redis.set("votingcode_increment", input)

  200
end

post('/admin/votingcodes') do
  input = JSON.parse(request.body.read)

  input.each do |n|
    $redis.sadd("votingcodes", n["code"])
    $redis.hmset("votingcode:#{n["code"]}",
      "code", n["code"],
      "used", n["used"],
      "new",  n["new"]
    )
  end

  200
end

post('/votingcode') do
  content_type 'text/json'

  input = JSON.parse(request.body.read)
  return 400 unless input["votingcode"]

  if settings.development?
    $redis.sadd("votingcodes", input["votingcode"])
    $redis.hmset("votingcode:#{input["votingcode"]}",
      "used", false,
      "new", true,
      "code", input["votingcode"]
    )
  end

  return 404 unless $redis.sismember("votingcodes", input["votingcode"])

  code = $redis.hgetall("votingcode:#{input["votingcode"]}")
  return 404 if code["used"] == "true"

  code["token"] = (Digest::SHA2.new << code["code"] + Time.now.to_s).to_s
  $redis.hmset("votingcode:#{code["code"]}",
    "used", true,
    "token", code["token"]
  )

  $redis.sadd("tokens", code["token"])

  JSON.generate({token: code["token"]})
end

get('/elections') do
  content_type 'text/json'

  payload = $redis.smembers("elections").map do |n|
    {
      election: n,
      positions: $redis.hget("election:#{n}", "positions"),
      candidates: candidates_for(n)
    }
  end

  JSON.generate(payload)
end

post('/votes') do
  content_type 'text/json'

  if (not $redis.sismember("tokens", params["token"])) and (not settings.development?)
    return 403
  end

  $redis.srem("tokens", params["token"])

  input = JSON.parse(request.body.read)

  input.each do |n|
    n["votes"].each do |candidate|
      $redis.lpush("votes:#{n["election"]}:#{c["id"]}", c["rank"])
    end
  end

  200

end
