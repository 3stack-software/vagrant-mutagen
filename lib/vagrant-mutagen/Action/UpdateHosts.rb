require_relative "../Mutagen"
module VagrantPlugins
  module Mutagen
    module Action
      class UpdateHosts
        include Mutagen


        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @ui = env[:ui]
        end

        def call(env)
          @ui.info "[vagrant-mutagen] Checking for SSH config entries"
          addHostEntries()
          @app.call(env)
        end

      end
    end
  end
end