require "jekyll"
require 'uri'
require 'net/http'
require 'net/https'
require 'json'


module GetReleaseMetadata
  class GetJsonGenerator < Jekyll::Generator
    safe true
    priority :highest

    def generate(site)
      md = site.config['metadata']
      api = md['api']
      key = md['key']
      user = md['user']
      pass = md['pass']

      if !key
        warn "No project key".yellow
        return
      end
      if !api
        warn "No api configured".yellow
        return
      end

      
      load(URI("#{api}/dataset/#{key}"), md, 'current', user, pass)
      addAgentLabels(md['current'])
      puts "Using release key #{md['current']['key']}"
      site.config['react']['datasetKey'] = md['current']['key']

      load(URI("#{api}/dataset/#{key}/source"), md, 'sources', user, pass)
      md['sources'].each { |d| addAgentLabels(d)}            

    end


    def addAgentLabels(d)
      if d['creator']
        d['creator'].each { |a| addAgentLabel(a)}            
      end
      if d['contributor']
        d['contributor'].each { |a| addAgentLabel(a)}            
      end
    end

    def addAgentLabel(a)
      label = StringIO.new
      if a['family']
        label << a['family']
        if a['given']
          label << ", "
          label << a['given']
        end
        if a['orcid']
          label << ' <a href="https://orcid.org/'
          label << a['orcid']
          label << '"><img alt="ORCID logo" src="https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png" width="16" height="16" /></a>'
        end
        if a['organisation']
          if !a['orcid'] and a['given'] and a['given'][-1] != "."
            label << "."
          end
          label << " <i>"
          if a['department']
            label << a['department']
            label << ", "
          end
          label << a['organisation']
          label << "</i>"
        end
      else
        if a['organisation']
          if a['department']
            label << a['department']
            label << ", "
          end
          label << a['organisation']
        end
      end
  
      if a['note']
        label << " - <i>"
        label << a['note']
        label << "</i>"
      end
      a['label']=label.string
    end

    def load(uri, cfg, target, user, pass)
      puts "Reading JSON from #{uri}"
      Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https', 
        :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

        req = Net::HTTP::Get.new uri.request_uri
        if user
          req.basic_auth user, pass
        end
        resp = http.request req # Net::HTTPResponse object

        if resp.code != "200"
          warn "Bad JSON response #{resp.code}: #{resp.message}"
          next
        end
        source = JSON.parse(resp.body)
        cfg[target] = source
      end
    end
  end
end

