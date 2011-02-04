class WifiLogsController < ApplicationController
  before_filter :authenticate_user!
  # GET /maps/1/wifi_logs/
  # GET /maps/1/wifi_access_points/1/wifi_logs/
  def index
    if !params[:map_id].nil?
      @map = Map.find(params[:map_id])
    else
      #FIXME
    end
    if !params[:wifi_access_point_id].nil?
      @wifi_access_point = WifiAccessPoint.find(params[:wifi_access_point_id])
    else
      #FIXME
    end
    @manual_locations = ManualLocation.where(:map_id => @map.id)
    @wifi_logs = []
    @manual_locations.each do |l|
      if !l.movement_log.nil?
        if @wifi_access_point.nil?
          @wifi_logs = @wifi_logs + l.movement_log.wifi_logs
        else
          @wifi_logs = @wifi_logs + l.movement_log.wifi_logs.where(:wifi_access_point_id => @wifi_access_point.id)
        end
      end
    end

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /maps/1/wifi_logs/new
  def new
    @wifi_log = WifiLog.new
    if !params[:map_id].nil?
      @map = Map.find(params[:map_id])
    end

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @wifi_log }
    end
  end

  # POST /maps/1/wifi_logs
  def create
    begin
      WifiLog.transaction do
        @manual_location = ManualLocation.new
        @manual_location.init_by_params(params)
        @manual_location.save!

        @gpsd_tpv = nil
        @gps_location = nil
        if !params["gpsd_tpv"].nil? && !params["gpsd_tpv"].empty?
          @gpsd_tpv = JSON.parse(params["gpsd_tpv"])
          if !@gpsd_tpv.empty?
            @gps_location = GpsLocation.new_by_json(@gpsd_tpv)
            @gps_location.save!
          end
        end
        @movement_log = MovementLog.new
        @movement_log.manual_location = @manual_location
        @movement_log.gps_location = @gps_location
        # FIXME
        # how to specify current user in Devise
        @movement_log.user = current_user
        @movement_log.remote_addr = request.remote_addr
        @movement_log.user_agent = request.user_agent
        @movement_log.user_device = params["user_device"]
        @movement_log.save!

        if !params["wifi_towers"].nil? && !params["wifi_towers"].empty?
          @wifi_towers = JSON.parse(params["wifi_towers"])
          @wifi_towers.each do |wifi_tower|
            @wifi_access_point = WifiAccessPoint.find_or_initialize_by_json(wifi_tower)
            if !@wifi_access_point.persisted?
              @wifi_access_point.save!
            end
            @wifi_log = WifiLog.new_by_json(wifi_tower)
            @wifi_log.wifi_access_point = @wifi_access_point
            @wifi_log.movement_log = @movement_log
            @wifi_log.save!
          end
        end
      end
      respond_to do |format|
        format.html { render :text => "Logs are successfully recorded." }
      end
    rescue
      respond_to do |format|
        format.html { render :text => "Failed to record logs." }
      end
    end
  end

end
