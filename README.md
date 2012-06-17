# MirrorMirror

A Ruby gem that allows for easier interactions and integration with external REST resources.

## Installation

    gem 'mirror_mirror'

## Usage Example

### Environment 
    
    # App controlled resource, reliant on external resource.
    class Timesheet < ActiveRecord::Base
      belongs_to :contractor, :auto_reflect => true
    end

    # Extenal Resource
    class Contractor < ActiveRecord::Base
      has_many :timesheets, :as => :worker
      
      mirror_mirror "http://api.example.com/v1/contractors", 
                    :request => :resource_request, :find => true
        
      def resource_request(verb, url, params)
        response = RestClient.send(verb, url + '.json', params)
        ActiveSupport::JSON.decode(response.to_str)["result"] if response.code == 200
      end
    end
    
    # API Resource Example
    {
      result: [{
        id: 1,
        first_name: "Daniel",
        last_name: "Doezema"
      },
      {
        id: 2,
        first_name: "John",
        last_name: "Doe"
      }]
    } 
 
### External API Scenario
  
    class ContractorsController < ApiController
      # api/contractors/:id/clock_out
      def clock_out
        # Automatically found & created b/c of the mirror_mirror :find => true option
        contractor  = Contractor.find(params[:id])
        timesheet   = contractor.timesheets.last
        result      = timesheet.update_attributes(:ended_at => Time.now)
      end
    end
    
### The "We've only got an id" Scenario

In this scenario a `contractor_id` is present, but we don't know if the `Contractor` record exists locally yet -- this is where the `:auto_reflect` option helps out. If a local `Contractor` record is not found then a request will automatically be made to fetch and create it.

    # Controller
    @timesheets = Timesheet.where("started_at > ?", Time.now.beginning_of_day)
    
    # View
    <h1>Today's Punched-In Contractors</h1>
    <ul>
      <% @timesheets.each do |timesheet| %>
        <li><%= "#{timesheet.worker.first_name} #{timesheet.worker.last_name}"</li>
      <% end %>
    </ul>