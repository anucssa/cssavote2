require 'sinatra'
require 'redis'
require 'json'

$redis = Redis.new

def candidates_for(election)
  $redis.hgetall("election:#{election}").delete_if do |k,v|
    not k.match /[0-9]+/
  end.invert # end up with {"u555555" => "1"}
end

before '/admin/*' do
  puts "Hello filter"
  given_token = (Digest::SHA2.new << (params["token"] || " ")).to_s
  actual_token = (Digest::SHA2.new << (ENV["AUTH_TOKEN"] || " ")).to_s

  if not secure_compare(given_token, actual_token)
    status 401
    halt
  end
end

def locked_req!
  if $redis.get("votingcode") == "voting"
    status 403
    halt
  end
end

get('/admin/votelock') do
  content_type 'text/json'

  JSON.generate({state: $redis.get("votelock")})
end

post('/admin/votelock') do
  input = JSON.parse(request.body.read)
  $redis.set("votelock", input["state"])
  200
end

get('/admin/candidates') do
  content_type 'text/json'

  payload = $redis.smembers("candidates").map do |uid|
    {
      id: uid,
      elections: $redis.smembers("elections:#{uid}")
    }.merge($redis.hgetall("candidate:#{uid}"))
  end

  JSON.generate(payload)
end

post('/admin/candidates') do

  locked_req!

  input = JSON.parse(request.body.read)
  input.each {|n| return 500 unless n["id"] }

  # Clear out the current candidates
  $redis.smembers("candidates").each do |n|
    $redis.smembers("elections").each do |e|
      candidates_for(e).each do |c,pos|
        $redis.hdel("election:#{e}", c)
      end
    end
    $redis.del("candidate:#{n}")
    $redis.del("elections:#{n}")
  end
  $redis.del("candidates")

  input.each {|n| $redis.sadd("candidates", n["id"]) }
  input.each do |n|
    $redis.hmset("candidate:#{n["id"]}", "name", n["name"])

    # add each candidate to their allotted elections
    n["elections"].each do |e|
      $redis.sadd("elections:#{n["id"]}", e)
      $redis.hmset("election:#{e}", candidates_for(e).length + 1, n["id"])
    end
  end

  200
end

get('/admin/elections') do
  content_type 'text/json'

  payload = $redis.smembers("elections").map do |election|
    {
      name: election,
      positions: $redis.hget("election:#{election}", "positions")
    }
  end

  JSON.generate(payload)
end

post('/admin/elections') do

  locked_req!

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

    if $redis.sismember("votingcodes", code)
      input += 1
      puts "ffs, why"
      redo
    end

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

  locked_req!

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

get('/admin/votes.blt') do
  content_type 'text/plain'

  cached = $redis.get("cache:votes.blt")
  return cached if cached

  output = ""

  # For each election
  $redis.smembers("elections").each do |election|
    output += "#{election}\n\n"

    positions = $redis.hget("election:#{election}", "positions")

    # Work out what order the candidates are in
    candidates = candidates_for(election)

    output += "#{candidates.length} #{positions}\n"

    votes = $redis.lrange("votes:#{election}", 0, $redis.llen("votes:#{election}")).sort

    counter = 0
    votes.length.times do |i|
      if votes[i] == votes[i+1]
        counter += 1
      elsif counter > 0 # there have been a few
        output += "#{counter} #{votes[i]} 0\n"
        counter = 0
      else
        counter = 0
        output += "1 #{votes[i]} 0\n"
      end
    end

    output += "0\n"

    candidates.sort {|a,b| a[1] <=> b[1] }.each do |i|
      output += "\"#{i[0]}\"\n"
    end

    output += "\n\n"
  end

  $redis.set("cache:votes.blt", output)

  output
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
    candidates = candidates_for(n).map do |id,pos|
      {
        "name" => $redis.hget("candidate:#{id}", "name"),
        "id"   => id
      }
    end

    {
      election: n,
      positions: $redis.hget("election:#{n}", "positions"),
      candidates: candidates
    }
  end

  JSON.generate(payload)
end

post('/votes') do

  if (not $redis.sismember("tokens", params["token"])) and (not settings.development?)
    return 403
  else
    $redis.srem("tokens", params["token"])
  end

  input = JSON.parse(request.body.read)

  input.each do |n|
    votes = []
    candidates = candidates_for(n["election"])
    n["votes"].map do |c|
      votes[ candidates[c["id"]].to_i ] = c["rank"]
    end

    votes.delete_if {|n| not n } # clear nils
    votes = votes.reduce("") {|memo, obj| memo += obj + " " }.strip
    $redis.lpush("votes:#{n["election"]}", votes)
  end

  # invalidate the BLT cache
  $redis.del("cache:votes.blt")

  200

end
