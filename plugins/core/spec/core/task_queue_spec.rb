
require 'java'

require File.join(File.dirname(__FILE__), *%w".. .. lib core task_queue")
require File.join(File.dirname(__FILE__), *%w".. .. lib core task")

TaskQueue = Redcar::TaskQueue
Task      = Redcar::Task

describe TaskQueue do
  before do
    $started_tasks = []
    @q = TaskQueue.new
  end
  
  after do
    @q.stop
  end
  
  class QuickTask < Task
    def initialize(id)
      @id = id
    end
    
    def execute
      $started_tasks << @id
    end
    
    def inspect
      "<#{self.class} #{@id}>"
    end
  end
  
  describe "running tasks" do
    it "should accept tasks and call them" do
      @q.submit(QuickTask.new(101)).get
      $started_tasks.should == [101]
    end
    
    it "should call tasks in order" do
      @q.submit(QuickTask.new(101))
      @q.submit(QuickTask.new(102))
      @q.submit(QuickTask.new(103)).get
      $started_tasks.should == [101, 102, 103]
    end
  end
  
  describe "information" do
    class BlockingTask < QuickTask
      def execute
        $started_tasks << @id
        loop {}
      end
    end
    
    describe "about pending tasks" do
      it "should tell you about tasks that have not been started yet" do
        @q.submit(t1 = BlockingTask.new(:a))
        @q.submit(t2 = BlockingTask.new(:b))
        @q.pending.include?(t2).should be_true
      end
      
      it "should not include in process tasks" do
        @q.submit(t1 = BlockingTask.new(:a))
        @q.submit(t2 = BlockingTask.new(:b))
        1 until $started_tasks.include?(:a)
        @q.pending.include?(t1).should be_false
      end
      
      it "should not include completed tasks" do
        @q.submit(t1 = QuickTask.new(:a))
        @q.submit(t2 = BlockingTask.new(:b))
        1 until $started_tasks.include?(:b)
        @q.pending.include?(t1).should be_false
      end
      
      it "should tell you when it was enqueued" do
        @q.submit(t1 = QuickTask.new(:a))
        t1.enqueue_time.should be_an_instance_of(Time)
      end
    end
    
    describe "in process tasks" do
      it "should tell you which task is in process" do
        @q.submit(t1 = BlockingTask.new(:a))
        1 until $started_tasks.include?(:a)
        @q.in_process.should == t1
      end
      
      it "should tell you when it was started" do
        @q.submit(t1 = BlockingTask.new(:a))
        1 until $started_tasks.include?(:a)
        t1.start_time.should be_an_instance_of(Time)
      end
    end
    
    describe "completed tasks" do
      it "should tell you which tasks have completed" do
        @q.submit(t1 = QuickTask.new(:a))
        @q.submit(t2 = BlockingTask.new(:b))
        1 until $started_tasks.include?(:b)
        @q.completed.include?(t1).should be_true
      end
      
      it "should not include in process tasks" do
        @q.submit(t1 = QuickTask.new(:a))
        @q.submit(t2 = BlockingTask.new(:b))
        1 until $started_tasks.include?(:b)
        @q.completed.include?(t2).should be_false
      end
      
      it "should not include in pending tasks" do
        @q.submit(t1 = QuickTask.new(:a))
        @q.submit(t2 = BlockingTask.new(:b))
        @q.submit(t3 = BlockingTask.new(:c))
        1 until $started_tasks.include?(:b)
        @q.completed.include?(t3).should be_false
      end
      
      it "should tell you when it was completed" do
        @q.submit(t1 = QuickTask.new(:a))
        @q.submit(t2 = BlockingTask.new(:b))
        1 until $started_tasks.include?(:b)
        t1.completed_time.should be_an_instance_of(Time)
      end
    end
  end
  
  describe "errored tasks" do
    class ErrorTask < QuickTask
      def execute
        $started_tasks << @id
        raise 'error'
      end
    end
    
    it "should be in completed task list" do
      @q.submit(t1 = ErrorTask.new(:a))
      @q.submit(t2 = BlockingTask.new(:b))
      1 until $started_tasks.include?(:b)
      @q.completed.should == [t1]
    end
    
    it "should have the error" do
      @q.submit(t1 = ErrorTask.new(:a))
      @q.submit(t2 = BlockingTask.new(:b))
      1 until $started_tasks.include?(:b)
      @q.completed.first.error.should be_an_instance_of(RuntimeError)
    end
  end
end








