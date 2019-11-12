require "vagrant-mutagen/Action/UpdateConfig"
require "vagrant-mutagen/Action/CacheConfig"
require "vagrant-mutagen/Action/RemoveHosts"

module VagrantPlugins
  module Mutagen
    class Plugin < Vagrant.plugin('2')
      name 'Mutagen'
      description <<-DESC
        This plugin manages the ~/.ssh/config file for the host machine. An entry is
        created for the hostname attribute in the vm.config.
      DESC

      config(:mutagen) do
        require_relative 'config'
        Config
      end

      action_hook(:mutagen, :machine_action_up) do |hook|
        hook.append(Action::UpdateConfig)
      end

      action_hook(:mutagen, :machine_action_provision) do |hook|
        hook.before(Vagrant::Action::Builtin::Provision, Action::UpdateConfig)
      end

      action_hook(:mutagen, :machine_action_halt) do |hook|
        hook.append(Action::RemoveHosts)
      end

      action_hook(:mutagen, :machine_action_suspend) do |hook|
        hook.append(Action::RemoveHosts)
      end

      action_hook(:mutagen, :machine_action_destroy) do |hook|
        hook.prepend(Action::CacheConfig)
      end

      action_hook(:mutagen, :machine_action_destroy) do |hook|
        hook.append(Action::RemoveHosts)
      end

      action_hook(:mutagen, :machine_action_reload) do |hook|
        hook.prepend(Action::RemoveHosts)
        hook.append(Action::UpdateConfig)
      end

      action_hook(:mutagen, :machine_action_resume) do |hook|
        hook.prepend(Action::RemoveHosts)
        hook.append(Action::UpdateConfig)
      end

      command(:mutagen) do
        require_relative 'command'
        Command
      end
    end
  end
end
