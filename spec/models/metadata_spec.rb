require 'flight_desktop_helper'
require_relative "../../lib/desktop/session"

RSpec.describe "Desktop::Session", type: :model do
  let(:config) { Flight.config }
  let(:uuid) { session.uuid }
  let(:metadata) { YAML.load_file(metadata_path) }
  let(:metadata_path) { File.join(config.session_path, uuid, "metadata.yml") }
  let(:name) { 'session-name' }
  let(:job_id) { 'job-id' }

  before(:all) do
    @type = Desktop::Type[:xterm]
  end

  context "saving a new desktop session" do
    let(:session) { Desktop::Session.new( type: @type ) }

    it "creates the metadata file" do
      FakeFS do
        expect(File).not_to exist(metadata_path)
        session.save
        expect(File).to exist(metadata_path)
      end
    end
  end

  context "metadata" do
    it "saves the attributes correctly" do
      FakeFS do
        @session = Desktop::Session.new( type: @type, name: name )
        session.save
        expect(Time.parse(metadata[:created_at])).to be_within(1).of(Time.now)
        expect(metadata[:name]).to eq(name)
        expect(metadata[:password].length).to eq(8)
        expect(metadata[:type]).to eq(@type.name)
      end
    end

    it "loads the attributes correctly" do
      FakeFS do
        @session = Desktop::Session.new( type: @type, name: name )
        session.save
        Desktop::Session.new( uuid: uuid ).tap do |s|
          s.load
          expect(s.name).to eq(name)
          expect(s.type.name).to eq(@type.name)
          expect(s.password).to eq(session.password)
        end
      end
    end
  end

  context "saving optional metadata attributes" do
    let(:session) { Desktop::Session.new( type: @type ) }

    it "saves the job ID for sessions started through flight job" do
      flight_job_id = ENV["FLIGHT_JOB_ID"]
      ENV["FLIGHT_JOB_ID"] = job_id
      FakeFS do
        session.save
        expect(metadata[:supplementary]).to eq({ job_id: job_id })
      end
      ENV["FLIGHT_JOB_ID"] = flight_job_id
    end

    it "saves an empty 'supplementary' field for sessions not started through flight job" do
      FakeFS do
        session.save
        expect(metadata[:supplementary]).to eq(Hash.new)
      end
    end
  end

  context "loading optional metadata attributes" do
    it "loads the job ID if it is present in the metadata" do
      Desktop::Session.new( uuid: 'flight-job-session' ).tap do |s|
        s.load
        expect(s.job_id).to eq(job_id)
      end
    end

    it "doesn't raise an error if the job ID is absent from the metadata" do
      Desktop::Session.new( uuid: 'valid-session' ).tap do |s|
        s.load
        expect(s.job_id).to eq(nil)
      end
    end
  end

  def session
    @session
  end
end
