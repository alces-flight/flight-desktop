require 'flight_desktop_helper'
require_relative "../../lib/desktop/session"

RSpec.describe "Desktop::Session", type: :model do
  let(:config) { Flight.config }
  let(:type) { Desktop::Type["xterm"] }

  context "valid new desktop session" do
    it "saves metadata" do
      puts config.session_path
      session = Desktop::Session.new( type: type, name: "test" )
      # FSR we need to call `Session#dir` to create the directories that the
      # metadata path is to live in.  During normal operation this is done as
      # a side-effect of starting the VNC server.  Perhaps the save method
      # ought also to be calling `dir`.
      session.dir
      session.save
    end
  end
end
