require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano domain', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'create', 'corstest', '--save'))
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', 'corstest'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it "show domain" do
    out, err, status = Open3.capture3(capcmd('murano', 'domain'))
    expect(out.chomp).to eq('corstest.apps.exosite.io')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
