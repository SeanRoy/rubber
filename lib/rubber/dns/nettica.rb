require 'nettica/client'
module Rubber
  module Dns

    class Nettica < Base

      def initialize(env)
        super(env)
        @nettica_env = @env.dns_providers.nettica
        @client = ::Nettica::Client.new(@nettica_env.user, @nettica_env.password)
        @ttl = (@nettica_env.ttl || 300).to_i
        @record_type = @nettica_env.record_type || "A"
      end

      def nameserver
        "dns1.nettica.com"
      end

      def check_status(response)
        code = case
          when response.respond_to?(:status)
            response.status
          when response.respond_to?(:result)
            response.result.status
          else
            500
        end
        if code < 200 || code > 299
          msg = "Failed to access nettica api (http_status=#{code})"
          msg += ", check dns_providers.nettica.user/password in rubber.yml" if code == 401
          raise msg
        end
        return response
      end

      def host_exists?(host)
        domain_info = check_status @client.list_domain(env.domain)
        raise "Domain needs to exist in nettica before records can be updated" unless domain_info.record
        return domain_info.record.any? { |r| r.hostName == host }
      end

      def create_host_record(host, ip)
        new = @client.create_domain_record(env.domain, host, @record_type, ip, @ttl, 0)
        check_status @client.add_record(new)
      end

      def destroy_host_record(host)
        old_record = check_status(@client.list_domain(env.domain)).record.find {|r| r.hostName == host }
        old = @client.create_domain_record(env.domain, host, old_record.recordType, old_record.data, old_record.tTL, old_record.priority)
        check_status @client.delete_record(old)
      end

      def update_host_record(host, ip)
        old_record = check_status(@client.list_domain(env.domain)).record.find {|r| r.hostName == host }
        update_record(host, ip, old_record)
      end

      # update the top level domain record which has an empty hostName
      def update_domain_record(ip)
        old_record = check_status(@client.list_domain(env.domain)).record.find {|r| r.hostName == '' and r.recordType == 'A' and r.data =~ /\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/}
        update_record('', ip, old_record)
      end

      def update_record(host, ip, old_record)
        old = @client.create_domain_record(env.domain, host, old_record.recordType, old_record.data, old_record.tTL, old_record.priority)
        new = @client.create_domain_record(env.domain, host, @record_type, ip, @ttl, 0)
        check_status @client.update_record(old, new)
      end

    end

  end
end
