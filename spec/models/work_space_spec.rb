
require 'rails_helper'

RSpec.describe WorkSpace do
  describe '#polling_stations_by_committee_room' do
    subject do
      polling_station.work_space
    end

    let :polling_station do
      create(
        :polling_station,
        committee_room: create(:committee_room)
      )
    end

    it 'gives most recent turnout observation for each polling station' do
      _another_observation = create(
        :turnout_observation,
        polling_station: polling_station,
        count: 11,
        created_at: 2.hours.ago
      )
      most_recent_observation = create(
        :turnout_observation,
        polling_station: polling_station,
        count: 22,
        created_at: 1.hour.ago
      )

      data = subject.polling_stations_by_committee_room

      _, first_group = data.first
      first_polling_station = first_group.first
      expect(first_polling_station).to eq(polling_station)
      expect(first_polling_station.last_turnout_observation).to eq(most_recent_observation)
    end

    it 'gives placeholder empty observation for polling station without observation' do
      data = subject.polling_stations_by_committee_room

      _, first_group = data.first
      first_polling_station = first_group.first
      expect(first_polling_station).to eq(polling_station)
      expect(first_polling_station.last_turnout_observation.count).to eq(0)
      expect(first_polling_station.last_turnout_observation.created_at).to be_nil
    end

    it 'groups polling stations/observations by committee room' do
      data = subject.polling_stations_by_committee_room

      committee_room, = data.first
      expect(committee_room).to eq(polling_station.committee_room)
    end
  end

  describe '#all_observations' do
    it 'sorts all observations by creation time' do
      polling_station = create(:polling_station)
      work_space = polling_station.work_space
      cr = create(:committee_room, work_space: work_space)
      turnout_observation = create(
        :turnout_observation,
        polling_station: polling_station,
        created_at: 2.day.ago
      )
      warp_count_observation = create(
        :warp_count_observation,
        polling_district: polling_station.polling_district,
        created_at: 3.days.ago
      )
      canvassers_observation = create(
        :canvassers_observation,
        committee_room: cr,
        created_at: 1.days.ago
      )

      result = work_space.all_observations

      expect(result).to eq([
        warp_count_observation,
        turnout_observation,
        canvassers_observation
      ])
    end

    it 'includes turnout observation' do
      polling_station = create(:polling_station)
      work_space = polling_station.work_space
      turnout_observation = create(
        :turnout_observation, polling_station: polling_station
      )
      _another_turnout_observation = create(:turnout_observation)

      result = work_space.all_observations

      expect(result.length).to eq(1)
      expect(result).to include(turnout_observation)
    end

    it 'includes canvassers observation' do
      work_space = create(:work_space)
      cr = create(:committee_room, work_space: work_space)
      canvassers_observation = create(
        :canvassers_observation, committee_room: cr
      )
      _another_canvassers_observation = create(:canvassers_observation)

      result = work_space.all_observations

      expect(result.length).to eq(1)
      expect(result).to include(canvassers_observation)
    end

    it 'includes cars observation' do
      work_space = create(:work_space)
      cr = create(:committee_room, work_space: work_space)
      cars_observation = create(
        :cars_observation, committee_room: cr
      )
      _another_cars_observation = create(:cars_observation)

      result = work_space.all_observations

      expect(result.length).to eq(1)
      expect(result).to include(cars_observation)
    end

    it 'includes remaining lifts observation' do
      polling_station = create(:polling_station)
      work_space = polling_station.work_space
      remaining_lifts_observation = create(
        :remaining_lifts_observation, polling_district: polling_station.polling_district
      )
      _another_remaining_lifts_observation = create(:remaining_lifts_observation)

      result = work_space.all_observations

      expect(result.length).to eq(1)
      expect(result).to include(remaining_lifts_observation)
    end

    it 'includes WARP count observation' do
      polling_station = create(:polling_station)
      work_space = polling_station.work_space
      warp_count_observation = create(
        :warp_count_observation, polling_district: polling_station.polling_district
      )
      _another_warp_count_observation = create(:warp_count_observation)

      result = work_space.all_observations

      expect(result.length).to eq(1)
      expect(result).to include(warp_count_observation)
    end
  end
end
