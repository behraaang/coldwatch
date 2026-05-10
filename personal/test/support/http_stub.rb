require "net/http"

# Helpers for stubbing Net::HTTP.start without pulling in webmock or VCR.
# Used by services that hit mempool.space / coingecko / ntfy.sh.
#
# Pattern in tests:
#
#   HttpStub.with_response(body: '{"ok":true}') do
#     result = MempoolFetcher.fetch("addr", base: "https://example.com")
#   end
#
# Implementation note: minitest's Object#stub, when given a non-callable
# value, *also* invokes any block passed to the stubbed method. Production
# code calls `Net::HTTP.start(host, port, opts) { |http| http.request(req) }`,
# so passing a non-callable response as the stub value would re-invoke that
# block with no `http` argument and explode. We pass a callable instead,
# which receives the original block but ignores it and returns the fake
# response directly — exactly what the real HTTPS round trip would have
# produced.
module HttpStub
  module_function

  def fake_response(body: "", status: 200)
    klass = case status
            when 200..299 then Net::HTTPSuccess
            when 400..499 then Net::HTTPClientError
            else               Net::HTTPInternalServerError
            end
    response = klass.new("1.1", status.to_s, "Stub")
    response.define_singleton_method(:body) { body }
    response
  end

  def with_response(body: "", status: 200)
    response = fake_response(body: body, status: status)
    Net::HTTP.stub(:start, ->(*_args, **_kw, &_blk) { response }) do
      yield response
    end
  end

  def with_raise(exception_class = SocketError, message: "stubbed network failure")
    raiser = ->(*_args, **_kw, &_blk) { raise exception_class, message }
    Net::HTTP.stub(:start, raiser) do
      yield
    end
  end
end
