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
        Rack::Timeout.timeout = timeout
      end

      context 'when the request has a HTTP_X_REQUEST_START' do
        let(:timeout) { 4 }

        context 'in s' do
          before { env['HTTP_X_REQUEST_START'] = ((Time.now - 1).to_f).to_s }

          it 'does not time out' do
            expect { call }.to_not raise_error
          end
        end

        context 'in ms' do
          before { env['HTTP_X_REQUEST_START'] = ((Time.now - 1).to_f * 1000).to_s }

          it 'does not time out' do
            expect { call }.to_not raise_error
          end
        end
      end

      context "when the request takes too long" do
        let(:timeout) { 1 }

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
