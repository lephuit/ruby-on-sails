# Includes the lib/ files: wave_proto utils delta_builder operations playback
# server wave blip annotation thread base_delta fake_delta delta database
# wave_user server_list

%w{wave_proto utils delta_builder operations playback server wave blip annotation thread base_delta fake_delta delta database wave_user server_list}.each do |file|
	require File.join(File.dirname(__FILE__), 'lib', file)
end

require File.join(File.dirname(__FILE__), 'lib', 'protocol', 'client')
require File.join(File.dirname(__FILE__), 'lib', 'protocol', 'server')
