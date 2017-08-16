require 'json'
require 'yaml'
require 'MrMurano/Webservice'

module MrMurano
  module Webservice
    class Settings < WebserviceBase
      def initialize
        super
        @uriparts << :cors
      end
      def cors
        ret = get('')
        return {} if ret.nil?
        return {} unless ret.kind_of? Hash
        return ret
      end
      def cors=(x)
        raise "Not Hash" unless x.kind_of? Hash
        put('', x)
      end
    end

    class Cors < WebserviceBase
      def initialize
        super
        @uriparts << :cors
        #@project_section = :cors
      end

      def fetch(id=nil, &block)
        ret = get()
        return [] if ret.is_a?(Hash) and ret.has_key?(:error)
        if ret.kind_of?(Hash) and ret.has_key?(:cors) then
          # XXX cors is a JSON encoded string. That seems weird. keep an eye on this.
          data = JSON.parse(ret[:cors], @json_opts)
        else
          data = ret
        end
        if block_given? then
          yield Hash.transform_keys_to_strings(data).to_yaml
        else
          data
        end
      end

      ##
      # Upload CORS
      # @param file [String,Nil] File path to upload other than defaults
      def upload(file=nil)
        unless file.nil? then
          data = YAML.load_file(file)
        else
          data = $project['routes.cors']
          # If it is just a string, then is a file to load.
          data = YAML.load_file(data) if data.kind_of? String
        end
        put('', data)
      end

    end
  end
end

#  vim: set ai et sw=2 ts=2 :
