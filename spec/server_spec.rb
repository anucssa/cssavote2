def clear_redis
  redis.keys("*").each {|n| redis.del(n) }
end

describe "The Admin part" do
  it "should add a candidate" do
  end

  it "should delete a candidate" do
  end

  it "should modify a candidate" do
  end

  it "should return all candidates" do
  end
end

describe "The General part" do
end

