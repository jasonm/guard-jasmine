# coding: utf-8

require 'spec_helper'

describe Guard::Jasmine::Runner do

  let(:runner) { Guard::Jasmine::Runner }
  let(:formatter) { Guard::Jasmine::Formatter }

  let(:defaults) { Guard::Jasmine::DEFAULT_OPTIONS }

  let(:phantomjs_error_response) do
    <<-JSON
    {
      "error": "Cannot request Jasmine specs"
    }
    JSON
  end

  let(:phantomjs_failure_response) do
    <<-JSON
    {
      "suites": [
        {
          "description": "Failure suite",
          "specs": [
            {
              "description": "Failure spec tests something",
              "error_message": "ReferenceError: Can't find variable: a in http://localhost:3000/assets/backbone/models/model_spec.js?body=1 (line 27)",
              "passed": false
            },
            {
              "description": "Failure spec 2 tests something",
              "error_message": "ReferenceError: Can't find variable: b in http://localhost:3000/assets/backbone/models/model_spec.js?body=1 (line 27)",
              "passed": false
            },
            {
              "description": "Success spec tests something",
              "passed": true
            }
          ]
        }
      ],
      "stats": {
        "specs": 3,
        "failures": 2,
        "time": 0.007
      },
      "passed": false
    }
    JSON
  end

  let(:phantomjs_success_response) do
    <<-JSON
    {
      "suites": [
        {
          "description": "Success suite",
          "specs": [
            {
              "description": "Success test tests something",
              "passed": true
            },
            {
              "description": "Another success test tests something",
              "passed": true
            }
          ]
        }
      ],
      "stats": {
        "specs": 2,
        "failures": 0,
        "time": 0.009
      },
      "passed": true
    }
    JSON
  end

  let(:phantomjs_command) do
    "/usr/local/bin/phantomjs #{ @project_path }/lib/guard/jasmine/phantomjs/run-jasmine.coffee"
  end

  before do
    formatter.stub(:notify)
    formatter.stub(:puts)
  end

  describe '#run' do
    before do
      File.stub(:foreach).and_yield 'describe "ErrorTest", ->'
      IO.stub(:popen).and_return StringIO.new(phantomjs_error_response)
    end

    context 'when passed an empty paths list' do
      it 'returns false' do
        runner.run([]).should eql [false, []]
      end
    end

    context 'when passed the spec directory' do
      it 'requests all jasmine specs from the server' do
        IO.should_receive(:popen).with("#{ phantomjs_command } http://localhost:3000/jasmine")
        runner.run(['spec/javascripts'], defaults.merge({ :notification => false }))
      end

      it 'shows a start information in the console' do
        formatter.should_receive(:info).with('Run all Jasmine suites', { :reset => true })
        formatter.should_receive(:info).with('Run Jasmine suite at http://localhost:3000/jasmine')
        runner.run(['spec/javascripts'], defaults)
      end
    end

    context 'for an erroneous Jasmine spec' do
      it 'requests the jasmine specs from the server' do
        IO.should_receive(:popen).with("#{ phantomjs_command } http://localhost:3000/jasmine?spec=ErrorTest")
        runner.run(['spec/javascripts/a.js.coffee'], defaults)
      end

      it 'shows the error in the console' do
        formatter.should_receive(:error).with(
            "An error occurred: Cannot request Jasmine specs"
        )
        runner.run(['spec/javascripts/a.js.coffee'], defaults)
      end

      it 'returns the errors' do
        response = runner.run(['spec/javascripts/a.js.coffee'], defaults)
        response.first.should be_false
        response.last.should =~ []
      end

      context 'with notifications' do
        it 'shows an error notification' do
          formatter.should_receive(:notify).with(
              "An error occurred: Cannot request Jasmine specs",
              :title    => 'Jasmine error',
              :image    => :failed,
              :priority => 2
          )
          runner.run(['spec/javascripts/a.js.coffee'], defaults)
        end
      end

      context 'without notifications' do
        it 'does not shows an error notification' do
          formatter.should_not_receive(:notify)
          runner.run(['spec/javascripts/a.js.coffee'], defaults.merge({ :notification => false }))
        end
      end
    end

    context "for a failing Jasmine spec" do
      before do
        File.stub(:foreach).and_yield 'describe "FailureTest", ->'
        IO.stub(:popen).and_return StringIO.new(phantomjs_failure_response)
      end

      it 'requests the jasmine specs from the server' do
        File.should_receive(:foreach).with('spec/javascripts/x/b.js.coffee').and_yield 'describe "FailureTest", ->'
        IO.should_receive(:popen).with("#{ phantomjs_command } http://localhost:3000/jasmine?spec=FailureTest")
        runner.run(['spec/javascripts/x/b.js.coffee'], defaults)
      end

      it 'returns the failures' do
        response = runner.run(['spec/javascripts/x/b.js.coffee'], defaults)
        response.first.should be_false
        response.last.should =~ ['spec/javascripts/x/b.js.coffee']
      end

      context 'with the specdoc set to :never' do
        it 'shows the summary in the console' do
          formatter.should_receive(:info).with(
              'Run Jasmine suite spec/javascripts/x/b.js.coffee', { :reset => true }
          )
          formatter.should_receive(:info).with(
              'Run Jasmine suite at http://localhost:3000/jasmine?spec=FailureTest'
          )
          formatter.should_not_receive(:suite_name)
          formatter.should_not_receive(:spec_failed)
          formatter.should_receive(:error).with(
              "3 specs, 2 failures\nin 0.007 seconds"
          )
          runner.run(['spec/javascripts/x/b.js.coffee'], defaults.merge({ :specdoc => :never }))
        end
      end

      context 'with the specdoc set either :always or :failure' do
        it 'shows the specdoc in the console' do
          formatter.should_receive(:info).with(
              'Run Jasmine suite spec/javascripts/x/b.js.coffee', { :reset => true }
          )
          formatter.should_receive(:info).with(
              'Run Jasmine suite at http://localhost:3000/jasmine?spec=FailureTest'
          )
          formatter.should_receive(:suite_name).with(
              '➥ Failure suite'
          )
          formatter.should_receive(:spec_failed).with(
              ' ✘ Failure spec tests something'
          )
          formatter.should_receive(:spec_failed).with(
              "   ➤ ReferenceError: Can't find variable: a in backbone/models/model_spec.js on line 27"
          )
          formatter.should_receive(:spec_failed).with(
              ' ✘ Failure spec 2 tests something'
          )
          formatter.should_receive(:spec_failed).with(
              "   ➤ ReferenceError: Can't find variable: b in backbone/models/model_spec.js on line 27"
          )
          formatter.should_receive(:error).with(
              "3 specs, 2 failures\nin 0.007 seconds"
          )
          runner.run(['spec/javascripts/x/b.js.coffee'], defaults.merge({ :notification => false }))
        end
      end

      context 'with the :hide_success option disabled' do
        it 'shows the passing specs in the console' do
          formatter.should_receive(:success).with(
              ' ✔ Success spec tests something'
          )
          runner.run(['spec/javascripts/x/b.js.coffee'], defaults)
        end
      end

      context 'without the :hide_success option enabled' do
        it 'does not shows the passing specs in the console' do
          formatter.should_not_receive(:success).with(
              ' ✔ Success spec tests something'
          )
          runner.run(['spec/javascripts/x/b.js.coffee'], defaults.merge({ :hide_success => true }))
        end
      end

      context 'with notifications' do
        it 'shows the failing spec notification' do
          formatter.should_receive(:notify).with(
              "Failure spec tests something: ReferenceError: Can't find variable: a",
              :title    => 'Jasmine spec failed',
              :image    => :failed,
              :priority => 2
          )
          formatter.should_receive(:notify).with(
              "Failure spec 2 tests something: ReferenceError: Can't find variable: b",
              :title    => 'Jasmine spec failed',
              :image    => :failed,
              :priority => 2
          )
          formatter.should_receive(:notify).with(
              "3 specs, 2 failures\nin 0.007 seconds",
              :title    => 'Jasmine suite failed',
              :image    => :failed,
              :priority => 2
          )
          runner.run(['spec/javascripts/x/b.js.coffee'], defaults)
        end

        context 'with :max_error_notify' do
          it 'shows the failing spec notification' do
            formatter.should_receive(:notify).with(
                "Failure spec tests something: ReferenceError: Can't find variable: a",
                :title    => 'Jasmine spec failed',
                :image    => :failed,
                :priority => 2
            )
            formatter.should_not_receive(:notify).with(
                "Failure spec 2 tests something: ReferenceError: Can't find variable: b",
                :title    => 'Jasmine spec failed',
                :image    => :failed,
                :priority => 2
            )
            formatter.should_receive(:notify).with(
                "3 specs, 2 failures\nin 0.007 seconds",
                :title    => 'Jasmine suite failed',
                :image    => :failed,
                :priority => 2
            )
            runner.run(['spec/javascripts/x/b.js.coffee'], defaults.merge({ :max_error_notify => 1 }))
          end
        end

        context 'without notifications' do
          it 'does not show a failure notification' do
            formatter.should_not_receive(:notify)
            runner.run(['spec/javascripts/x/b.js.coffee'], defaults.merge({ :notification => false }))
          end
        end
      end

      context "for a successful Jasmine spec" do
        before do
          File.stub(:foreach).and_yield 'describe("SuccessTest", function() {'
          IO.stub(:popen).and_return StringIO.new(phantomjs_success_response)
        end

        it 'requests the jasmine specs from the server' do
          File.should_receive(:foreach).with('spec/javascripts/t.js').and_yield 'describe("SuccessTest", function() {'
          IO.should_receive(:popen).with("#{ phantomjs_command } http://localhost:3000/jasmine?spec=SuccessTest")

          runner.run(['spec/javascripts/t.js'], defaults)
        end

        it 'returns the success' do
          response = runner.run(['spec/javascripts/x/b.js.coffee'], defaults)
          response.first.should be_true
          response.last.should =~ []
        end

        context 'with the specdoc set to :always' do
          it 'shows the specdoc in the console' do
            formatter.should_receive(:info).with(
                'Run Jasmine suite spec/javascripts/x/t.js', { :reset => true }
            )
            formatter.should_receive(:info).with(
                'Run Jasmine suite at http://localhost:3000/jasmine?spec=SuccessTest'
            )
            formatter.should_receive(:suite_name).with(
                '➥ Success suite'
            )
            formatter.should_receive(:success).with(
                ' ✔ Success test tests something'
            )
            formatter.should_receive(:success).with(
                ' ✔ Another success test tests something'
            )
            formatter.should_receive(:success).with(
                "2 specs, 0 failures\nin 0.009 seconds"
            )
            runner.run(['spec/javascripts/x/t.js'], defaults.merge({ :specdoc => :always }))
          end
        end

        context 'with the specdoc set to :never or :failure' do
          it 'shows the summary in the console' do
            formatter.should_receive(:info).with(
                'Run Jasmine suite spec/javascripts/x/t.js', { :reset => true }
            )
            formatter.should_receive(:info).with(
                'Run Jasmine suite at http://localhost:3000/jasmine?spec=SuccessTest'
            )
            formatter.should_not_receive(:suite_name)
            formatter.should_receive(:success).with(
                "2 specs, 0 failures\nin 0.009 seconds"
            )
            runner.run(['spec/javascripts/x/t.js'], defaults.merge({ :specdoc => :never }))
          end
        end

        context 'with notifications' do
          it 'shows a success notification' do
            formatter.should_receive(:notify).with(
                "2 specs, 0 failures\nin 0.009 seconds",
                :title => 'Jasmine suite passed'
            )
            runner.run(['spec/javascripts/t.js'], defaults)
          end

          context 'with hide success notifications' do
            it 'does not shows a success notification' do
              formatter.should_not_receive(:notify)
              runner.run(['spec/javascripts/t.js'], defaults.merge({ :notification => true, :hide_success => true }))
            end
          end
        end

        context 'without notifications' do
          it 'does not shows a success notification' do
            formatter.should_not_receive(:notify)
            runner.run(['spec/javascripts/t.js'], defaults.merge({ :notification => false }))
          end
        end
      end

    end

  end
end
