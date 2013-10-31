require "eventmachine"
require "em-http"
require "base64"
require 'uri'
module Suj
  module Pusher
    class WNSConnection
      include Suj::Pusher::Logger

      WPN_OAUTH_SERVER =  "https://login.live.com/accesstoken.srf"

      ERRORS = {
        0 => "No errors encountered",
        1 => "Processing error",
        2 => "Missing device token",
        3 => "Missing topic",
        4 => "Missing payload",
        5 => "Invalid token size",
        6 => "Invalid topic size",
        7 => "Invalid payload size",
        8 => "Invalid token",
        255 => "Unknown error"
      }
      
      def initialize(pool,options = {})
        @pool = pool 
        @options = options
        #info "options #{options}"
        @cert_key = Digest::SHA1.hexdigest(@options[:secret])
        @cert_file = File.join(Suj::Pusher.config.certs_path, @cert_key)
      end

   

      def deliver(options)

       begin
       @body = "grant_type=client_credentials&client_id=#{CGI.escape(@options[:sid])}&client_secret=#{CGI.escape(@options[:secret])}&scope=notify.windows.com"
       @header = {"Content-Type" => "application/x-www-form-urlencoded"}
       http = EventMachine::HttpRequest.new(WPN_OAUTH_SERVER).post( :head => @header, :body =>@body )
       info http.inspect
       http.errback do
       	error "WNS network error"
        @pool.remove_connection(@cert_key)
       end
       http.callback do
          if http.response_header.status != 200
            error "WNS push error #{http.response_header.status}"
            error http.response
       else


         
        token = JSON.parse(http.response) 
            @options = options
          @notification = Suj::Pusher::WnsNotification.new(@options)
            info "WNS delivering data"
	    @Authorization  = "Bearer #{token["access_token"]}"
            
	    @Content_type = ""
            if(@options[:wnstype].eql?("wns/raw"))
            
                @Content_type = "application/octet-stream"
            else
            
              @Content_type = "text/xml"
            end
            @Content_length = @notification.data.size
            @X_WNS_Type = @options[:wnstype]
            @X_WNS_Cache_Policy = "no-cache"
           if(@options.has_key?("wnscache"))
            
              @X_WNS_Cache_Policy = @options[:wnscache]
            end
            @X_WNS_RequestForStatus = true
            if(@options.has_key?("wnsrequeststatus"))
            
              @X_WNS_RequestForStatus = @options[:wnsrequeststatus]
            end
            @X_WNS_Tag = nil
            if(@options.has_key?("wnstag"))
            
              @X_WNS_Tag = @options[:wnstag]
            end
            @X_WNS_TTL = nil
            if(@options.has_key?("time_to_live"))
            
              @X_WNS_Cache_Policy = @options[:time_to_live]
            end
	    @options[:wnsids].each do |id|
		info "atempting send notification to Id: #{id}"
		@header = Hash.new
		@header['Authorization'] = @Authorization
		@header['Content-Type'] = @Content_type 
		@header['Content-Length'] = @Content_length 
		@header['X-WNS-Type'] = @X_WNS_Type 
		@header['X-WNS-Cache-Policy'] = @X_WNS_Cache_Policy 
		@header['X-WNS-RequestForStatus'] = @X_WNS_RequestForStatus 
		if(@X_WNS_Tag!= nil)
  			@header['X-WNS-Tag'] = @X_WNS_Tag 
		end
		if(@X_WNS_TTL!= nil)
			@header['X-WNS-TTL'] = @X_WNS_TTL 
		end
		http2 = EventMachine::HttpRequest.new(id).post( :head => @header, :body =>@options[:data]) #@notification.data )
        	http2.errback do
          		error "WNS-sending network error"
        	end
        	http2.callback do
          		if http2.response_header.status != 200
            			error "WNS-sending push error #{http2.response_header.status}"
           			 error http.response
          		else
            			info "WNS-push notification sent"
            			info http2.response_header
          		end
        	end
            
            end
        end #nbersano
       end #nbersano
            @notification = nil
            info "WNS delivered data"
        rescue => ex
          unbind
          error "WNS notification error : #{ex}"
        end
       unbind
      end




      def unbind
        info "WNS Connection closed..."
        @disconnected = true
        FileUtils.rm_f(@cert_file)
        @pool.remove_connection(@cert_key)
      end
    end
  end
end
