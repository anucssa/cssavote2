require 'rack/test'
require 'json'
require 'redis'

require './server.rb'

$redis = Redis.new

def clear_redis
  $redis.keys("*").each {|n| $redis.del(n) if n != "votelock" }
end


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

describe "The Admin part" do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  before(:all) do
    clear_redis
    post '/admin/elections', JSON.generate(ELECTIONS)
    expect(last_response).to be_ok
    post '/admin/candidates', JSON.generate(CANDIDATES)
    expect(last_response).to be_ok
  end

  before(:each) do
    post "/admin/votelock", JSON.generate({state: "editing"})
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

  it "prevents schema modification on on vote lock" do
    get "/admin/votelock"
    expect(JSON.parse(last_response.body)["state"]).to eq("editing")

    post "/admin/votelock", JSON.generate({state: "voting"})
    expect(last_response).to be_ok

    post "/admin/candidates", JSON.generate({})
    expect(last_response).to_not be_ok

    post "/admin/elections", JSON.generate({})
    expect(last_response).to_not be_ok
  end

  it 'lets codes be added' do
    get "/admin/votingcodes"
    expect(last_response).to be_ok
    vote_count = JSON.parse(last_response.body).length

    post "/admin/votingcodes", JSON.generate([{
        code: "123456",
        used: "false",
        new: "true"
    }])
    expect(last_response).to be_ok

    get "/admin/votingcodes"
    expect(last_response).to be_ok
    expect(JSON.parse(last_response.body).length).to eq(vote_count + 1)
  end

  it 'generates codes when more are requested' do
    get "/admin/votingcodes"
    expect(last_response).to be_ok
    vote_count = JSON.parse(last_response.body).length

    get "/admin/votingcodes/more"
    expect(last_response).to be_ok

    get "/admin/votingcodes"
    expect(last_response).to be_ok
    expect(JSON.parse(last_response.body).length).to be > vote_count
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
end

describe "The General part" do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  before(:all) do
    post '/admin/elections', JSON.generate(ELECTIONS)
    post '/admin/candidates', JSON.generate(CANDIDATES)
    post '/admin/votelock', JSON.generate({state: "voting"})

    get '/admin/votelock'
    expect(JSON.parse(last_response.body)["state"]).to eq("voting")
  end
end
