#TODO: remove before commit, just used for testing with .to_yaml function
require 'yaml'
module VagrantPlugins
  module Mutagen
    module Mutagen
      if ENV['VAGRANT_MUTAGEN_SSH_CONFIG_PATH']
        @@ssh_user_config_path = ENV['VAGRANT_MUTAGEN_SSH_CONFIG_PATH']
      else
        @@ssh_user_config_path = '~/.ssh/config'
      end
      @@ssh_user_config_path = File.expand_path(@@ssh_user_config_path)

      def addConfigEntries
        # Prepare some needed variables
        uuid = @machine.id
        name = @machine.name
        hostname = @machine.config.vm.hostname
        # New Config for ~/.ssh/config
        newconfig = ''

        # Read contents of SSH config file
        file = File.open(@@ssh_user_config_path, "rb")
        configContents = file.read
        # Check for existing entry for hostname in config
        entryPattern = configEntryPattern(hostname, name, uuid)
        if configContents.match(/#{entryPattern}/)
          @ui.info "[vagrant-mutagen]   found SSH Config entry for: #{hostname}"
        else
          @ui.info "[vagrant-mutagen]   adding entry to SSH config for: #{hostname}"
          # Get SSH config from Vagrant
          newconfig = createConfigEntry(hostname, name, uuid)
        end

        # Append vagrant ssh config to end of file
        addToSSHConfig(newconfig)
      end

      def addToSSHConfig(content)
        return if content.length == 0

        @ui.info "[vagrant-mutagen] Writing the following config to (#@@ssh_user_config_path)"
        @ui.info content
        if !File.writable_real?(@@ssh_user_config_path)
          @ui.info "[vagrant-mutagen] This operation requires administrative access. You may " +
                       "skip it by manually adding equivalent entries to the config file."
          if !sudo(%Q(sh -c 'echo "#{content}" >> #@@ssh_user_config_path'))
            @ui.error "[vagrant-mutagen] Failed to add config, could not use sudo"
            adviseOnSudo
          end
        elsif Vagrant::Util::Platform.windows?
          require 'tmpdir'
          uuid = @machine.id || @machine.config.mutagen.id
          tmpPath = File.join(Dir.tmpdir, 'hosts-' + uuid + '.cmd')
          File.open(tmpPath, "w") do |tmpFile|
          tmpFile.puts(">>\"#{@@ssh_user_config_path}\" echo #{content}")
          end
          sudo(tmpPath)
          File.delete(tmpPath)
        else
          content = "\n" + content + "\n"
          hostsFile = File.open(@@ssh_user_config_path, "a")
          hostsFile.write(content)
          hostsFile.close()
        end
      end

      # Create a regular expression that will match the vagrant-mutagen signature
      def configEntryPattern(hostname, name, uuid = self.uuid)
        hashedId = Digest::MD5.hexdigest(uuid)
        Regexp.new("^# VAGRANT: #{hashedId}.*$\nHost #{hostname}.*$")
      end

      def createConfigEntry(hostname, name, uuid = self.uuid)
        # Get the SSH config from Vagrant
        sshconfig = `vagrant ssh-config --host #{hostname}`
        # Trim Whitespace from end
        sshconfig = sshconfig.gsub /^$\n/, ''
        sshconfig = sshconfig.chomp
        # Return the entry
        %Q(#{signature(name, uuid)}\n#{sshconfig}\n#{signature(name, uuid)})
      end

      def cacheConfigEntries
        @machine.config.mutagen.id = @machine.id
      end

      def removeHostEntries
        if !@machine.id and !@machine.config.mutagen.id
          @ui.info "[vagrant-mutagen] No machine id, nothing removed from #@@hosts_path"
          return
        end
        file = File.open(@@ssh_user_config_path, "rb")
        configContents = file.read
        uuid = @machine.id || @machine.config.mutagen.id
        hashedId = Digest::MD5.hexdigest(uuid)
        if configContents.match(/#{hashedId}/)
          removeFromHosts
          removeFromSshKnownHosts
        end
      end

      def removeFromHosts(options = {})
        uuid = @machine.id || @machine.config.mutagen.id
        hashedId = Digest::MD5.hexdigest(uuid)
        if !File.writable_real?(@@hosts_path) || Vagrant::Util::Platform.windows?
          if !sudo(%Q(sed -i -e '/#{hashedId}/ d' #@@hosts_path))
            @ui.error "[vagrant-mutagen] Failed to remove hosts, could not use sudo"
            adviseOnSudo
          end
        else
          hosts = ""
          File.open(@@hosts_path).each do |line|
            hosts << line unless line.include?(hashedId)
          end
          hosts.strip!
          hostsFile = File.open(@@hosts_path, "w")
          hostsFile.write(hosts)
          hostsFile.close()
        end
      end

      def removeFromSshKnownHosts
        if !@isWindowsHost
          hostnames = getHostnames
          hostnames.each do |hostname|
            command = %Q(sed -i -e '/#{hostname}/ d' #@@ssh_known_hosts_path)
            if system(command)
              @ui.info "[vagrant-mutagen] Removed host: #{hostname} from ssh_known_hosts file: #@@ssh_known_hosts_path"
            end
          end
        end
      end

      def signature(name, uuid = self.uuid)
        hashedId = Digest::MD5.hexdigest(uuid)
        %Q(# VAGRANT: #{hashedId} (#{name}) / #{uuid})
      end
    end
  end
end
