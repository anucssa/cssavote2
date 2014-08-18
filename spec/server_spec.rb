require 'rack/test'
require 'json'
require 'redis'

require './server.rb'

$redis = Redis.new

def clear_redis
  $redis.keys("*").each {|n| $redis.del(n) if n != "votelock" }
end

describe "The Admin part" do
  include Rack::Test::Methods

  ELECTIONS = [
    {
      name: "president",
      positions: 1
    }, {
      name: "secretary",
      positions: 1
    }, {
      name: "genrep",
      positions: 5
    }
  ]

  CANDIDATES = [
    {
      id: "u1234567",
      elections: ["president"],
      name: "Steve Balmer"
    }, {
      id: "u7654321",
      elections: ["secretary", "genrep"],
      name: "Steve Jobs"
    }
  ]

  def app
    Sinatra::Application
  end

  before(:each) do
    clear_redis
    post '/admin/elections', JSON.generate(ELECTIONS)
    expect(last_response).to be_ok
    post '/admin/candidates', JSON.generate(CANDIDATES)
    expect(last_response).to be_ok
  end

  it "should return all positions" do
    get '/admin/elections'
    expect(JSON.parse(last_response.body).length).to be $redis.smembers("elections").length
  end

  it "should add a candidate" do
    post '/admin/candidates', JSON.generate([{
      id: "u1234321",
      elections: ["president", "genrep"],
      name: "Linus Torvalds"
    }])

    expect(last_response).to be_ok
    expect($redis.smembers("candidates").length).to be 1
  end

  it "should return all candidates" do
    get '/admin/candidates'

    expect(last_response).to be_ok
    expect(JSON.parse(last_response.body).length).to be $redis.smembers("candidates").length
  end

  it "should deny unauthed requests" do
    AUTH_TOKEN = "qwerty"
    ENV["AUTH_TOKEN"] = AUTH_TOKEN

    get "/admin/"
    expect(last_response).to_not be_ok

    get "/admin/candidates", {token: AUTH_TOKEN}
    expect(last_response).to be_ok

    ENV.delete "AUTH_TOKEN"
  end

  it "prevents schema modification on on vote lock" do
    get "/admin/votelock"
    puts last_response.body
    expect(JSON.parse(last_response.body)["state"]).to eq("editing")

    post "/admin/votelock", JSON.generate({state: "voting"})
    expect(last_response).to be_ok

    post "/admin/candidates", JSON.generate({})
    expect(last_response).to_not be_ok

    post "/admin/elections", JSON.generate({})
    expect(last_response).to_not be_ok
  end
end

describe "The General part" do
end
