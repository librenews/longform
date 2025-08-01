class RecordsController < ApplicationController
  before_action :authenticate_user!

  def index
    @collections = []
    @error = nil

    begin
      reader = BlueskyRecordReader.new(current_user)
      
      # Get common collections to browse
      collections_result = reader.list_all_collections
      
      if collections_result[:success]
        @collections = collections_result[:collections]
      else
        @error = collections_result[:error]
      end
      
    rescue => e
      @error = "Error connecting to AT Protocol: #{e.message}"
    end
  end

  def collection
    @collection_name = params[:collection_name]
    @records_result = { success: false, records: [], error: nil }

    begin
      reader = BlueskyRecordReader.new(current_user)
      @records_result = reader.list_records(@collection_name, 50)
    rescue => e
      @records_result[:error] = "Error fetching records: #{e.message}"
    end
  end

  def show
    @record_uri = params[:id]
    @record_result = { success: false, record: nil, error: nil }

    begin
      reader = BlueskyRecordReader.new(current_user)
      @record_result = reader.get_record(@record_uri)
    rescue => e
      @record_result[:error] = "Error fetching record: #{e.message}"
    end
  end

  private

  def authenticate_user!
    redirect_to root_path unless current_user&.access_token.present?
  end
end
