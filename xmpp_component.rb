require 'socket'
require 'digest/sha1'
require 'digest/sha2'

require 'rubygems'
require 'hpricot'

require 'base64'
require 'pp'
require 'openssl'
require 'drb'
require 'yaml'

require 'protobuffer'
require 'wave.danopia.net/lib/sails_remote'

sleep 2

def encode64(data)
	Base64.encode64(data).gsub("\n", '')
end
def decode64(data)
	Base64.decode64(data)
end

puts "Loading config"
config = YAML.load(File.open('sails.conf'))
provider = Provider.new config['domain-name'], config['service-name'] || 'wave'

#################

wave = Wave.new(provider, 'R0PIDtU751vF')

delta = Delta.new(wave, "me@danopia.net")
delta.operations << AddUserOp.new("me@danopia.net")
wave << delta

delta = Delta.new(wave, "me@danopia.net")
delta.operations << AddUserOp.new("test@danopia.net")
wave << delta

delta = Delta.new(wave, "me@danopia.net")
delta.operations << MutateOp.new('main', ["(\004",
			{2=>{0=>"line", 1=>{0=>"by", 1=>'me@danopia.net'}}}," \001",
			{1=>"This is a test."}])
wave << delta

delta = Delta.new(wave, "me@danopia.net")
delta.operations << RemoveUserOp.new("test@danopia.net")
wave << delta

provider << wave

#################

wave = Wave.new(provider, 'BHW1z9FOWKua')

delta = Delta.new(wave, "me@danopia.net")
delta.operations << AddUserOp.new('me@danopia.net') # Add myself to the conv_root_path
wave << delta

delta = Delta.new(wave, "me@danopia.net")
delta.operations << AddUserOp.new('echoe@killerswan.com') # Add an echoey to the wave
wave << delta

delta = Delta.new(wave, "me@danopia.net")
delta.operations << RemoveUserOp.new('echoe@killerswan.com')
wave << delta

delta = Delta.new(wave, "me@danopia.net")
delta.operations << AddUserOp.new('echoey@killerswan.com')
wave << delta

provider << wave

#################

wave = Wave.new(provider, 'ASDFASDFASDF', 'newwave.danopia.net')

delta = Delta.new(wave, "me@newwave.danopia.net")
delta.operations << AddUserOp.new('me@newwave.danopia.net') # Add myself to the conv_root_path
wave << delta

delta = Delta.new(wave, "me@newwave.danopia.net")
delta.operations << AddUserOp.new('echoe@danopia.net') # Add an echoey to the wave
wave << delta

delta = Delta.new(wave, "me@newwave.danopia.net")
delta.operations << RemoveUserOp.new('echoe@danopia.net')
wave << delta

delta = Delta.new(wave, "me@newwave.danopia.net")
delta.operations << AddUserOp.new('echoey@danopia.net')
wave << delta

delta = Delta.new(wave, "me@newwave.danopia.net")
delta.operations << AddUserOp.new('danopia@danopia.net')
wave << delta

provider << wave

#################

puts "Connecting to #{config['xmpp-connect-host']}:#{config['xmpp-connect-port']} as #{provider.name}..."
sock = TCPSocket.new config['xmpp-connect-host'] || 'localhost', config['xmpp-connect-port'].to_i || 5275
provider.sock = sock

def sock.provider=(provider)
	@provider = provider
end
def sock.ids
	@ids ||= {}
end
def sock.send_raw(packet)
	$stdout.puts "Sent: \e[2;34m#{packet}\e[0m" if packet.size > 1
	print packet
	packet
end
def sock.send_xml(name, type, to, contents, id=nil)
	if type.to_i > 0
		id = type
		type = 'result'
	else
		id ||= "#{(rand*10000).to_i}-#{(rand*100).to_i}"
	end
	
	ids[id] = send_raw("<#{name} type=\"#{type}\" id=\"#{id}\" to=\"#{to}\" from=\"#{@provider.name}\">#{contents}</#{name}>")
	id
