require "open3"
require "timeout"

describe "bin/memory_monitor" do
  let(:binfile) { File.expand_path("../../bin/memory_monitor", __FILE__) }

  def run(program)
    output = {}

    command = [
      binfile,
      "--timeout", "0.1",
      "--interval", "0.1",
      "--limit", "30",
      "ruby", "-e", program
    ]

    Timeout.timeout(2) do
      Open3.popen3(*command) do |stdin, stdout, stderr, wait_thread|
        yield wait_thread.pid, stdout, stderr if block_given?

        output[:status] = wait_thread.value
        output[:stdout] = stdout.read
        output[:stderr] = stderr.read
      end
    end

    output
  end

  it "runs a program" do
    output = run('puts "hi"')
    expect(output[:stdout]).to eq("hi\n")
  end

  it "sends SIGTERM to a program which exceeds its memory limit" do
    output = run <<-RUBY
      a = []
      loop do
        puts "hi"
        $stdout.flush
        a << "foo" * 10000
        sleep 0.001
      end
    RUBY

    expect(output[:stdout]).to include("hi")
    expect(output[:stderr]).to match(/\[memory_monitor\] process memory .+MB exceeded limit .+MB, sending SIGTERM/)
    expect(output[:status].exitstatus).to eq(1)
  end

  it "sends SIGKILL to a program which fails to stop on SIGTERM" do
    output = run <<-RUBY
      a = []

      trap("TERM") do
        puts "ignoring SIGTERM"
      end

      loop do
        puts "hi"
        $stdout.flush
        a << "foo" * 10000
        sleep 0.001
      end
    RUBY

    expect(output[:stdout]).to include("hi")
    expect(output[:stdout]).to include("ignoring SIGTERM")
    expect(output[:stderr]).to match(/process memory .+MB exceeded limit .+MB, sending SIGTERM/)
    expect(output[:stderr]).to match(/process failed to stop after .+s, sending SIGKILL/)
    expect(output[:status].exitstatus).to eq(1)
  end

  it "monitors the total memory of all processes, including subprocesses" do
    output = run <<-RUBY
      Process.wait fork {
        a = []
        loop do
          puts "hi"
          $stdout.flush
          a << "foo" * 10000
          sleep 0.001
        end
      }
    RUBY

    expect(output[:stdout]).to include("hi")
    expect(output[:stderr]).to match(/process memory .+MB exceeded limit .+MB, sending SIGTERM/)
    expect(output[:status].exitstatus).to eq(1)
  end

  it "forwards signals to the child" do
    program = <<-RUBY
      trap("TERM") {
        puts "got signal: TERM"
        $stdout.flush
      }
      puts "ready"
      $stdout.flush
      sleep 1
    RUBY

    output = run(program) { |monitor_pid, stdout, stderr|
      expect(stdout.readline).to eq("ready\n") # wait for handler to get defined
      Process.kill("TERM", monitor_pid)
    }

    expect(output[:stdout]).to include("got signal: TERM")
  end
end
