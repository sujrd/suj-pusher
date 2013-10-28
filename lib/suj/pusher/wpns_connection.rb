require "eventmachine"
require "em-http"
require "base64"
require 'uri'
module Suj
  module Pusher
    class WPNSConnection
      include Suj::Pusher::Logger


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
        @cert_key = Digest::SHA1.hexdigest(@options[:secret])
        @cert_file = File.join(Suj::Pusher.config.certs_path, @cert_key)
        info "initialazing wns connection"
      end


      def deliver(options)
        begin
            @options = options
          @notification = Suj::Pusher::WnsNotification.new(@options)
            info "WPNS delivering data"
#	    @Authorization  = "Bearer #{token["access_token"]}"
            @Content_type = "text/xml; charset=utf-8"
            @Content_length = @options[:data].size #@notification.data.size
            @X_MessageID = nil
            @X_MessageID = @options[:wpmid]
	    @X_WindowsPhone_Target = nil
            @X_WindowsPhone_Target = @options[:wptype]
            @X_NotificationClass = @options[:wpnotificationclass]
	    @options[:wpids].each do |id|
		info "atempting send notification to Id: #{id}"
		@header = Hash.new
		@header['Content-Type'] = @Content_type 
		@header['Accept'] = "application/*" 
	#	@header['Content-Length'] = @Content_length 
		@header['X-NotificationClass'] =  @X_NotificationClass
		if (@X_WindowsPhone_Target != nil)
        		@header['X-WindowsPhone-Target'] = @X_WindowsPhone_Target
		else
                end 
		if( @X_MessageID  != nil)
  			@header['X-MessageID'] = @X_MessageID 
		else
		end
		http = EventMachine::HttpRequest.new(id).post( :head => @header, :body => @options[:data])# @notification.data )
        	info http.inspect
        	http.errback do
          		error "WPNS-sending network error"
        	end
        	http.callback do
			if http.response_header.status != 200
            			error "WPNS-sending push error #{http.response_header.status}"
           			 error http.response
           			 error http.response_header
          		else
            			info "WPNS-push notification sent"
            			info http.response_header
          		end
        	end
            
            end

            @notification = nil
            info "WPNS delivered data"
        rescue => ex
          unbind
          error "WPNS notification error : #{ex}"
        end
	unbind 
      end




      def unbind
        info "WPNS Connection closed..."
        FileUtils.rm_f(@cert_file)
        @pool.remove_connection(@cert_key)
      end
    end
  end
end
