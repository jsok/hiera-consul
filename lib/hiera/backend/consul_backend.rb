# Hiera backend for Consul
class Hiera
  module Backend
    class Consul_backend

      def initialize()
        require 'base64'
        require 'net/http'
        require 'json'
        require 'uri'

        @config = Config[:consul]
        if ENV['CONSUL_HTTP_ADDR']
          # By convention the ENV var does not contain a scheme, but URI
          # requires one. Net::HTTP will switch to https if configured later.
          uri = URI('http://' + ENV['CONSUL_HTTP_ADDR'])
          @consul = Net::HTTP.new(uri.host, uri.port)
        elsif (@config[:host] && @config[:port])
          @consul = Net::HTTP.new(@config[:host], @config[:port])
        else
          raise "[hiera-consul] Missing minimum configuration, please check hiera.yaml"
        end
        @consul.read_timeout = @config[:http_read_timeout] || 10
        @consul.open_timeout = @config[:http_connect_timeout] || 10

        begin
          check_agent
          Hiera.debug("[hiera-consul] Client configured to connect to #{@consul.address}:#{@consul.port}")
        rescue Exception => e
          @consul = nil
          Hiera.warn("[hiera-consul] Skipping backend. Configuration error: #{e}")
        end
      end

      def lookup(key, scope, order_override, resolution_type)
        return nil if @consul.nil?

        answer = nil

        paths = @config[:paths].map { |p| Backend.parse_string(p, scope, { 'key' => key }) }
        paths.insert(0, order_override) if order_override

        paths.each do |path|
          Hiera.debug("[hiera-consul] Looking up #{path}/#{key} in consul backend")

          # Check that we are not looking somewhere that will make hiera crash subsequent lookups
          if "#{path}/#{key}".match("//")
            Hiera.debug("[hiera-consul] The specified path #{path}/#{key} is malformed, skipping")
            next
          end

          query_path = "#{path}/#{key}"
          recurse = resolution_type == :hash

          result = wrapquery(query_path, recurse)
          next unless result

          api_prefix = /^\/v\d\/kv\//
          prefix = query_path.sub(api_prefix, '')
          answer = parse_result(result, prefix)
          next unless answer

          Hiera.debug("[hiera-consul] Read key #{key} from path #{path}")
          break
        end

        answer
      end

      private

      def wrapquery(path, recurse = false)
          path += "?recurse" if recurse
          httpreq = Net::HTTP::Get.new("#{path}")

          data = nil
          begin
            response = @consul.request(httpreq)
            case response
            when Net::HTTPSuccess
              data = response.body
            else
              Hiera.debug("[hiera-consul] Could not read key: #{path}")
            end
          rescue Exception => e
            Hiera.warn("[hiera-consul] Error occurred reading value #{path}: #{e}")
          end

          data
      end

      def parse_result(res, prefix)
          if res == "null"
            Hiera.debug("[hiera-consul] Skipped null result")
            return nil
          end

          res_array = JSON.parse(res)
          case res_array.length
          when 0
            Hiera.debug("[hiera-consul] Skipped empty result")
            answer = nil
          when 1
            answer = Base64.decode64(res_array.first['Value'])
          else
            # Interpret the results as a nested Hash
            answer = res_array.each_with_object({}) do |entry, memo|
              # Strip the mount prefix and leading slash
              k = entry['Key'][(prefix.length+1)..-1]
              v = entry['Value'].nil? ? {} : Base64.decode64(entry['Value'])
              deep_merge!(memo, k.split('/').reverse.inject(v) { |a, n| { n => a } })
            end
          end

          answer
      end

      def deep_merge!(tgt_hash, src_hash)
        tgt_hash.merge!(src_hash) do |key, oldval, newval|
          if oldval.kind_of?(Hash) && newval.kind_of?(Hash)
            deep_merge!(oldval, newval)
          else
            newval
          end
        end
      end

      def check_agent
        response = wrapquery("/v1/agent/self")
        if response.nil?
          raise "Client could not connect to #{@consul.address}:#{@consul.port}"
        end
        true
      end

    end
  end
end