end

sock.provider = provider

sock.send_raw '<stream:stream xmlns="jabber:component:accept" xmlns:stream="http://etherx.jabber.org/streams" to="' + provider.name + '">'

message = sock.recv 1024
puts "Recieved: \e[33m#{message}\e[0m"
doc = Hpricot(message)

id = (doc/'stream:stream').first['id']

unless id
	puts "Unable to connect to XMPP. The server denied the component."
	exit
end

key = Digest::SHA1.hexdigest(id + config['xmpp-password'])

sock.send_raw "<handshake>#{key}</handshake>"

puts 'Setting up keepalive thread'
Thread.new do
	while sleep 60
		sock.send_raw ' '
		#puts 'Sent a space'
	end
end

remote = SailsRemote.serve(provider)
trap("INT") { remote.stop_service }
puts "DRb server running at #{remote.uri}"

puts 'Entering program loop'

ids = {} # used for history requests
#ready = false
until sock.closed?
	#if ready
		#message = '<message from="wave.fedone.ferrum-et-magica.de" to="wave.danopia.net" type="normal" id="7837-16"><request xmlns="urn:xmpp:receipts"/><event xmlns="http://jabber.org/protocol/pubsub#event"><items><item><wavelet-update xmlns="http://waveprotocol.org/protocol/0.2/waveserver" wavelet-name="fedone.ferrum-et-magica.de/w+P6MKjCO7yjGk/conv+root"><applied-delta>Cv4BClIKGAgBEhSu+JngKoP3Rd/UWzVbkkYT1Cg3OxIfbXVya0BmZWRvbmUuZmVycnVtLWV0LW1hZ2ljYS5kZRoVChNkYW5vcGlhQGRhbm9waWEubmV0EqcBCoABDdZsGqODVWvnv++wVzBOHe0GxWwk+3Uw6wLKBATp6z7zhlSniyeQukZoXxIwWWyZy9nOmJnfi/PKym31VHMZWsZJ9U8pptRiANjxG6K4BP1HjcK0QSXgX7s1jOyh1NeCr++pnv+y6qw97ojifNP2Yq5ZPbrUL8rgblyp/L4cl/gSIJ+nDylQQHNfFOiRVLIoyGbJizNr0JcFtkSZHOyZFRsKGAESGAgBEhSu+JngKoP3Rd/UWzVbkkYT1Cg3OxgBIIeqtrbIJA==</applied-delta></wavelet-update></item></items></event></message>'
		#message = '<message from="wave.fedone.ferrum-et-magica.de" to="wave.danopia.net" type="normal" id="8390-18"><request xmlns="urn:xmpp:receipts"/><event xmlns="http://jabber.org/protocol/pubsub#event"><items><item><wavelet-update xmlns="http://waveprotocol.org/protocol/0.2/waveserver" wavelet-name="fedone.ferrum-et-magica.de/w+P6MKjCO7yjGk/conv+root"><applied-delta>CrECCoQBChgIAhIUPWoUvFBWI4FDvkx8AW1uoEvykwYSH211cmtAZmVkb25lLmZlcnJ1bS1ldC1tYWdpY2EuZGUaRxpFCgRtYWluEj0KLxotCgRsaW5lEiUKAmJ5Eh9tdXJrQGZlZG9uZS5mZXJydW0tZXQtbWFnaWNhLmRlCgIgAQoGEgRoZWxwEqcBCoABAufyO9HjYzlmz+LoUiF6OdvTbREceK0zzZ49yUfiOKhFMJLsQKmNMPzAS54Laoh+QoA0YI5uTGyOQV4dXRgs0qaandWuU3WtEepgl7XX0ZPCTqTiBlObWtUa2+eljLK/KoSMaVQ7pNHfW1RI+P9ww7eOVzbJy2LSbq5X/jwCB2oSIJ+nDylQQHNfFOiRVLIoyGbJizNr0JcFtkSZHOyZFRsKGAESGAgCEhQ9ahS8UFYjgUO+THwBbW6gS/KTBhgBIJ+E+7bIJA==</applied-delta></wavelet-update></item></items></event></message>'
		#ready = false
	#else
		message = sock.recv 10000
	puts "Recieved: \e[33m#{message}\e[0m"
	#end
	
	if !message || message.empty?
		puts 'Connection closed.'
		exit
	
	elsif message.include? '</stream:stream>'
		puts "Server closed the XMPP component connection."
		remote.stop_service
		exit
	end
	
	doc = Hpricot("<packet>#{message}</packet>")
	
	doc.root.children.each do |packet|
		name = packet.name
		
		if name == 'handshake'
			puts "Connected to XMPP."
			if config['ping']			
				puts "Sending ping to #{config['ping']}"
				sock.send_xml 'iq', 'get', config['ping'], '<query xmlns="http://jabber.org/protocol/disco#items"/>'
			end
			next
		end
		
		type = packet['type'] || 'none'
		id = packet['id']
		from = packet['from']
		to = packet['to']
		
		case [name.to_sym, type.to_sym]
		
			when [:iq, :get]
				if (packet/'query').any?
					if (packet/'query').first['xmlns'].include?('items')
						sock.send_xml 'iq', id, from, "<query xmlns=\"http://jabber.org/protocol/disco#items\"><item jid=\"#{provider.name}\" name=\"#{config['identity']}\"/></query>"
					else
						sock.send_xml 'iq', id, from, "<query xmlns=\"http://jabber.org/protocol/disco#info\"><identity category=\"collaboration\" type=\"google-wave\" name=\"#{config['identity']}\"/><feature var=\"http://waveprotocol.org/protocol/0.2/waveserver\"/></query>"
					end
					#ready = true if from.include? 'danopia.net'
					
				# <pubsub xmlns="http://jabber.org/protocol/pubsub"><items node="wavelet"><delta-history xmlns="http://waveprotocol.org/protocol/0.2/waveserver" start-version="0" start-version-hash="d2F2ZTovL2Rhbm9waWEubmV0L3crRWx4cG04bWpCN0tJL2NvbnYrcm9vdA==" end-version="3" end-version-hash="RNy5arFR2hAXu+q63y4ESDbWRvE=" wavelet-name="danopia.net/w+Elxpm8mjB7KI/conv+root"/></items></pubsub>
				elsif (packet/'pubsub').any?
					puts "#{from} requested some deltas"
					
					node = (packet/'pubsub/items/delta-history').first
					node['wavelet-name'] =~ /^(.+)\/w\+(.+)\/(.+)$/
					wave_domain, wave_name, wavelet_name = $1, $2, $3
					
					wave = provider["#{wave_domain}/w+#{wave_name}"]
					payload = ''
					(node['start-version'].to_i..node['end-version'].to_i).each do |version|
						delta = wave[version]
						next unless delta.is_a? Delta
						payload << "<item><applied-delta xmlns=\"http://waveprotocol.org/protocol/0.2/waveserver\"><![CDATA[#{encode64(delta.to_s)}]]></applied-delta></item>"
					end
					
					payload << "<item><commit-notice xmlns=\"http://waveprotocol.org/protocol/0.2/waveserver\" version=\"#{wave[node['end-version'].to_i].version}\"/></item>"
					payload << "<item><history-truncated xmlns=\"http://waveprotocol.org/protocol/0.2/waveserver\" version=\"#{wave[node['end-version'].to_i].version}\"/></item>"
					
					sock.send_xml 'iq', id, from, "<pubsub xmlns=\"http://jabber.org/protocol/pubsub\"><items>#{payload}</items></pubsub>"
					
				end
				
			when [:iq, :set]
				if (packet/'certificate').any?
					puts "Got a cert from #{from}"
					provider.certs[from] = (packet/'certificate').inner_text
					sock.send_xml 'iq', id, from, "<pubsub xmlns=\"http://jabber.org/protocol/pubsub\"><publish><item node=\"signer\"><signature-response xmlns=\"http://waveprotocol.org/protocol/0.2/waveserver\"/></item></publish></pubsub>"
				
				elsif (packet/'publish').any?
					puts "Publish request from #{from} for one of my waves"
					node = (packet/'publish/item/submit-request/delta').first
					delta = Delta.parse(provider, node['wavelet-name'], decode64(node.inner_text))
					pp delta
					
					sock.send_xml 'message', id, from, "<received xmlns=\"urn:xmpp:receipts\"/>"
				end
				
			when [:iq, :result]
				
				if (packet/'query/item').any?
					puts "Got service listing from #{from}:"
					
					haswave = false
					(packet/'query/item').each do |item|
						puts "\t#{item['name']}\t(at #{item['jid']})"
						haswave = item['jid'] if item['name'].include? 'Wave Server'
					end
					
					if haswave
						puts "Found wave services on #{from} as #{haswave}, pulling details"
						sock.send_xml 'iq', 'get', haswave, '<query xmlns="http://jabber.org/protocol/disco#info"/>'
					else
						puts "No wave server found on #{from}"
					end
				
				elsif (packet/'query/identity').any?
					node = (packet/'query/identity').first
					
					if node['type'] == 'google-wave'
						puts "#{from} is Google Wave service (#{node['name']}). Sending ping."
						sock.send_xml 'message', 'normal', from, '<ping xmlns="http://waveprotocol.org/protocol/0.2/waveserver"/><request xmlns="urn:xmpp:receipts"/>', '9744-2'
					else
						puts "#{from} is NOT a Google Wave service, it's a \"#{node['name']}\"!"
					end
				
				elsif (packet/'pubsub/publish/item/signature-response').any?
					puts "#{from} responded to cert, now to send wave ASDFASDFASDF."
					provider['ASDFASDFASDF'].newest.propagate
					
				elsif (packet/'pubsub/items/item/applied-delta').any?
					wave = ids[id]
					ids.delete id
					puts "Got history for #{wave.name}"
					
					(packet/'pubsub/items/item/applied-delta').each do |update|
						delta = Delta.parse(provider, wave.conv_root_path, decode64(update.inner_text))
						puts "Got a delta, version #{delta.version}"
					end
				end
			
			when [:message, :normal], [:message, :none]
				subtype = packet.children.first.name
				
				if subtype == 'received'
					if id == '9744-2'
						puts "#{from} ponged, attempting to send the cert"
						sock.send_xml 'iq', 'set', from, "<pubsub xmlns=\"http://jabber.org/protocol/pubsub\"><publish node=\"signer\"><item><signature xmlns=\"http://waveprotocol.org/protocol/0.2/waveserver\" domain=\"newwave.#{provider.domain}\" algorithm=\"SHA256\"><certificate><![CDATA[#{provider.certs[provider.domain]}]]></certificate></signature></item></publish></pubsub>"
					else
						puts "#{from} ACK'ed our previous packet."
					end
					
				elsif subtype == 'request'
					(packet/'event/items/item/wavelet-update').each do |update|
						delta = Delta.parse(provider, update['wavelet-name'], decode64(update.inner_text))
						puts "Got a delta, version #{delta.version}"
						
						wave = delta.wave
						if wave.real_deltas.size != wave.deltas.size - 1
							puts "Requesting more deltas"
							id = sock.send_xml 'iq', 'get', from, "<pubsub xmlns=\"http://jabber.org/protocol/pubsub\"><items node=\"wavelet\"><delta-history xmlns=\"http://waveprotocol.org/protocol/0.2/waveserver\" start-version=\"0\" start-version-hash=\"#{encode64(wave[0].hash)}\" end-version=\"#{wave.newest_version}\" end-version-hash=\"#{encode64(wave.newest.hash)}\" wavelet-name=\"#{wave.conv_root_path}\"/></items></pubsub>"
							ids[id] = wave
						end
					end
					
				end
			
			else
				puts "Unknown packet"
				
		end
	end
end
