require File.dirname(__FILE__) + '/../../../spec_helper'
require 'net/http'

describe "Net::HTTP.newobj when passed address" do
  before(:each) do
    @net = Net::HTTP.newobj("localhost")
  end
  
  it "returns a new Net::HTTP instance" do
    @net.should be_kind_of(Net::HTTP)
  end
  
  it "sets the new Net::HTTP instance's address to the passed address" do
    @net.address.should == "localhost"
  end
  
  it "sets the new Net::HTTP instance's port to the default HTTP port" do
    @net.port.should eql(Net::HTTP.default_port)
  end
  
  it "does not start the new Net::HTTP instance" do
    @net.started?.should be_false
  end
end

describe "Net::HTTP.newobj when passed address, port" do
  before(:each) do
    @net = Net::HTTP.newobj("localhost", 3333)
  end

  it "returns a new Net::HTTP instance" do
    @net.should be_kind_of(Net::HTTP)
  end
  
  it "sets the new Net::HTTP instance's address to the passed address" do
    @net.address.should == "localhost"
  end
  
  it "sets the new Net::HTTP instance's port to the passed port" do
    @net.port.should eql(3333)
  end
  
  it "does not start the new Net::HTTP instance" do
    @net.started?.should be_false
  end
end