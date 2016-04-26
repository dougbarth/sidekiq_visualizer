require 'json'
require 'set'
require 'csv'
require 'date'
require 'erb'

# Minimum time that a job must have executed for it to be added to the results file.
MIN_DURATION = 0

DT_FORMAT = "%m/%d/%Y %H:%M:%S"

class Job
  attr_reader :jid, :job_class
  attr_reader :events, :executions

  def initialize(jid, job_class)
    @jid = jid
    @job_class = job_class
    @events = []
    @executions = []
    @open_executions = {}
  end

  def lifecyle_event!(state, tid, time)
    @events << JobEvent.new(self, state, tid, time)

    case state
    when "start"
      execution = JobExecution.new(self, tid, time)
      @open_executions[tid] = execution
      @executions << execution
    when "done"
      execution = @open_executions.delete(tid)
      if execution
        execution.end_at = time
      end
    end
  end

  def to_s
    "#{jid} => #{@events}"
  end
end

class JobEvent < Struct.new(:job, :state, :tid, :time)
end

class JobExecution < Struct.new(:job, :tid, :start_at)
  attr_accessor :end_at

  def complete?
    start_at && end_at
  end

  def duration
    end_at - start_at
  end
end

jobs_by_jid = {}
thread_ids = Set.new

ARGF.each_line do |line|
  entry = JSON.parse(line)

  message = entry['message']
  time = entry['generated_at']
  worker = entry['program']

  match_data = /^3 (TID-[a-z0-9]+) (.*) (JID-[0-9a-f]+) .*INFO: (start|done)/.match(message)

  if match_data
    tid, job_class, jid, state = match_data.captures

    worker_thread_id = "#{worker}-#{tid}"
    thread_ids << "#{worker}-#{tid}"

    job = jobs_by_jid[jid]
    unless job
      job = Job.new(jid, job_class)
      jobs_by_jid[jid] = job
    end

    job.lifecyle_event!(state, worker_thread_id, DateTime.parse(time))
  end
end

class ChartRenderer
  def initialize(threads, jobs)
    @threads = threads
    @jobs = jobs
  end

  def render
    template = ERB.new(IO.read('views/local_chart.erb'))
    template.result(binding)
  end

  def data
    data = []

    @threads.sort.each do |tid|
      @jobs.values.each do |job|
        executions = job.executions.select { |e| e.tid == tid }
        executions.each do |ex|
          if ex.complete? && ex.duration > MIN_DURATION
            data << [tid, job.job_class, ex.start_at, ex.end_at]
          end
        end
      end
    end

    data
  end

  def js_date(date_time)
    "new Date(#{date_time.strftime("%Y, %m - 1, %d, %H, %M, %S")})"
  end
end

renderer = ChartRenderer.new(thread_ids, jobs_by_jid)
puts renderer.render
