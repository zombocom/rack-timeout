require 'rack/timeout'

describe Rack::Timeout do
  describe '#call' do

    let(:app) { ->(e) { sleep 2 } }
    let(:env) { {} }

    subject(:call) do
      Rack::Timeout.new(app).call(env)
    end

    context "when the timeout is set" do
      before do
        Rack::Timeout.timeout = 1
      end

      context "when the request takes too long" do
        it 'raises a timeout error' do
          expect { call }.to raise_error(Rack::Timeout::RequestTimeoutError)
        end
      end
    end

    context "when overtime is set" do
      before do
        Rack::Timeout.timeout = 1
        Rack::Timeout.overtime = 3
      end

      context 'and the request takes longer than the timeout, but less than the overtime' do
        context "and a body exists" do
          before do
            env['HTTP_TRANSFER_ENCODING'] = 'chunked'
          end

          it "completes successfully" do
            expect { call }.to_not raise_error
          end
        end

        context "but no body exists" do
          it 'raises a timeout error' do
            expect { call }.to raise_error(Rack::Timeout::RequestTimeoutError)
          end
        end
      end

      context 'and the request takes longer than even the overtime' do
        let(:app) { ->(e) { sleep 5 } }
        before do
          env['HTTP_TRANSFER_ENCODING'] = 'chunked'
        end

        it 'raises a timeout error' do
          expect { call }.to raise_error(Rack::Timeout::RequestTimeoutError)
        end
      end
    end
  end
end
