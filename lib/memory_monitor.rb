require_relative "memory_monitor/version"

class MemoryMonitor
  attr_reader :command, :limit, :timeout, :interval, :pid, :pgid,
              :memory_in_kilobytes, :memory_in_megabytes

  SIGNALS = %w(HUP INT QUIT USR1 USR2 TERM)

  def self.run(*args, **kwargs)
    new(*args, **kwargs).run
  end

  def initialize(command, limit:, timeout: 2, interval: 1)
    @command  = command
    @limit    = limit
    @timeout  = timeout
    @interval = interval
  end

  def run
    forward_signals

    @pid  = Process.spawn(*command, pgroup: true)
    @pgid = Process.getpgid(pid)

    Thread.abort_on_exception = true
    Thread.new { monitor }

    Process.wait pid

    if $?.success?
      $?.exitstatus
    else
      false
    end
  end

  def limit_in_kilobytes
    limit * 1024
  end

  def monitor
    loop do
      @memory_in_kilobytes =
        `ps -o pgrp= -o rss=`
          .split("\n")
          .map { |line| line.split(" ").map(&:to_i) }
          .select { |pgid, _| pgid == self.pgid }
          .map { |_, size| size }
          .max

      @memory_in_megabytes = (memory_in_kilobytes / 1024).round(1)

      if memory_in_kilobytes > limit_in_kilobytes
        term
        sleep timeout
        kill
      end

      sleep interval
    end
  end

  def term
    log "process memory #{memory_in_megabytes}MB exceeded limit #{limit}MB, sending SIGTERM"
    Process.kill("TERM", -pgid)
  end

  def kill
    log "process failed to stop after #{timeout}s, sending SIGKILL"
    Process.kill("KILL", -pgid)
  end

  def log(message)
    $stderr.puts "[memory_monitor] #{message}"
  end

  def forward_signals
    SIGNALS.each do |signal|
      Signal.trap(signal) do
        begin
          Process.kill(signal, pid) if pid
        rescue Errno::ESRCH
          # pid doesn't exist
        end
      end
    end
  end
end
