# Copyright (c) 2012-2018 Snowplow Analytics Ltd. All rights reserved.
#
# This program is licensed to you under the Apache License Version 2.0,
# and you may not use this file except in compliance with the Apache License Version 2.0.
# You may obtain a copy of the Apache License Version 2.0 at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the Apache License Version 2.0 is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the Apache License Version 2.0 for the specific language governing permissions and limitations there under.

# Author::    Joshua Beemster (mailto:support@snowplowanalytics.com)
# Copyright:: Copyright (c) 2012-2018 Snowplow Analytics Ltd
# License::   Apache License Version 2.0

require 'aws-sdk-emr'
require 'contracts'
require 'pathname'
require 'uri'

module Snowplow
  module EmrEtlRunner
    module EMR

      include Contracts

      # Attempts to find an active EMR JobFlow with a given name
      #
      # Parameters:
      # +client+:: EMR client
      # +name+:: EMR cluster name
      def get_emr_jobflow_id(client, name)
        get_emr_jobflow_id_impl(client, name)
      end

      private

      def get_emr_jobflow_id_impl(client, name)
        # Marker is used for paginating through all results
        marker = nil
        emr_cluster_id = nil

        loop do
          response = list_clusters(client, marker)
          emr_clusters = response.clusters.select { |c| c[:name] == name }

          case emr_clusters.size
          when 0
            marker = response.marker
          when 1
            emr_cluster = emr_clusters.first
            if emr_cluster[:status][:state] == "RUNNING"
              raise EmrDiscoveryError, "EMR Cluster must be in WAITING state before new job steps can be submitted - found #{emr_cluster[:status][:state]}"
            end
            emr_cluster_id = emr_cluster[:id]
          else
            raise EmrDiscoveryError, "EMR Cluster name must be unique for safe discovery - found #{emr_clusters.size} with name #{name}"
          end

          break if marker.nil? or !emr_cluster_id.nil?
        end

        emr_cluster_id
      end

      def list_clusters(client, marker)
        options = {
            cluster_states: ["WAITING", "RUNNING"],
        }
        options[:marker] = marker unless marker.nil?
        client.list_clusters(options)
      end

    end
  end
end
