require "json"

module Loci
  module LSP
    class LSPError < Exception
      property code : Int32

      def initialize(message : String, @code : Int32)
        super(message)
      end
    end

    class Transport
      @process : Process
      @stdin : IO
      @stdout : IO
      @next_id : Int32 = 0
      @closed : Bool = false

      def initialize(command : String)
        @process = Process.new(command, shell: true,
          input: Process::Redirect::Pipe,
          output: Process::Redirect::Pipe,
          error: Process::Redirect::Close)
        @stdin = @process.input
        @stdout = @process.output
      end

      # Send a request with typed params, block until matching response
      def request(method : String, params : JSON::Serializable) : JSON::Any
        id = next_id
        params_json = JSON.parse(params.to_json)
        body = {jsonrpc: "2.0", id: id, method: method, params: params_json}.to_json
        send_message(body)
        read_response(id)
      end

      # Send a request with no params
      def request(method : String) : JSON::Any
        id = next_id
        body = {jsonrpc: "2.0", id: id, method: method}.to_json
        send_message(body)
        read_response(id)
      end

      # Send a notification with typed params (no response expected)
      def notify(method : String, params : JSON::Serializable) : Nil
        params_json = JSON.parse(params.to_json)
        body = {jsonrpc: "2.0", method: method, params: params_json}.to_json
        send_message(body)
      end

      # Send a notification with no params
      def notify(method : String) : Nil
        body = {jsonrpc: "2.0", method: method}.to_json
        send_message(body)
      end

      def close : Nil
        return if @closed
        @closed = true
        begin
          @stdin.close
        rescue
        end
        begin
          @process.wait
        rescue
        end
      end

      private def next_id : Int32
        @next_id += 1
        @next_id
      end

      private def send_message(json_body : String) : Nil
        header = "Content-Length: #{json_body.bytesize}\r\n\r\n"
        @stdin << header << json_body
        @stdin.flush
      end

      private def read_response(expected_id : Int32) : JSON::Any
        loop do
          message = read_message
          parsed = JSON.parse(message)

          if id = parsed["id"]?
            if id.as_i == expected_id
              if error = parsed["error"]?
                raise LSPError.new(error["message"].as_s, error["code"].as_i)
              end
              return parsed["result"]
            end
          end
          # Server-initiated notification — skip and keep reading
        end
      end

      private def read_message : String
        content_length = -1

        loop do
          line = @stdout.read_line
          line = line.chomp("\r")
          break if line.empty?

          if line.starts_with?("Content-Length:")
            content_length = line.split(":")[1].strip.to_i
          end
        end

        raise "Missing Content-Length header" if content_length < 0

        buf = Bytes.new(content_length)
        @stdout.read_fully(buf)
        String.new(buf)
      end
    end
  end
end
