class Rack::App::Router::Dynamic < Rack::App::Router::Base

  require 'rack/app/router/dynamic/request_path_part_placeholder'
  DYNAMIC_REQUEST_PATH_PART = RequestPathPartPlaceholder.new('DYNAMIC_REQUEST_PATH_PART')
  MOUNTED_DIRECTORY = RequestPathPartPlaceholder.new('MOUNTED_DIRECTORY')
  MOUNTED_APPLICATION = RequestPathPartPlaceholder.new('MOUNTED_APPLICATION')

  def fetch_endpoint(request_method, request_path)
    normalized_request_path = Rack::App::Utils.normalize_path(request_path)

    last_mounted_directory = nil
    last_mounted_app = nil
    current_cluster = main_cluster(request_method)

    normalized_request_path.split('/').each do |path_part|

      last_mounted_directory = current_cluster[MOUNTED_DIRECTORY] || last_mounted_directory
      last_mounted_app = current_cluster[MOUNTED_APPLICATION] || last_mounted_app

      current_cluster = current_cluster[path_part] || current_cluster[DYNAMIC_REQUEST_PATH_PART]

      last_mounted_directory = (current_cluster || {})[MOUNTED_DIRECTORY] || last_mounted_directory
      last_mounted_app = (current_cluster || {})[MOUNTED_APPLICATION] || last_mounted_app

      if current_cluster.nil?
        if last_mounted_directory
          current_cluster = last_mounted_directory
          break

        elsif last_mounted_app
          current_cluster = last_mounted_app
          break

        else
          return nil

        end
      end

    end

    return current_cluster[:endpoint]

  end

  protected

  def initialize
    @http_method_cluster = {}
  end

  def path_part_is_dynamic?(path_part_str)
    !!(path_part_str.to_s =~ /^:\w+$/i)
  end

  def deep_merge!(hash, other_hash)
    Rack::App::Utils.deep_merge(hash, other_hash)
  end

  def main_cluster(request_method)
    (@http_method_cluster[request_method.to_s.upcase] ||= {})
  end

  def path_part_is_a_mounted_directory?(path_part)
    (path_part == '**' or path_part == '*')
  end

  def path_part_is_a_mounted_rack_based_application?(path_part)
    path_part == Rack::App::Constants::RACK_BASED_APPLICATION
  end

  def compile_registered_endpoints!
    @http_method_cluster.clear
    endpoints.each do |endpoint_prop|
      compile_endpoint(endpoint_prop[:request_method], endpoint_prop[:request_path], endpoint_prop[:endpoint])
    end
  end

  def compile_endpoint(request_method, request_path, endpoint)
    clusters_for(request_method) do |current_cluster|

      path_params = {}
      break_build = false

      request_path.split('/').each.with_index do |path_part, index|

        new_cluster_name = if path_part_is_dynamic?(path_part)
                             path_params[index]= path_part.sub(/^:/, '')
                             DYNAMIC_REQUEST_PATH_PART

                           elsif path_part_is_a_mounted_directory?(path_part)
                             break_build = true
                             MOUNTED_DIRECTORY

                           elsif path_part_is_a_mounted_rack_based_application?(path_part)
                             break_build = true
                             MOUNTED_APPLICATION

                           else
                             path_part
                           end

        current_cluster = (current_cluster[new_cluster_name] ||= {})
        break if break_build

      end

      current_cluster[:endpoint]= endpoint
      if current_cluster[:endpoint].respond_to?(:register_path_params_matcher)
        current_cluster[:endpoint].register_path_params_matcher(path_params)
      end

    end
  end

  def clusters_for(request_method)
    if ::Rack::App::Constants::HTTP::ANY == request_method
      (::Rack::App::Constants::HTTP.constants - [:ANY]).map(&:to_s).each do |cluster_type|
        yield(main_cluster(cluster_type))
      end
    else
      yield(main_cluster(request_method))
    end
  end

end