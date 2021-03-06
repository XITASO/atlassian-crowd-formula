require "serverspec"

set :backend, :exec

describe service("atlassian-crowd") do
  it { should be_enabled }
  it { should be_running }
end

describe port("8009") do
  it { should be_listening }
end

describe port("8095") do
  it { should be_listening }
end

describe command('curl -L localhost:8095') do
  its(:stdout) { should contain('Set up Crowd') }
end
